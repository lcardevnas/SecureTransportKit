import Foundation

/// HTTP methods supported by ``HTTPRequest``.
public enum HTTPMethod: String, Sendable {
    /// Retrieves a representation without requesting a state change.
    case get = "GET"
    /// Submits a new representation or operation.
    case post = "POST"
    /// Replaces a representation.
    case put = "PUT"
    /// Partially updates a representation.
    case patch = "PATCH"
    /// Removes a representation.
    case delete = "DELETE"
}

/// Authorization schemes that ``JSONAPIClient`` can apply to a request.
public enum HTTPAuthorization: Sendable {
    /// Adds an `Authorization: Bearer <token>` header when the URL request is built.
    ///
    /// The token is opaque and must never be logged or exposed through error descriptions.
    case bearer(String)
}

/// Defines which HTTP status codes indicate a successful request.
///
/// Every value in `200..<300` is always accepted. Additional codes support conditional requests or
/// backend-specific success semantics without embedding them in the transport layer.
public struct AcceptedHTTPStatus: Sendable {
    private var additional: Set<Int>

    /// Creates a success policy containing all `2xx` responses plus optional additional codes.
    ///
    /// - Parameter additional: Non-`2xx` status codes that should also be treated as successful.
    public init(additional: Set<Int> = []) {
        self.additional = additional
    }

    /// Returns whether a status code satisfies this success policy.
    ///
    /// - Parameter status: The HTTP status code to evaluate.
    /// - Returns: `true` for all `2xx` values and explicitly added codes.
    public func contains(_ status: Int) -> Bool {
        (200..<300).contains(status) || additional.contains(status)
    }

    /// The default policy that accepts only `2xx` responses.
    public static let successful = AcceptedHTTPStatus()
}

/// A backend-neutral HTTP request and its expected decoded response type.
///
/// Each item in ``pathComponents`` is percent-encoded as one path segment. Consumers should supply
/// raw values rather than pre-encoded strings.
public struct HTTPRequest<Response>: Sendable {
    /// Ordered, unescaped path segments appended to the client's base URL.
    public var pathComponents: [String]

    /// The HTTP method used for the request.
    public var method: HTTPMethod

    /// Query parameters encoded by `URLComponents`.
    public var queryItems: [URLQueryItem]

    /// Additional request headers. Header names are compared case-insensitively by `URLRequest`.
    public var headers: [String: String]

    /// Optional authorization applied while the concrete `URLRequest` is built.
    public var authorization: HTTPAuthorization?

    /// Optional, already-encoded request body.
    public var body: Data?

    /// Optional request timeout in seconds. `nil` preserves the `URLRequest` default.
    public var timeout: TimeInterval?

    /// The status-code policy used before a response is returned or decoded.
    public var acceptedStatus: AcceptedHTTPStatus

    /// The response metatype carried for compile-time request/response association.
    public var responseType: Response.Type

    /// Creates a backend-neutral HTTP request.
    ///
    /// - Parameters:
    ///   - pathComponents: Raw path segments appended individually to the base URL.
    ///   - method: The HTTP method. Defaults to ``HTTPMethod/get``.
    ///   - queryItems: Query parameters encoded by `URLComponents`.
    ///   - headers: Additional request headers.
    ///   - authorization: Optional authorization information.
    ///   - body: An optional, already-encoded body.
    ///   - timeout: An optional timeout in seconds.
    ///   - acceptedStatus: The status-code success policy.
    ///   - response: The type expected when the response is decoded.
    public init(
        pathComponents: [String],
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        authorization: HTTPAuthorization? = nil,
        body: Data? = nil,
        timeout: TimeInterval? = nil,
        acceptedStatus: AcceptedHTTPStatus = .successful,
        response: Response.Type = Response.self
    ) {
        self.pathComponents = pathComponents
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.authorization = authorization
        self.body = body
        self.timeout = timeout
        self.acceptedStatus = acceptedStatus
        self.responseType = response
    }
}

/// Raw, immutable-by-convention HTTP response data returned by a transport.
public struct HTTPResponse: Sendable {
    /// The response body bytes.
    public var data: Data

    /// The numeric HTTP status code.
    public var statusCode: Int

    /// Response headers normalized to string keys and values.
    public var headers: [String: String]

    /// Creates a raw HTTP response.
    ///
    /// - Parameters:
    ///   - data: The response body bytes.
    ///   - statusCode: The numeric HTTP status code.
    ///   - headers: Response headers represented as strings.
    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }

    /// Looks up a response header without regard to the header-name casing.
    ///
    /// - Parameter name: The header name to locate.
    /// - Returns: The header value, or `nil` when the header is absent.
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// Backend-neutral failures raised while building, sending, validating, or decoding HTTP requests.
public enum HTTPTransportError: Error, Sendable {
    /// The network is unavailable or the connection was lost.
    case offline
    /// The operation was cancelled.
    case cancelled
    /// The operation exceeded its timeout.
    case timedOut
    /// The underlying transport returned a response that was not HTTP.
    case invalidResponse
    /// The base URL and request components could not form a valid URL.
    case invalidURL
    /// A request value could not be encoded. The associated text is diagnostic and must not contain secrets.
    case encoding(String)
    /// A response body could not be decoded. The associated text is diagnostic and must not contain secrets.
    case decoding(String)
    /// The response status did not satisfy the request's ``AcceptedHTTPStatus`` policy.
    case unsuccessful(HTTPResponse)
    /// The underlying transport failed for a reason outside the explicitly classified categories.
    ///
    /// The associated text is diagnostic and must not contain authorization headers or tokens.
    case transport(String)
}
