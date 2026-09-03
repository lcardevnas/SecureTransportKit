# Quickstart: HTTP Transport

## Prerequisites

- Link `HTTPTransport`.
- Supply a base URL and, when required, application-specific JSON coding.

## Validation Scenario

```swift
import HTTPTransport

let client = JSONAPIClient(
    baseURL: URL(string: "https://example.invalid")!,
    client: URLSessionHTTPClient()
)
let request = HTTPRequest<Data>(
    pathComponents: ["resources", "opaque/value"],
    queryItems: [URLQueryItem(name: "page", value: "1")]
)
let response = try await client.sendRaw(request)
```

The second dynamic value remains one encoded path segment. Run
`swift test --filter HTTPTransportTests` and expect request construction, custom statuses, raw
responses, and error classifications to pass. Replace the placeholder base URL with one owned by the
consuming application; concrete routes remain in its repositories.
