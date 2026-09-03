# Public Contract: SecureSession

```swift
public struct SessionCredentials: Codable, Equatable, Sendable { /* tokens, expiry, subjectID */ }

public protocol SessionRefreshClient: Sendable {
    func refresh(using refreshToken: String) async -> SessionRefreshResult
}

public actor SecureSessionStore {
    public var current: SessionCredentials? { get }
    public func restore() -> SessionCredentials?
    public func adopt(_ credentials: SessionCredentials) throws
    public func clear()
    public func accessToken(now: Date = .now) async throws -> String
    public func refresh(replacing staleAccessToken: String?) async throws -> SessionCredentials
    public func updates() -> AsyncStream<SessionCredentials?>
}
```

The store owns serialization of refresh operations. A refresh adapter is called at most once for one
in-flight stale token. Public failures never embed token values. Configuration controls storage key,
installation marker, defaults suite, leeway, and reinstall policy. Removing legacy `userID` decoding
or changing the default reinstall policy is breaking.
