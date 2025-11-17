import Alamofire
import Foundation

/// Alamofire 的 RequestInterceptor，内部使用 async/await 风格的 AuthInterceptorType
public final class AlamofireAuthInterceptor: RequestInterceptor {

    private let authInterceptor: AuthInterceptorType?

    public init(authInterceptor: AuthInterceptorType? = nil) {
        self.authInterceptor = authInterceptor
    }

    // MARK: - adapt (nonisolated)

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, Error>) -> Void
    ) {
        guard let auth = authInterceptor else {
            completion(.success(urlRequest))
            return
        }

        Task {
            do {
                let modified = try await auth.prepare(urlRequest)
                await MainActor.run {
                    completion(.success(modified))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - retry (nonisolated)

    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping @Sendable (RetryResult) -> Void
    ) {
        guard let auth = authInterceptor else {
            completion(.doNotRetry)
            return
        }

        let originalRequest = request.request
            ?? URLRequest(url: URL(string: "about:blank")!)

        Task {
            let shouldRetry = await auth.handleAuthenticationFailure(
                originalRequest: originalRequest,
                response: request.response,
                error: error
            )

            await MainActor.run {
                if shouldRetry {
                    completion(.retryWithDelay(0.0))
                } else {
                    completion(.doNotRetryWithError(error))
                }
            }
        }
    }
}

