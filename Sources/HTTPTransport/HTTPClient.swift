import Foundation

/// Executes fully constructed URL requests and returns raw HTTP responses.
///
/// Conforming transports do not decide which status codes are successful; that policy belongs to
/// ``HTTPRequest`` and is applied by ``JSONAPIClient``.
public protocol HTTPClient: Sendable {
    /// Executes a URL request.
    ///
    /// - Parameter request: A fully constructed request.
    /// - Returns: Raw HTTP response metadata and body bytes.
    /// - Throws: ``HTTPTransportError`` or a conforming transport's documented error.
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

/// An ``HTTPClient`` backed by Foundation's `URLSession`.
public struct URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession

    /// Creates a URLSession-backed transport.
    ///
    /// - Parameter session: The session used to execute requests. Inject a configured or ephemeral
    ///   session when the shared session is inappropriate.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Executes a URL request and classifies common connectivity failures.
    ///
    /// HTTP status codes are returned unchanged, including `4xx` and `5xx`; validation happens in
    /// ``JSONAPIClient/sendRaw(_:)``.
    ///
    /// - Parameter request: A fully constructed request.
    /// - Returns: The raw HTTP response.
    /// - Throws: ``HTTPTransportError/invalidResponse`` for a non-HTTP response, or another
    ///   ``HTTPTransportError`` classified from the underlying operation.
    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPTransportError.invalidResponse
            }
            let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, entry in
                result[String(describing: entry.key)] = String(describing: entry.value)
            }
            return HTTPResponse(data: data, statusCode: http.statusCode, headers: headers)
        } catch let error as HTTPTransportError {
            throw error
        } catch {
            throw Self.classify(error)
        }
    }

    static func classify(_ error: any Error) -> HTTPTransportError {
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return .offline
            default: return .transport(error.localizedDescription)
            }
        }
        if error is CancellationError { return .cancelled }
        return .transport(error.localizedDescription)
    }
}
