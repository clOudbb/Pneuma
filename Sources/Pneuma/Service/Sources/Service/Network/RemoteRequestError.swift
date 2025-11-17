import Foundation
import Alamofire

public enum RemoteRequestError: Error, CustomStringConvertible {
    case afError(AFError)
    case underlying(Error)
    case statusCode(Int, Data?)
    case decoding(Error, Data?)
    case cancelled
    case invalidURL
    case unknown

    public var description: String {
        switch self {
        case .afError(let af): return "AFError: \(af)"
        case .underlying(let e): return "Underlying: \(e)"
        case .statusCode(let c, _): return "HTTP status \(c)"
        case .decoding(let e, _): return "Decoding: \(e)"
        case .cancelled: return "Cancelled"
        case .invalidURL: return "Invalid URL"
        case .unknown: return "Unknown"
        }
    }
}
