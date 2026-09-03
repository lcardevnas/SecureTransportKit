import Foundation
import HTTPTransport
import SecureSession

/// Marks an ``HTTPRequest`` as requiring session authentication.
///
/// Wrapping is explicit so plain requests cannot receive credentials accidentally. Authentication
/// challenge replay is configurable per request and remains bounded to one additional attempt.
public struct AuthenticatedHTTPRequest<Response>: Sendable {
    /// The backend-neutral request to authorize and execute.
    public var request: HTTPRequest<Response>

    /// Whether a configured authentication challenge may trigger one refresh and replay.
    public var retriesAuthenticationChallenge: Bool

    /// HTTP status codes interpreted as authentication challenges. The default is `401`.
    public var authenticationChallengeStatuses: Set<Int>

    /// Creates an explicitly authenticated request.
    ///
    /// Disable replay for operations that the backend cannot safely receive twice. Even when replay
    /// is enabled, the client performs at most one refresh and one additional send.
    ///
    /// - Parameters:
    ///   - request: The request to authorize.
    ///   - retriesAuthenticationChallenge: Whether one refresh/replay cycle is permitted.
    ///   - authenticationChallengeStatuses: Status codes that trigger the cycle.
    public init(
        _ request: HTTPRequest<Response>,
        retriesAuthenticationChallenge: Bool = true,
        authenticationChallengeStatuses: Set<Int> = [401]
    ) {
        self.request = request
        self.retriesAuthenticationChallenge = retriesAuthenticationChallenge
        self.authenticationChallengeStatuses = authenticationChallengeStatuses
    }
}

/// Adds session authorization to explicitly authenticated requests and coordinates one challenge replay.
///
/// The client contains no endpoints, retry backoff, or backend-error interpretation. It obtains tokens
/// from ``SecureSessionStore`` and delegates request construction, execution, and status validation to
/// ``JSONAPIClient``.
public struct AuthenticatedHTTPClient: Sendable {
    /// The generic JSON/HTTP client used for both the initial send and optional replay.
    public let client: JSONAPIClient

    /// The actor-isolated owner of access and refresh credentials.
    public let sessionStore: SecureSessionStore

    /// Creates an authenticated decorator around a generic JSON/HTTP client.
    ///
    /// - Parameters:
    ///   - client: The client that builds, executes, and validates requests.
    ///   - sessionStore: The session owner that supplies and refreshes access tokens.
    public init(client: JSONAPIClient, sessionStore: SecureSessionStore) {
        self.client = client
        self.sessionStore = sessionStore
    }

    /// Sends an authenticated request without decoding the response body.
    ///
    /// A Bearer header is added to a copy of the wrapped request. When the first response has a
    /// configured challenge status and replay is enabled, the session is refreshed and the original
    /// request is rebuilt with the replacement token. A challenge from the replay is returned as an
    /// error without another refresh.
    ///
    /// - Parameter authenticated: An explicitly authenticated request and its replay policy.
    /// - Returns: The accepted raw response from the initial send or single replay.
    /// - Throws: Session errors from ``SecureSessionStore`` or transport/status errors from
    ///   ``JSONAPIClient/sendRaw(_:)``.
    public func sendRaw<Response>(_ authenticated: AuthenticatedHTTPRequest<Response>) async throws -> HTTPResponse {
        let token = try await sessionStore.accessToken()
        do {
            return try await send(authenticated.request, accessToken: token)
        } catch HTTPTransportError.unsuccessful(let response)
            where authenticated.retriesAuthenticationChallenge
                && authenticated.authenticationChallengeStatuses.contains(response.statusCode) {
            let refreshed = try await sessionStore.refresh(replacing: token)
            return try await send(authenticated.request, accessToken: refreshed.accessToken)
        }
    }

    /// Sends an authenticated request and decodes its accepted response body.
    ///
    /// - Parameter authenticated: An explicitly authenticated request and its replay policy.
    /// - Returns: The decoded response value associated with the wrapped request.
    /// - Throws: ``HTTPTransportError/decoding(_:)``, session errors, or errors documented by
    ///   ``sendRaw(_:)``.
    public func send<Response: Decodable>(
        _ authenticated: AuthenticatedHTTPRequest<Response>
    ) async throws -> Response {
        let response = try await sendRaw(authenticated)
        do { return try client.coding.decode(Response.self, from: response.data) }
        catch { throw HTTPTransportError.decoding(String(describing: error)) }
    }

    private func send<Response>(_ request: HTTPRequest<Response>, accessToken: String) async throws -> HTTPResponse {
        var authorised = request
        authorised.authorization = .bearer(accessToken)
        return try await client.sendRaw(authorised)
    }
}
