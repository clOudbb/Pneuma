import Foundation
import Alamofire

public typealias ProgressHandler = (Double) -> Void

/// Actor-wrapped RemoteService using only Alamofire public API.
/// Async APIs return (UUID, Result<...>) so caller always receives request id.
public actor RemoteService {
    public static let shared = RemoteService()

    private var session: Session
    private let defaultValidateRange: ClosedRange<Int> = 200...299

    /// Active requests keyed by DataRequest.id (UUID)
    private var activeRequests: [UUID: Alamofire.Request] = [:]

    public init(session: Session? = nil, authInterceptor: AuthInterceptorType? = nil) {
        if let s = session {
            self.session = s
        } else {
            let interceptor = AlamofireAuthInterceptor(authInterceptor: authInterceptor)
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 60
            self.session = Session(configuration: cfg, interceptor: interceptor)
        }
    }

    // MARK: - Helpers to manage activeRequests
    private func store(_ request: Alamofire.Request) {
        activeRequests[request.id] = request
    }
    private func remove(id: UUID) {
        activeRequests.removeValue(forKey: id)
    }

    // Cancel helpers (actor-isolated)
    public func cancelRequest(id: UUID) {
        if let r = activeRequests[id] {
            r.cancel()
            activeRequests.removeValue(forKey: id)
        }
    }
    public func cancelAll() {
        for (_, r) in activeRequests { r.cancel() }
        activeRequests.removeAll()
    }

    // MARK: - Async JSON request (URLConvertible, parameters)
    /// Performs HTTP request and returns AF Data + HTTPURLResponse wrapped in Result with the request id.
    public func request<Parameters: Encodable & Sendable>(url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: Parameters? = nil,
                        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                        headers: HTTPHeaders? = nil,
                        validateRange: ClosedRange<Int>? = nil) async -> (UUID, Result<(Data, HTTPURLResponse), RemoteRequestError>) {
        let req = session.request(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
        store(req)
        let id = req.id

        do {
            // use AF's native async API
            let data = try await req.serializingData().value
            // after await, get response
            if let http = req.response {
                let range = validateRange ?? defaultValidateRange
                if !range.contains(http.statusCode) {
                    remove(id: id)
                    return (id, .failure(.statusCode(http.statusCode, data)))
                }
                remove(id: id)
                return (id, .success((data, http)))
            } else {
                remove(id: id)
                return (id, .failure(.unknown))
            }
        } catch {
            remove(id: id)
            if let af = error as? AFError { return (id, .failure(.afError(af))) }
            if (error as NSError).code == NSURLErrorCancelled { return (id, .failure(.cancelled)) }
            return (id, .failure(.underlying(error)))
        }
    }

    /// Convenience: decode to Decodable
    public func requestDecodable<T: Decodable, Parameters: Encodable & Sendable>(url: URLConvertible,
                                               method: HTTPMethod = .get,
                                               parameters: Parameters? = nil,
                                               encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                               headers: HTTPHeaders? = nil,
                                               validateRange: ClosedRange<Int>? = nil,
                                               decoder: JSONDecoder = JSONDecoder()) async -> (UUID, Result<T, RemoteRequestError>) {
        let (id, raw) = await request(url: url, method: method, parameters: parameters, encoder: encoder, headers: headers, validateRange: validateRange)
        switch raw {
        case .failure(let e): return (id, .failure(e))
        case .success(let (data, _)):
            do {
                let model = try decoder.decode(T.self, from: data)
                return (id, .success(model))
            } catch {
                return (id, .failure(.decoding(error, data)))
            }
        }
    }

    // MARK: - Block API for JSON request (returns DataRequest.id)
    @discardableResult
    public func request<Parameters: Encodable & Sendable>(url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: Parameters? = nil,
                        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                        headers: HTTPHeaders? = nil,
                        validateRange: ClosedRange<Int>? = nil,
                        completion: @escaping @Sendable (Result<(Data, HTTPURLResponse), RemoteRequestError>) -> Void) -> UUID {
        let req = session.request(url, method: method, parameters: parameters, encoder: encoder, headers: headers)
        store(req)
        let id = req.id

        req.responseData { [weak self] resp in
            // cleanup inside actor context
            _Concurrency.Task { [weak self] in
                guard let self = self else { return }
                
                await self.remove(id: id)
            }

            if let err = resp.error {
                if (err as NSError).code == NSURLErrorCancelled { completion(.failure(.cancelled)); return }
                if let af = err as? AFError { completion(.failure(.afError(af))); return }
                completion(.failure(.underlying(err))); return
            }

            guard let http = resp.response else { completion(.failure(.unknown)); return }
            switch resp.result {
            case .success(let data):
                let range = validateRange ?? self?.defaultValidateRange ?? 200...299
                if !range.contains(http.statusCode) { completion(.failure(.statusCode(http.statusCode, data))); return }
                completion(.success((data, http)))
            case .failure(let err):
                if let af = err as? AFError { completion(.failure(.afError(af))) }
                else { completion(.failure(.underlying(err))) }
            }
        }

        return id
    }

    @discardableResult
    public func requestDecodable<T: Decodable, Parameters: Encodable & Sendable>(url: URLConvertible,
                                               method: HTTPMethod = .get,
                                               parameters: Parameters? = nil,
                                               encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                               headers: HTTPHeaders? = nil,
                                               validateRange: ClosedRange<Int>? = nil,
                                               decoder: JSONDecoder = JSONDecoder(),
                                               completion: @escaping @Sendable (Result<T, RemoteRequestError>) -> Void) -> UUID {
        let id = request(url: url, method: method, parameters: parameters, encoder: encoder, headers: headers, validateRange: validateRange) { result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let (data, _)):
                do {
                    let obj = try decoder.decode(T.self, from: data)
                    completion(.success(obj))
                } catch {
                    completion(.failure(.decoding(error, data)))
                }
            }
        }
        return id
    }

    // MARK: - Upload: multipart with optional manual mime types.
    /// manualMimeTypes: optional map filename -> mimeType; if nil or missing entry, auto-detect via Utilities.mimeType
    public func uploadMultipart<T: Decodable>(to url: URLConvertible,
                                              multipartFiles: [(fieldName: String, fileURL: URL, fileName: String, manualMime: String?)],
                                              parameters: [String: String]? = nil,
                                              method: HTTPMethod = .post,
                                              headers: HTTPHeaders? = nil,
                                              decoder: JSONDecoder = JSONDecoder(),
                                              validateRange: ClosedRange<Int>? = nil) async -> (UUID, Result<T, RemoteRequestError>) {
        // build request via session.upload(multipartFormData:to:)
        // Use AF's async flow via serializingData on returned UploadRequest
        let uploadReq = session.upload(multipartFormData: { mp in
            // append parameters
            if let params = parameters {
                for (k, v) in params {
                    if let data = v.data(using: .utf8) { mp.append(data, withName: k) }
                }
            }
            // append files
            for file in multipartFiles {
                let mime = MIME.mimeType(for: file.fileURL, manual: file.manualMime)
                mp.append(file.fileURL, withName: file.fieldName, fileName: file.fileName, mimeType: mime)
            }
        }, to: url, method: method, headers: headers)

        store(uploadReq)
        let id = uploadReq.id

        do {
            let data = try await uploadReq.serializingData().value
            if let http = uploadReq.response {
                let range = validateRange ?? defaultValidateRange
                if !range.contains(http.statusCode) {
                    remove(id: id); return (id, .failure(.statusCode(http.statusCode, data)))
                }
                remove(id: id)
                do {
                    let obj = try decoder.decode(T.self, from: data)
                    return (id, .success(obj))
                } catch {
                    return (id, .failure(.decoding(error, data)))
                }
            } else {
                remove(id: id)
                return (id, .failure(.unknown))
            }
        } catch {
            remove(id: id)
            if let af = error as? AFError { return (id, .failure(.afError(af))) }
            if (error as NSError).code == NSURLErrorCancelled { return (id, .failure(.cancelled)) }
            return (id, .failure(.underlying(error)))
        }
    }

    /// Block API for multipart upload
    @discardableResult
    public func uploadMultipart<T: Decodable>(to url: URLConvertible,
                                              multipartFiles: [(fieldName: String, fileURL: URL, fileName: String, manualMime: String?)],
                                              parameters: [String: String]? = nil,
                                              method: HTTPMethod = .post,
                                              headers: HTTPHeaders? = nil,
                                              decoder: JSONDecoder = JSONDecoder(),
                                              validateRange: ClosedRange<Int>? = nil,
                                              progress: Alamofire.Request.ProgressHandler? = nil,
                                              completion: @escaping @Sendable (Result<T, RemoteRequestError>) -> Void) -> UUID {
        let req = session.upload(multipartFormData: { mp in
            if let params = parameters {
                for (k, v) in params { if let d = v.data(using: .utf8) { mp.append(d, withName: k) } }
            }
            for file in multipartFiles {
                let mime = MIME.mimeType(for: file.fileURL, manual: file.manualMime)
                mp.append(file.fileURL, withName: file.fieldName, fileName: file.fileName, mimeType: mime)
            }
        }, to: url, method: method, headers: headers)

        store(req)
        let id = req.id

        req.uploadProgress { p in progress?(p) }
           .responseData { [weak self] resp in
            _Concurrency.Task { [weak self] in
                guard let self = self else { return }

                await self.remove(id: id)
            }
            if let err = resp.error {
                if (err as NSError).code == NSURLErrorCancelled { completion(.failure(.cancelled)); return }
                if let af = err as? AFError { completion(.failure(.afError(af))); return }
                completion(.failure(.underlying(err))); return
            }
            guard let http = resp.response else { completion(.failure(.unknown)); return }
            switch resp.result {
            case .success(let data):
                let range = validateRange ?? self?.defaultValidateRange ?? 200...299
                if !range.contains(http.statusCode) { completion(.failure(.statusCode(http.statusCode, data))); return }
                do {
                    let obj = try decoder.decode(T.self, from: data)
                    completion(.success(obj))
                } catch {
                    completion(.failure(.decoding(error, data)))
                }
            case .failure(let err):
                if let af = err as? AFError { completion(.failure(.afError(af))) }
                else { completion(.failure(.underlying(err))) }
            }
        }

        return id
    }

    // MARK: - Download
    /// Async download: optional destinationURL; if nil use AF suggested destination
    public func download(from url: URLConvertible,
                         to destinationURL: URL? = nil,
                         headers: HTTPHeaders? = nil,
                         progress: ProgressHandler? = nil,
                         validateRange: ClosedRange<Int>? = nil) async -> (UUID, Result<URL, RemoteRequestError>) {
        let destination: DownloadRequest.Destination
        if let dest = destinationURL {
            destination = { _, _ in (dest, [.removePreviousFile, .createIntermediateDirectories]) }
        } else {
            destination = DownloadRequest.suggestedDownloadDestination()
        }

        let req = session.download(url, headers: headers, to: destination)
        store(req)
        let id = req.id

        do {
            let fileUrl = try await req.serializingDownloadedFileURL().value
            // AF's downloaded file response has response stored
            if let http = req.response {
                let range = validateRange ?? defaultValidateRange
                // Note: for downloads AF may not include data; we still check status
                if !range.contains(http.statusCode) {
                    remove(id: id); return (id, .failure(.statusCode(http.statusCode, nil)))
                }
            }
            remove(id: id)
            return (id, .success(fileUrl))
        } catch {
            remove(id: id)
            if let af = error as? AFError { return (id, .failure(.afError(af))) }
            if (error as NSError).code == NSURLErrorCancelled { return (id, .failure(.cancelled)) }
            return (id, .failure(.underlying(error)))
        }
    }

    /// Block download
    @discardableResult
    public func download(from url: URLConvertible,
                         to destinationURL: URL? = nil,
                         headers: HTTPHeaders? = nil,
                         progress: Alamofire.Request.ProgressHandler? = nil,
                         validateRange: ClosedRange<Int>? = nil,
                         completion: @escaping @Sendable (Result<URL, RemoteRequestError>) -> Void) -> UUID {
        let destination: DownloadRequest.Destination
        if let dest = destinationURL {
            destination = { _, _ in (dest, [.removePreviousFile, .createIntermediateDirectories]) }
        } else {
            destination = DownloadRequest.suggestedDownloadDestination()
        }

        let req = session.download(url, headers: headers, to: destination)
        store(req)
        let id = req.id

        req.downloadProgress { p in progress?(p) }
           .response { [weak self] resp in
            _Concurrency.Task { await self?.remove(id: id) }
            if let err = resp.error {
                if (err as NSError).code == NSURLErrorCancelled { completion(.failure(.cancelled)); return }
                if let af = err as? AFError { completion(.failure(.afError(af))); return }
                completion(.failure(.underlying(err))); return
            }
            if let fileUrl = resp.fileURL {
                completion(.success(fileUrl))
            } else {
                completion(.failure(.unknown))
            }
        }

        return id
    }
}
