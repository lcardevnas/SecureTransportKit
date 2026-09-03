import AuthenticatedHTTP
import Foundation
import HTTPTransport
import SecureSession
import SecureStorage

private final class ExampleMemoryStorage: SecureValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SecureValueKey: Data] = [:]

    func write(_ data: Data, for key: SecureValueKey) throws {
        lock.withLock { values[key] = data }
    }

    func read(_ key: SecureValueKey) throws -> Data? {
        lock.withLock { values[key] }
    }

    func delete(_ key: SecureValueKey) throws {
        lock.withLock { values[key] = nil }
    }
}

private actor ExampleBackend: HTTPClient, SessionRefreshClient {
    private var challenged = false

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        if !challenged {
            challenged = true
            return HTTPResponse(data: Data(), statusCode: 401)
        }
        return HTTPResponse(data: Data(), statusCode: 204)
    }

    func refresh(using refreshToken: String) async -> SessionRefreshResult {
        .success(SessionCredentials(
            accessToken: "replacement-access",
            refreshToken: "replacement-refresh",
            expiresAt: .now.addingTimeInterval(3_600),
            subjectID: "example-subject"
        ))
    }
}

/// Minimal composition example. A real app supplies its own base URL, routes, and refresh adapter.
func runExample() async throws {
    let backend = ExampleBackend()
    let session = SecureSessionStore(
        refreshClient: backend,
        storage: ExampleMemoryStorage(),
        configuration: SecureSessionConfiguration(
            key: SecureValueKey(service: "com.example.app", account: "session"),
            markerKey: "example.installation"
        )
    )
    try await session.adopt(SessionCredentials(
        accessToken: "initial-access",
        refreshToken: "initial-refresh",
        expiresAt: .now.addingTimeInterval(3_600),
        subjectID: "example-subject"
    ))

    let plain = JSONAPIClient(baseURL: URL(string: "https://example.invalid")!, transport: backend)
    let authenticated = AuthenticatedHTTPClient(client: plain, sessionStore: session)
    let request = HTTPRequest<Data>(pathComponents: ["protected-resource"])
    _ = try await authenticated.sendRaw(AuthenticatedHTTPRequest(request))
}
