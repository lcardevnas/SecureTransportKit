import AuthenticatedHTTP
import Foundation
import HTTPTransport
import SecureSession
import SecureStorage
import Testing

private final class MemoryStore: SecureValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?
    func write(_ data: Data, for key: SecureValueKey) { lock.withLock { value = data } }
    func read(_ key: SecureValueKey) -> Data? { lock.withLock { value } }
    func delete(_ key: SecureValueKey) { lock.withLock { value = nil } }
}

private actor RefreshClient: SessionRefreshClient {
    private(set) var calls = 0
    func refresh(using refreshToken: String) async -> SessionRefreshResult {
        calls += 1
        return .success(.init(
            accessToken: "new-token", refreshToken: "new-refresh",
            expiresAt: .now.addingTimeInterval(3_600), subjectID: "subject"
        ))
    }
}

private actor SequenceHTTPClient: HTTPClient {
    var responses: [HTTPResponse]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}

private actor ChallengeByTokenHTTPClient: HTTPClient {
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        let isStale = request.value(forHTTPHeaderField: "Authorization") == "Bearer old-token"
        return HTTPResponse(data: Data(), statusCode: isStale ? 401 : 204)
    }
}

struct AuthenticatedHTTPClientTests {
    private func makeStore(refresh: RefreshClient) async throws -> SecureSessionStore {
        let store = SecureSessionStore(
            refreshClient: refresh, storage: MemoryStore(),
            configuration: .init(
                key: .init(service: "tests", account: UUID().uuidString),
                markerKey: "installed", defaultsSuiteName: "tests.\(UUID())"
            )
        )
        try await store.adopt(.init(
            accessToken: "old-token", refreshToken: "refresh",
            expiresAt: .now.addingTimeInterval(3_600), subjectID: "subject"
        ))
        return store
    }

    @Test func refreshesAndRetriesExactlyOnce() async throws {
        let transport = SequenceHTTPClient([
            HTTPResponse(data: Data(), statusCode: 401),
            HTTPResponse(data: Data(), statusCode: 204),
        ])
        let refresh = RefreshClient()
        let store = SecureSessionStore(
            refreshClient: refresh,
            storage: MemoryStore(),
            configuration: .init(
                key: .init(service: "tests", account: UUID().uuidString),
                markerKey: "installed", defaultsSuiteName: "tests.\(UUID())"
            )
        )
        try await store.adopt(.init(
            accessToken: "old-token", refreshToken: "refresh",
            expiresAt: .now.addingTimeInterval(3_600), subjectID: "subject"
        ))
        let client = AuthenticatedHTTPClient(
            client: JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport),
            sessionStore: store
        )
        let request = AuthenticatedHTTPRequest(HTTPRequest<Data>(pathComponents: ["resource"]))

        #expect(try await client.sendRaw(request).statusCode == 204)
        #expect(await refresh.calls == 1)
        let sent = await transport.requests
        #expect(sent.count == 2)
        #expect(sent[0].value(forHTTPHeaderField: "Authorization") == "Bearer old-token")
        #expect(sent[1].value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
    }

    @Test func secondChallengeIsNotRetried() async throws {
        let transport = SequenceHTTPClient([
            HTTPResponse(data: Data(), statusCode: 401),
            HTTPResponse(data: Data(), statusCode: 401),
        ])
        let refresh = RefreshClient()
        let store = SecureSessionStore(
            refreshClient: refresh, storage: MemoryStore(),
            configuration: .init(
                key: .init(service: "tests", account: UUID().uuidString),
                markerKey: "installed", defaultsSuiteName: "tests.\(UUID())"
            )
        )
        try await store.adopt(.init(
            accessToken: "old", refreshToken: "refresh",
            expiresAt: .now.addingTimeInterval(3_600), subjectID: "subject"
        ))
        let client = AuthenticatedHTTPClient(
            client: JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport),
            sessionStore: store
        )
        let request = AuthenticatedHTTPRequest(HTTPRequest<Data>(pathComponents: ["resource"]))

        await #expect(throws: HTTPTransportError.self) { try await client.sendRaw(request) }
        #expect(await transport.requests.count == 2)
        #expect(await refresh.calls == 1)
    }

    @Test func plainClientNeverAddsSessionCredentials() async throws {
        let transport = SequenceHTTPClient([HTTPResponse(data: Data(), statusCode: 204)])
        let plain = JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
        _ = try await plain.sendRaw(HTTPRequest<Data>(pathComponents: ["public"]))
        #expect(await transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func replayCanBeDisabled() async throws {
        let transport = SequenceHTTPClient([HTTPResponse(data: Data(), statusCode: 401)])
        let refresh = RefreshClient()
        let store = try await makeStore(refresh: refresh)
        let client = AuthenticatedHTTPClient(
            client: JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport),
            sessionStore: store
        )
        let request = AuthenticatedHTTPRequest(
            HTTPRequest<Data>(pathComponents: ["unsafe"]),
            retriesAuthenticationChallenge: false
        )

        await #expect(throws: HTTPTransportError.self) { try await client.sendRaw(request) }
        #expect(await transport.requests.count == 1)
        #expect(await refresh.calls == 0)
    }

    @Test func customChallengeStatusRefreshesOnce() async throws {
        let transport = SequenceHTTPClient([
            HTTPResponse(data: Data(), statusCode: 419),
            HTTPResponse(data: Data(), statusCode: 204),
        ])
        let refresh = RefreshClient()
        let store = try await makeStore(refresh: refresh)
        let client = AuthenticatedHTTPClient(
            client: JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport),
            sessionStore: store
        )
        let request = AuthenticatedHTTPRequest(
            HTTPRequest<Data>(pathComponents: ["custom"]),
            authenticationChallengeStatuses: [419]
        )

        #expect(try await client.sendRaw(request).statusCode == 204)
        #expect(await refresh.calls == 1)
        #expect(await transport.requests.count == 2)
    }

    @Test func concurrentChallengesShareOneRefresh() async throws {
        let transport = ChallengeByTokenHTTPClient()
        let refresh = RefreshClient()
        let store = try await makeStore(refresh: refresh)
        let client = AuthenticatedHTTPClient(
            client: JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport),
            sessionStore: store
        )
        let request = AuthenticatedHTTPRequest(HTTPRequest<Data>(pathComponents: ["shared"]))

        async let first = client.sendRaw(request)
        async let second = client.sendRaw(request)
        #expect(try await [first.statusCode, second.statusCode] == [204, 204])
        #expect(await refresh.calls == 1)
        #expect(await transport.requests.count == 4)
    }
}
