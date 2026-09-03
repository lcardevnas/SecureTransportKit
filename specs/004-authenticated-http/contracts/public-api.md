# Public Contract: AuthenticatedHTTP

```swift
public struct AuthenticatedHTTPRequest<Response>: Sendable {
    public init(
        _ request: HTTPRequest<Response>,
        retriesAuthenticationChallenge: Bool = true,
        authenticationChallengeStatuses: Set<Int> = [401]
    )
}

public struct AuthenticatedHTTPClient: Sendable {
    public init(client: JSONAPIClient, sessionStore: SecureSessionStore)
    public func sendRaw<Response>(_ request: AuthenticatedHTTPRequest<Response>) async throws -> HTTPResponse
    public func send<Response: Decodable>(_ request: AuthenticatedHTTPRequest<Response>) async throws -> Response
}
```

The first send uses the current valid token. Only a configured rejected status may trigger one refresh
and one second send. The second send cannot refresh recursively. Replay opt-out and custom challenge
sets are source-compatible configuration; changing their defaults is breaking.
