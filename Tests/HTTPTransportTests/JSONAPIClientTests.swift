import Foundation
@testable import HTTPTransport
import Testing

private actor RecordingHTTPClient: HTTPClient {
    var responses: [HTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [HTTPResponse]) { self.responses = responses }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}

private struct Message: Codable, Equatable { var value: String }

struct JSONAPIClientTests {
    @Test func buildsAndDecodesRequest() async throws {
        let transport = RecordingHTTPClient([
            HTTPResponse(data: try JSONEncoder().encode(Message(value: "ok")), statusCode: 200)
        ])
        let client = JSONAPIClient(baseURL: URL(string: "https://example.com/api")!, transport: transport)
        let request = HTTPRequest<Message>(
            pathComponents: ["items", "opaque/token"],
            method: .post,
            queryItems: [URLQueryItem(name: "q", value: "hello world")],
            body: try client.encode(Message(value: "request"))
        )

        #expect(try await client.send(request) == Message(value: "ok"))
        let sent = try #require(await transport.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString.contains("opaque%2Ftoken") == true)
        #expect(sent.url?.query?.contains("q=hello%20world") == true)
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func acceptsAdditionalStatus() async throws {
        let transport = RecordingHTTPClient([HTTPResponse(data: Data(), statusCode: 304)])
        let client = JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
        let request = HTTPRequest<Data>(
            pathComponents: ["catalogue"],
            acceptedStatus: AcceptedHTTPStatus(additional: [304])
        )
        #expect(try await client.sendRaw(request).statusCode == 304)
    }

    @Test func rejectsUnexpectedStatusWithResponseContext() async {
        let transport = RecordingHTTPClient([
            HTTPResponse(data: Data("no".utf8), statusCode: 409, headers: ["Retry-After": "10"])
        ])
        let client = JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
        let request = HTTPRequest<Data>(pathComponents: ["conflict"])
        do {
            _ = try await client.sendRaw(request)
            Issue.record("Expected an unsuccessful response")
        } catch HTTPTransportError.unsuccessful(let response) {
            #expect(response.statusCode == 409)
            #expect(response.data == Data("no".utf8))
            #expect(response.header("retry-after") == "10")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func preservesMethodHeadersBodyTimeoutAndEmptySuccess() async throws {
        for method in [HTTPMethod.get, .post, .put, .patch, .delete] {
            let transport = RecordingHTTPClient([HTTPResponse(data: Data(), statusCode: 204)])
            let client = JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
            let body = Data("payload".utf8)
            let request = HTTPRequest<Data>(
                pathComponents: ["items"], method: method,
                headers: ["X-Test": "value"], body: body, timeout: 7
            )

            #expect(try await client.sendRaw(request).statusCode == 204)
            let sent = try #require(await transport.requests.first)
            #expect(sent.httpMethod == method.rawValue)
            #expect(sent.value(forHTTPHeaderField: "X-Test") == "value")
            #expect(sent.httpBody == body)
            #expect(sent.timeoutInterval == 7)
        }
    }

    @Test func encodesEveryOpaqueValueAsOnePathComponent() throws {
        let client = JSONAPIClient(
            baseURL: URL(string: "https://example.com/root")!,
            transport: RecordingHTTPClient([])
        )
        let request = HTTPRequest<Data>(pathComponents: ["opaque/value", "a+b=c", "literal%2Ftext"])
        let url = try #require(client.urlRequest(for: request).url)
        #expect(url.absoluteString == "https://example.com/root/opaque%2Fvalue/a%2Bb%3Dc/literal%252Ftext")
    }

    @Test func classifiesConnectivityCancellationAndTimeout() {
        for (input, expected) in [
            (URLError(.notConnectedToInternet), "offline"),
            (URLError(.networkConnectionLost), "offline"),
            (URLError(.cannotConnectToHost), "offline"),
            (URLError(.timedOut), "timedOut"),
            (URLError(.cancelled), "cancelled"),
        ] {
            let classified = URLSessionHTTPClient.classify(input)
            switch (classified, expected) {
            case (.offline, "offline"), (.timedOut, "timedOut"), (.cancelled, "cancelled"): break
            default: Issue.record("Unexpected classification: \(classified)")
            }
        }
        if case .cancelled = URLSessionHTTPClient.classify(CancellationError()) {} else {
            Issue.record("CancellationError was not classified as cancelled")
        }
    }

    @Test func reportsInvalidJSONAsDecodingFailure() async {
        let transport = RecordingHTTPClient([HTTPResponse(data: Data("{".utf8), statusCode: 200)])
        let client = JSONAPIClient(baseURL: URL(string: "https://example.com")!, transport: transport)
        await #expect(throws: HTTPTransportError.self) {
            try await client.send(HTTPRequest<Message>(pathComponents: ["message"]))
        }
    }
}
