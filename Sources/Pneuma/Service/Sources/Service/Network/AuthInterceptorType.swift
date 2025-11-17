import Foundation

/// Async-capable auth interceptor abstraction (dependency-injection).
/// Implementations must be Sendable (or explicitly annotated @unchecked Sendable).
public protocol AuthInterceptorType: Sendable {
    /// Called before request is sent. Return mutated URLRequest (e.g. add Authorization header).
    func prepare(_ request: URLRequest) async throws -> URLRequest

    /// Called when authentication failure occurs (e.g. HTTP 401).
    /// Return true if interceptor handled refresh and caller may retry the original request.
    func handleAuthenticationFailure(originalRequest: URLRequest, response: HTTPURLResponse?, error: Error?) async -> Bool
}
