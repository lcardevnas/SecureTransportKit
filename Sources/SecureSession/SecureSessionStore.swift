import Foundation
import SecureStorage

/// Determines how persisted credentials are handled when no installation marker is present.
public enum ReinstallationPolicy: Sendable {
    /// Deletes Keychain credentials that outlived the application's local installation state.
    case discardOrphanedCredentials

    /// Restores Keychain credentials even when the local installation marker is absent.
    case preserveCredentials
}

/// Configures persistence, expiration, and reinstall behavior for ``SecureSessionStore``.
public struct SecureSessionConfiguration: Sendable {
    /// The secure-storage location used for encoded credentials.
    public var key: SecureValueKey

    /// The `UserDefaults` key that records whether credentials belong to this installation.
    public var markerKey: String

    /// The optional `UserDefaults` suite containing the installation marker.
    public var defaultsSuiteName: String?

    /// The interval before expiration at which an access token is treated as needing refresh.
    public var expirationLeeway: TimeInterval

    /// The behavior applied when Keychain data exists without an installation marker.
    public var reinstallationPolicy: ReinstallationPolicy

    /// Creates session-store configuration.
    ///
    /// - Parameters:
    ///   - key: The secure-storage location for encoded credentials.
    ///   - markerKey: The `UserDefaults` key used as an installation marker.
    ///   - defaultsSuiteName: An optional suite for the marker, or `nil` for standard defaults.
    ///   - expirationLeeway: Seconds before expiration at which renewal begins. Defaults to 60.
    ///   - reinstallationPolicy: How orphaned Keychain credentials are handled.
    public init(
        key: SecureValueKey,
        markerKey: String,
        defaultsSuiteName: String? = nil,
        expirationLeeway: TimeInterval = 60,
        reinstallationPolicy: ReinstallationPolicy = .discardOrphanedCredentials
    ) {
        self.key = key
        self.markerKey = markerKey
        self.defaultsSuiteName = defaultsSuiteName
        self.expirationLeeway = expirationLeeway
        self.reinstallationPolicy = reinstallationPolicy
    }
}

/// Errors produced by ``SecureSessionStore`` lifecycle operations.
public enum SecureSessionError: Error, Equatable, Sendable {
    /// No credentials are currently available.
    case noSession

    /// Credentials could not be encoded or persisted securely.
    case persistenceFailed

    /// The application-provided refresh adapter returned a classified failure.
    case refreshFailed(SessionRefreshFailure)
}

