# Public Contract: HTTPTransport

```swift
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct HTTPRequest<Response>: Sendable { /* method, URL inputs, body, policy */ }
public struct HTTPResponse: Sendable { /* data, statusCode, headers */ }
public struct URLSessionHTTPClient: HTTPClient, Sendable
public struct JSONAPIClient: Sendable {
    public func urlRequest<Response>(for request: HTTPRequest<Response>) throws -> URLRequest
    public func sendRaw<Response>(_ request: HTTPRequest<Response>) async throws -> HTTPResponse
    public func send<Response: Decodable>(_ request: HTTPRequest<Response>) async throws -> Response
}
```

`JSONCoding` supplies injectable encode/decode behavior. Authorization is represented as a typed
value so request construction controls header formatting. `sendRaw` validates status without requiring
a response body. New methods or error cases are additive; changing escaping or default accepted
statuses is breaking.
