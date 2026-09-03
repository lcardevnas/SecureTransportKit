import Foundation
import SecureSession
import SecureStorage
import Testing

private final class MemorySecureStore: SecureValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SecureValueKey: Data] = [:]

    func write(_ data: Data, for key: SecureValueKey) {
        lock.withLock { values[key] = data }
    }

    func read(_ key: SecureValueKey) -> Data? {
        lock.withLock { values[key] }
    }

    func delete(_ key: SecureValueKey) {
        lock.withLock { values[key] = nil }
    }
}

private actor StubRefreshClient: SessionRefreshClient {
    private(set) var calls = 0
    var result: SessionRefreshResult

    init(result: SessionRefreshResult) { self.result = result }

    func refresh(using refreshToken: String) async -> SessionRefreshResult {
        calls += 1
        try? await Task.sleep(for: .milliseconds(20))
        return result
    }
}

private func credentials(token: String = "access", expiresAt: Date = .now.addingTimeInterval(3_600)) -> SessionCredentials {
    SessionCredentials(
        accessToken: token,
        refreshToken: "refresh",
        expiresAt: expiresAt,
        subjectID: "subject"
    )
}

private func configuration(suite: String = "secure-transport-kit.tests.\(UUID())") -> SecureSessionConfiguration {
    SecureSessionConfiguration(
        key: SecureValueKey(service: "secure-transport-kit.tests", account: UUID().uuidString),
        markerKey: "installed",
        defaultsSuiteName: suite
    )
}

struct SecureSessionStoreTests {
    @Test func adoptsAndRestoresCredentials() async throws {
        let storage = MemorySecureStore()
        let config = configuration()
        let refresh = StubRefreshClient(result: .success(credentials(token: "unused")))
        let first = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        let original = credentials()
        try await first.adopt(original)

        let relaunched = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        #expect(await relaunched.restore() == original)
    }

    @Test func orphanedKeychainCredentialsAreDiscardedAfterReinstallation() async throws {
        let suite = "secure-transport-kit.tests.\(UUID())"
        let storage = MemorySecureStore()
        let config = configuration(suite: suite)
        let refresh = StubRefreshClient(result: .success(credentials()))
        let first = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        try await first.adopt(credentials())
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)

        let reinstalled = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        #expect(await reinstalled.restore() == nil)
        #expect(storage.read(config.key) == nil)
    }

    @Test func concurrentCallersShareOneRefresh() async throws {
        let refreshed = credentials(token: "new")
        let refresh = StubRefreshClient(result: .success(refreshed))
        let store = SecureSessionStore(
            refreshClient: refresh,
            storage: MemorySecureStore(),
            configuration: configuration()
        )
        try await store.adopt(credentials(expiresAt: .distantPast))

        async let first = store.accessToken()
        async let second = store.accessToken()
        #expect(try await [first, second] == ["new", "new"])
        #expect(await refresh.calls == 1)
    }

    @Test func refreshFailureDispositionControlsSessionLifetime() async throws {
        for disposition in [RefreshFailureDisposition.retainSession, .invalidateSession] {
            let failure = SessionRefreshFailure(disposition: disposition)
            let store = SecureSessionStore(
                refreshClient: StubRefreshClient(result: .failure(failure)),
                storage: MemorySecureStore(),
                configuration: configuration()
            )
            try await store.adopt(credentials(expiresAt: .distantPast))
            await #expect(throws: SecureSessionError.self) { try await store.accessToken() }
            let exists = await store.current != nil
            #expect(exists == (disposition == .retainSession))
        }
    }

    @Test func legacyUserIDFieldMigrates() throws {
        let legacy = """
        {"accessToken":"a","refreshToken":"r","expiresAt":0,"userID":"legacy-user"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SessionCredentials.self, from: legacy)
        #expect(decoded.subjectID == "legacy-user")
    }

    @Test func malformedCredentialsAreRemoved() async {
        let storage = MemorySecureStore()
        let config = configuration()
        storage.write(Data("not-json".utf8), for: config.key)
        let store = SecureSessionStore(
            refreshClient: StubRefreshClient(result: .success(credentials())),
            storage: storage,
            configuration: config
        )

        #expect(await store.restore() == nil)
        #expect(storage.read(config.key) == nil)
    }

    @Test func observersReceiveCommittedLifecycleChanges() async throws {
        let store = SecureSessionStore(
            refreshClient: StubRefreshClient(result: .success(credentials())),
            storage: MemorySecureStore(),
            configuration: configuration()
        )
        let stream = await store.updates()
        let observation = Task { () -> [SessionCredentials?] in
            var iterator = stream.makeAsyncIterator()
            var values: [SessionCredentials?] = []
            if let first = await iterator.next() { values.append(first) }
            if let second = await iterator.next() { values.append(second) }
            return values
        }

        let adopted = credentials(token: "observed")
        try await store.adopt(adopted)
        await store.clear()
        let values = await observation.value
        #expect(values.count == 2)
        #expect(values[0] == adopted)
        #expect(values[1] == nil)
    }

    @Test func preservePolicyRestoresCredentialsWithoutInstallationMarker() async throws {
        let suite = "secure-transport-kit.tests.\(UUID())"
        let storage = MemorySecureStore()
        var config = configuration(suite: suite)
        config.reinstallationPolicy = .preserveCredentials
        let refresh = StubRefreshClient(result: .success(credentials()))
        let first = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        let original = credentials(token: "preserved")
        try await first.adopt(original)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)

        let reinstalled = SecureSessionStore(refreshClient: refresh, storage: storage, configuration: config)
        #expect(await reinstalled.restore() == original)
    }
}
