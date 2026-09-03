import Foundation

/// Encodes request values and decodes response values for ``JSONAPIClient``.
///
/// Applications can provide a conforming value to customize date, key, or data strategies without
/// coupling the transport package to backend DTOs.
public protocol JSONCoding: Sendable {
    /// Encodes a value into request-body bytes.
    ///
    /// - Parameter value: The encodable value.
    /// - Returns: Encoded bytes.
    func encode<T: Encodable>(_ value: T) throws -> Data

    /// Decodes response-body bytes into a value.
    ///
    /// - Parameters:
    ///   - type: The expected response type.
    ///   - data: The response-body bytes.
    /// - Returns: The decoded value.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// Default JSON coding that uses fresh Foundation encoders and decoders.
public struct DefaultJSONCoding: JSONCoding, Sendable {
    /// Creates the default JSON coding policy.
    public init() {}

    /// Encodes a value with a new `JSONEncoder` using Foundation defaults.
    public func encode<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }

    /// Decodes a value with a new `JSONDecoder` using Foundation defaults.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

/// Builds endpoint-free HTTP requests relative to a base URL and applies an injectable coding policy.
public struct JSONAPIClient: Sendable {
    /// The URL against which request path components are resolved.
    public let baseURL: URL

    /// The transport that executes constructed URL requests.
    public let transport: any HTTPClient

    /// The coding policy used for request and response values.
    public let coding: any JSONCoding

    /// Creates a JSON-capable HTTP client.
    ///
    /// - Parameters:
    ///   - baseURL: The application-owned base URL. The package declares no production endpoint.
    ///   - transport: The component that executes URL requests.
    ///   - coding: The encoder and decoder policy for application DTOs.
    public init(
        baseURL: URL,
        transport: any HTTPClient = URLSessionHTTPClient(),
        coding: any JSONCoding = DefaultJSONCoding()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.coding = coding
    }

    /// Encodes a request value with the configured coding policy.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: Encoded request-body bytes.
    /// - Throws: ``HTTPTransportError/encoding(_:)`` when encoding fails.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try coding.encode(value) }
        catch { throw HTTPTransportError.encoding(String(describing: error)) }
    }

    /// Converts a typed request into a Foundation `URLRequest`.
    ///
    /// Path components are escaped independently as RFC 3986 unreserved segments. A body receives
    /// `application/json` as its content type unless the consumer supplied one, and the default
    /// `Accept` header is `application/json`.
    ///
    /// - Parameter request: The backend-neutral request description.
    /// - Returns: A fully constructed URL request.
    /// - Throws: ``HTTPTransportError/invalidURL`` when URL construction fails.
    public func urlRequest<Response>(for request: HTTPRequest<Response>) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HTTPTransportError.invalidURL
        }
        var path = components.percentEncodedPath
        for component in request.pathComponents {
            guard let encoded = Self.encodePathComponent(component) else {
                throw HTTPTransportError.invalidURL
            }
            if !path.hasSuffix("/") { path += "/" }
            path += encoded
        }
        components.percentEncodedPath = path
        if !request.queryItems.isEmpty { components.queryItems = request.queryItems }
        guard let url = components.url else { throw HTTPTransportError.invalidURL }

        var result = URLRequest(url: url)
        result.httpMethod = request.method.rawValue
        result.httpBody = request.body
        request.headers.forEach { result.setValue($0.value, forHTTPHeaderField: $0.key) }
        switch request.authorization {
        case .bearer(let token):
            result.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case nil:
            break
        }
        if request.body != nil, result.value(forHTTPHeaderField: "Content-Type") == nil {
            result.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if result.value(forHTTPHeaderField: "Accept") == nil {
            result.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        if let timeout = request.timeout { result.timeoutInterval = timeout }
        return result
    }

    /// Sends a request and validates its status without decoding the response body.
    ///
    /// - Parameter request: The request to build and execute.
    /// - Returns: The accepted raw HTTP response.
    /// - Throws: ``HTTPTransportError/unsuccessful(_:)`` when the response status is not accepted,
    ///   plus request-construction or transport errors.
    public func sendRaw<Response>(_ request: HTTPRequest<Response>) async throws -> HTTPResponse {
        let response = try await transport.send(urlRequest(for: request))
        guard request.acceptedStatus.contains(response.statusCode) else {
            throw HTTPTransportError.unsuccessful(response)
        }
        return response
    }

    /// Sends a request and decodes an accepted response body.
    ///
    /// - Parameter request: The request whose generic response type will be decoded.
    /// - Returns: The decoded response value.
    /// - Throws: ``HTTPTransportError/decoding(_:)`` when decoding fails, plus the errors documented
    ///   by ``sendRaw(_:)``.
    public func send<Response: Decodable>(_ request: HTTPRequest<Response>) async throws -> Response {
        let response = try await sendRaw(request)
        do { return try coding.decode(Response.self, from: response.data) }
        catch { throw HTTPTransportError.decoding(String(describing: error)) }
    }

    private static func encodePathComponent(_ component: String) -> String? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return component.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