/// Owns persisted credentials and serializes refresh-token exchange.
public actor SecureSessionStore {
    private let refreshClient: any SessionRefreshClient
    private let storage: any SecureValueStore
    private let configuration: SecureSessionConfiguration
    private let defaults: UserDefaults
    private var session: SessionCredentials?
    private var refreshTask: Task<SessionCredentials, any Error>?
    private var observers: [UUID: AsyncStream<SessionCredentials?>.Continuation] = [:]

    /// Creates an actor-isolated session owner.
    ///
    /// Initialization does not read persisted credentials. Call ``restore()`` explicitly during
    /// application startup when restoration is desired.
    ///
    /// - Parameters:
    ///   - refreshClient: The application-owned adapter that exchanges refresh tokens.
    ///   - storage: The secure value store used for credentials.
    ///   - configuration: Persistence, expiration, and reinstall policies.
    public init(
        refreshClient: any SessionRefreshClient,
        storage: any SecureValueStore = KeychainValueStore(),
        configuration: SecureSessionConfiguration
    ) {
        self.refreshClient = refreshClient
        self.storage = storage
        self.configuration = configuration
        self.defaults = configuration.defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The credentials currently held in memory, or `nil` when signed out.
    public var current: SessionCredentials? { session }

    /// Restores credentials from secure storage according to the reinstall policy.
    ///
    /// Missing, malformed, or disallowed orphaned credentials produce `nil`. Malformed and
    /// orphaned data is removed so it cannot repeatedly fail on later launches.
    ///
    /// - Returns: The restored credentials, or `nil` when no usable session exists.
    @discardableResult
    public func restore() -> SessionCredentials? {
        guard let data = try? storage.read(configuration.key) else { return nil }
        guard let stored = try? JSONDecoder().decode(SessionCredentials.self, from: data) else {
            try? storage.delete(configuration.key)
            defaults.removeObject(forKey: configuration.markerKey)
            return nil
        }

        if configuration.reinstallationPolicy == .discardOrphanedCredentials,
           !defaults.bool(forKey: configuration.markerKey) {
            try? storage.delete(configuration.key)
            return nil
        }
        session = stored
        return stored
    }

    /// Replaces the current session and persists it before notifying observers.
    ///
    /// - Parameter credentials: The complete credentials to make current.
    /// - Throws: ``SecureSessionError/persistenceFailed`` when the credentials cannot be stored.
    public func adopt(_ credentials: SessionCredentials) throws {
        session = credentials
        do {
            try persist(credentials)
        } catch {
            session = nil
            throw SecureSessionError.persistenceFailed
        }
        publish(credentials)
    }

    /// Removes credentials from memory and storage and then notifies observers.
    ///
    /// Storage deletion is best-effort so callers can always complete their local sign-out path.
    public func clear() {
        session = nil
        refreshTask = nil
        try? storage.delete(configuration.key)
        defaults.removeObject(forKey: configuration.markerKey)
        publish(nil)
    }

    /// Returns a usable access token, refreshing the session when it is expired or within leeway.
    ///
    /// Concurrent calls that require renewal share the same refresh operation.
    ///
    /// - Parameter now: The instant used for the expiration decision, injectable for deterministic tests.
    /// - Returns: A current access token. The value is opaque and must not be logged.
    /// - Throws: ``SecureSessionError/noSession`` when signed out,
    ///   ``SecureSessionError/refreshFailed(_:)`` when renewal fails, or
    ///   ``SecureSessionError/persistenceFailed`` when refreshed credentials cannot be stored.
    public func accessToken(now: Date = .now) async throws -> String {
        guard let session else { throw SecureSessionError.noSession }
        guard session.expiresAt > now.addingTimeInterval(configuration.expirationLeeway) else {
            return try await refresh(replacing: session.accessToken).accessToken
        }
        return session.accessToken
    }

    /// Refreshes the session unless another caller has already replaced the challenged token.
    ///
    /// This compare-and-refresh behavior lets concurrent `401` responses share one exchange. If
    /// `staleAccessToken` differs from the current token, the current credentials are returned
    /// immediately. Otherwise, concurrent callers await a single in-flight task.
    ///
    /// - Parameter staleAccessToken: The token that triggered renewal, or `nil` to force evaluation
    ///   against the current session without stale-token comparison.
    /// - Returns: The current or newly refreshed credentials.
    /// - Throws: ``SecureSessionError/noSession``, ``SecureSessionError/refreshFailed(_:)``, or
    ///   ``SecureSessionError/persistenceFailed``.
    @discardableResult
    public func refresh(replacing staleAccessToken: String?) async throws -> SessionCredentials {
        if let staleAccessToken, let session, session.accessToken != staleAccessToken {
            return session
        }
        if let refreshTask { return try await refreshTask.value }
        guard let refreshToken = session?.refreshToken else { throw SecureSessionError.noSession }

        let task = Task<SessionCredentials, any Error> { [refreshClient] in
            switch await refreshClient.refresh(using: refreshToken) {
            case .success(let refreshed): refreshed
            case .failure(let failure): throw SecureSessionError.refreshFailed(failure)
            }
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let refreshed = try await task.value
            try adopt(refreshed)
            return refreshed
        } catch let SecureSessionError.refreshFailed(failure) {
            if failure.disposition == .invalidateSession { clear() }
            throw SecureSessionError.refreshFailed(failure)
        } catch {
            throw error
        }
    }

    /// Creates a stream of committed session changes.
    ///
    /// The stream emits future adoptions, successful refreshes, and clear operations in actor order.
    /// It does not emit an initial snapshot; read ``current`` separately when one is required.
    /// Terminating the stream unregisters its continuation from the store.
    ///
    /// - Returns: A stream whose elements contain credentials after adoption or `nil` after clearing.
    public func updates() -> AsyncStream<SessionCredentials?> {
        let id = UUID()
        return AsyncStream { continuation in
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    private func persist(_ credentials: SessionCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try storage.write(data, for: configuration.key)
        defaults.set(true, forKey: configuration.markerKey)
    }

    private func publish(_ credentials: SessionCredentials?) {
        observers.values.forEach { $0.yield(credentials) }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
