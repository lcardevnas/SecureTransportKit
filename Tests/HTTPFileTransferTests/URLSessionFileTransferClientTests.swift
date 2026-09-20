import Foundation
@testable import HTTPFileTransfer
import HTTPTransport
import Testing

private struct ProtocolStub: Sendable {
    var statusCode: Int = 200
    var headers: [String: String] = [:]
    var body = Data()
    var error: URLError?
    var returnsHTTPResponse = true
    var delay: TimeInterval = 0
    var capturesRequestBody = true
}

private struct RecordedRequest: @unchecked Sendable {
    var request: URLRequest
    var body: Data
}

private final class ProtocolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var stub = ProtocolStub()
    private var requests: [RecordedRequest] = []
    private var stops = 0

    func configure(_ stub: ProtocolStub) {
        lock.lock()
        self.stub = stub
        requests.removeAll()
        stops = 0
        lock.unlock()
    }

    func currentStub() -> ProtocolStub {
        lock.lock()
        defer { lock.unlock() }
        return stub
    }

    func record(_ request: URLRequest, body: Data) {
        lock.lock()
        requests.append(RecordedRequest(request: request, body: body))
        lock.unlock()
    }

    func firstRequest() -> RecordedRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.first
    }

    func requestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    func recordStop() {
        lock.lock()
        stops += 1
        lock.unlock()
    }

    func stopCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return stops
    }
}

private final class TransferURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ProtocolRegistry()
    private let stateLock = NSLock()
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.registry.currentStub()
        let body = stub.capturesRequestBody ? Self.readBody(from: request) : Data()
        Self.registry.record(request, body: body)
        let deliver: @Sendable () -> Void = { [weak self] in
            self?.deliver(stub)
        }
        if stub.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {
        stateLock.lock()
        stopped = true
        stateLock.unlock()
        Self.registry.recordStop()
    }

    private func deliver(_ stub: ProtocolStub) {
        stateLock.lock()
        let shouldDeliver = !stopped
        stateLock.unlock()
        guard shouldDeliver else { return }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response: URLResponse
        if stub.returnsHTTPResponse {
            response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
        } else {
            response = URLResponse(
                url: request.url!,
                mimeType: nil,
                expectedContentLength: stub.body.count,
                textEncodingName: nil
            )
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.body.isEmpty { client?.urlProtocol(self, didLoad: stub.body) }
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            result.append(buffer, count: count)
        }
        return result
    }
}

@Suite(.serialized)
struct URLSessionFileTransferClientTests {
    @Test func uploadsFileWithAuthorizationTimeoutAndBoundedResponse() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.bin")
        let sourceData = Data("upload-body".utf8)
        try sourceData.write(to: source)
        TransferURLProtocol.registry.configure(
            ProtocolStub(statusCode: 201, headers: ["X-Request-ID": "request-1"], body: Data(repeating: 7, count: 70_000))
        )

        let task = client().upload(
            FileUploadRequest(
                url: URL(string: "https://example.com/upload")!,
                method: .post,
                headers: ["X-Test": "value"],
                authorization: .bearer("private-token"),
                body: .file(url: source, contentType: "application/octet-stream"),
                timeout: 9
            )
        )
        let result = try await completedResult(from: task)
        let recorded = try #require(TransferURLProtocol.registry.firstRequest())

        #expect(result.response.statusCode == 201)
        #expect(result.response.data.count == 65_536)
        #expect(result.response.requestID == "request-1")
        #expect(result.fileURL == nil)
        #expect(recorded.request.httpMethod == "POST")
        #expect(recorded.request.value(forHTTPHeaderField: "Authorization") == "Bearer private-token")
        #expect(recorded.request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(recorded.request.value(forHTTPHeaderField: "X-Test") == "value")
        #expect(recorded.request.timeoutInterval == 9)
        #expect(recorded.body == sourceData)
    }

    @Test func uploadsLargeRegularFileWithoutCreatingAnInMemoryRequestBody() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("large.bin")
        FileManager.default.createFile(atPath: source.path, contents: nil)
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: 32 * 1024 * 1024)
        try handle.close()
        TransferURLProtocol.registry.configure(
            ProtocolStub(statusCode: 204, capturesRequestBody: false)
        )

        let result = try await completedResult(
            from: client().upload(
                FileUploadRequest(
                    url: URL(string: "https://example.com/large")!,
                    method: .post,
                    body: .file(url: source, contentType: "application/octet-stream")
                )
            )
        )
        let recorded = try #require(TransferURLProtocol.registry.firstRequest())
        #expect(result.response.statusCode == 204)
        #expect(recorded.request.httpBody == nil)
        #expect(recorded.body.isEmpty)
    }

    @Test func uploadsMultipartAndRemovesTemporaryBody() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("asset.bin")
        try Data("asset-body".utf8).write(to: source)
        TransferURLProtocol.registry.configure(ProtocolStub(statusCode: 204))
        let task = client().upload(
            FileUploadRequest(
                url: URL(string: "https://example.com/form")!,
                method: .put,
                body: .multipart(
                    MultipartFormData(
                        parts: [
                            .text(name: "title", value: "hello"),
                            .file(
                                name: "asset",
                                url: source,
                                filename: "asset.bin",
                                contentType: "application/octet-stream"
                            ),
                        ],
                        boundary: "fixed-boundary"
                    )
                )
            )
        )

        _ = try await completedResult(from: task)
        let recorded = try #require(TransferURLProtocol.registry.firstRequest())
        let body = String(decoding: recorded.body, as: UTF8.self)
        #expect(recorded.request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=fixed-boundary")
        #expect(body.contains("name=\"title\"\r\n\r\nhello"))
        #expect(body.contains("asset-body"))
    }

    @Test func multipartTemporaryFileIsRemovedAfterSuccessAndFailure() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.bin")
        try Data("body".utf8).write(to: source)

        for statusCode in [204, 500] {
            TransferURLProtocol.registry.configure(ProtocolStub(statusCode: statusCode))
            let prepared = try MultipartFileWriter.prepare(
                .multipart(
                    MultipartFormData(
                        parts: [
                            .file(
                                name: "file",
                                url: source,
                                filename: "source.bin",
                                contentType: "application/octet-stream"
                            )
                        ]
                    )
                )
            )
            let transfer = URLSessionTransferTask(kind: .upload(.successful))
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [TransferURLProtocol.self]
            transfer.startUpload(
                FileUploadRequest(
                    url: URL(string: "https://example.com/cleanup")!,
                    method: .post,
                    body: .file(url: source, contentType: "application/octet-stream")
                ),
                prepared: prepared,
                configuration: configuration
            )

            if statusCode == 204 {
                _ = try await completedResult(from: transfer)
            } else {
                await #expect(throws: HTTPTransportError.self) {
                    _ = try await completedResult(from: transfer)
                }
            }
            #expect(FileManager.default.fileExists(atPath: prepared.fileURL.path) == false)
        }
    }

    @Test func rejectedUploadCarriesOnlyBoundedResponseData() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.bin")
        try Data("body".utf8).write(to: source)
        TransferURLProtocol.registry.configure(
            ProtocolStub(statusCode: 413, body: Data(repeating: 9, count: 90_000))
        )

        do {
            _ = try await completedResult(
                from: client().upload(
                    FileUploadRequest(
                        url: URL(string: "https://example.com/rejected")!,
                        method: .post,
                        body: .file(url: source, contentType: "application/octet-stream")
                    )
                )
            )
            Issue.record("Expected rejected status")
        } catch HTTPTransportError.unsuccessful(let response) {
            #expect(response.statusCode == 413)
            #expect(response.data.count == 65_536)
        }
    }

    @Test func emitsMonotonicProgressAndUnknownTotal() async throws {
        let task = URLSessionTransferTask(kind: .upload(.successful))
        var iterator = task.events().makeAsyncIterator()
        task.recordProgress(completed: 5, total: 10)
        guard case .progress(let first) = try await iterator.next() else {
            Issue.record("Expected first progress")
            return
        }
        task.recordProgress(completed: 4, total: 10)
        task.recordProgress(completed: 6, total: -1)
        guard case .progress(let second) = try await iterator.next() else {
            Issue.record("Expected second progress")
            return
        }
        #expect(first == HTTPTransferProgress(completedByteCount: 5, totalByteCount: 10))
        #expect(second == HTTPTransferProgress(completedByteCount: 6, totalByteCount: nil))
        task.cancel()
        await #expect(throws: HTTPTransportError.self) { try await iterator.next() }
    }

    @Test func explicitCancellationFinishesByThrowingWithoutCompletion() async {
        TransferURLProtocol.registry.configure(ProtocolStub(body: Data("late".utf8), delay: 1))
        let directory = try! temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("download.bin")
        let task = client().download(
            FileDownloadRequest(
                url: URL(string: "https://example.com/slow")!,
                destinationURL: destination
            )
        )
        task.cancel()
        do {
            for try await event in task.events() {
                if case .completed = event { Issue.record("Cancellation emitted completion") }
            }
            Issue.record("Expected cancellation error")
        } catch HTTPTransportError.cancelled {
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func cancellationIsIdempotentAndRemovesMultipartTemporaryFile() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.bin")
        try Data("body".utf8).write(to: source)
        TransferURLProtocol.registry.configure(ProtocolStub(body: Data("late".utf8), delay: 1))
        let concrete = URLSessionTransferTask(kind: .upload(.successful))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransferURLProtocol.self]
        let prepared = try MultipartFileWriter.prepare(
            .multipart(
                MultipartFormData(
                    parts: [
                        .file(
                            name: "file",
                            url: source,
                            filename: "source.bin",
                            contentType: "application/octet-stream"
                        )
                    ],
                    boundary: "cancel-boundary"
                )
            )
        )
        concrete.startUpload(
            FileUploadRequest(
                url: URL(string: "https://example.com/cancel")!,
                method: .post,
                body: .multipart(MultipartFormData(parts: []))
            ),
            prepared: prepared,
            configuration: configuration
        )
        try await waitUntil { TransferURLProtocol.registry.requestCount() == 1 }
        let temporaryURL = try #require(concrete.temporaryUploadURLSnapshot)
        #expect(FileManager.default.fileExists(atPath: temporaryURL.path))

        concrete.cancel()
        concrete.cancel()
        await #expect(throws: HTTPTransportError.self) {
            for try await _ in concrete.events() {}
        }
        try await waitUntil { !FileManager.default.fileExists(atPath: temporaryURL.path) }
        try await waitUntil { TransferURLProtocol.registry.stopCount() == 1 }
        #expect(TransferURLProtocol.registry.stopCount() == 1)
    }

    @Test func cancellingStreamConsumerCancelsUnderlyingTransfer() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        TransferURLProtocol.registry.configure(ProtocolStub(body: Data("late".utf8), delay: 1))
        let transfer = client().download(
            FileDownloadRequest(
                url: URL(string: "https://example.com/structured-cancel")!,
                destinationURL: directory.appendingPathComponent("download.bin")
            )
        )
        let consumer = Task { try await completedResult(from: transfer) }
        try await waitUntil { TransferURLProtocol.registry.requestCount() == 1 }
        consumer.cancel()
        do {
            _ = try await consumer.value
            Issue.record("Expected stream-consumer cancellation to throw")
        } catch HTTPTransportError.cancelled {
        } catch {
            Issue.record("Unexpected stream-consumer cancellation error: \(error)")
        }
        try await waitUntil { TransferURLProtocol.registry.stopCount() == 1 }
        #expect(TransferURLProtocol.registry.stopCount() == 1)
    }

    @Test func acceptedDownloadAtomicallyReplacesDestination() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("download.bin")
        try Data("old".utf8).write(to: destination)
        TransferURLProtocol.registry.configure(
            ProtocolStub(statusCode: 200, headers: ["X-Request-ID": "download-1"], body: Data("complete-new-file".utf8))
        )

        let result = try await completedResult(
            from: client().download(
                FileDownloadRequest(
                    url: URL(string: "https://example.com/download")!,
                    destinationURL: destination
                )
            )
        )
        #expect(result.fileURL == destination)
        #expect(result.response.data.isEmpty)
        #expect(result.response.requestID == "download-1")
        #expect(try Data(contentsOf: destination) == Data("complete-new-file".utf8))
    }

    @Test func rejectedDownloadPreservesDestinationAndBoundsBody() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("download.bin")
        let old = Data("old-complete-file".utf8)
        try old.write(to: destination)
        TransferURLProtocol.registry.configure(
            ProtocolStub(statusCode: 503, headers: ["Retry-After": "10"], body: Data(repeating: 3, count: 80_000))
        )

        do {
            _ = try await completedResult(
                from: client().download(
                    FileDownloadRequest(
                        url: URL(string: "https://example.com/rejected-download")!,
                        destinationURL: destination
                    )
                )
            )
            Issue.record("Expected rejected status")
        } catch HTTPTransportError.unsuccessful(let response) {
            #expect(response.statusCode == 503)
            #expect(response.data.count == 65_536)
            #expect(response.retryAfter == 10)
            #expect(try Data(contentsOf: destination) == old)
        }
    }

    @Test func classifiesOfflineTimeoutAndInvalidHTTPResponse() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("download.bin")
        for (stub, expected) in [
            (ProtocolStub(error: URLError(.notConnectedToInternet)), "offline"),
            (ProtocolStub(error: URLError(.timedOut)), "timedOut"),
            (ProtocolStub(body: Data(), returnsHTTPResponse: false), "invalidResponse"),
        ] {
            TransferURLProtocol.registry.configure(stub)
            do {
                _ = try await completedResult(
                    from: client().download(
                        FileDownloadRequest(
                            url: URL(string: "https://example.com/failure")!,
                            destinationURL: destination
                        )
                    )
                )
                Issue.record("Expected \(expected)")
            } catch HTTPTransportError.offline where expected == "offline" {
            } catch HTTPTransportError.timedOut where expected == "timedOut" {
            } catch HTTPTransportError.invalidResponse where expected == "invalidResponse" {
            } catch {
                Issue.record("Unexpected error for \(expected): \(error)")
            }
        }
    }

    @Test func invalidSourceAndDestinationDiagnosticsRevealNoPathsOrSecrets() async throws {
        let missing = URL(fileURLWithPath: "/private/missing-secret-file.bin")
        let invalidDestination = URL(fileURLWithPath: "/private/missing-secret-dir/output.bin")
        let upload = client().upload(
            FileUploadRequest(
                url: URL(string: "https://example.com/upload")!,
                method: .post,
                authorization: .bearer("secret-token"),
                body: .file(url: missing, contentType: "application/octet-stream")
            )
        )
        let download = client().download(
            FileDownloadRequest(
                url: URL(string: "https://example.com/download")!,
                authorization: .bearer("secret-token"),
                destinationURL: invalidDestination
            )
        )

        for task in [upload, download] {
            do {
                _ = try await completedResult(from: task)
                Issue.record("Expected validation failure")
            } catch {
                let description = String(describing: error)
                #expect(!description.contains("secret-token"))
                #expect(!description.contains("missing-secret"))
            }
        }

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            _ = try await completedResult(
                from: client().download(
                    FileDownloadRequest(
                        url: URL(string: "https://example.com/download")!,
                        destinationURL: directory
                    )
                )
            )
            Issue.record("Expected a directory destination to be rejected")
        } catch HTTPFileTransferError.invalidDestination {
        } catch {
            Issue.record("Unexpected directory-destination error: \(error)")
        }
    }

    private func client() -> URLSessionFileTransferClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransferURLProtocol.self]
        return URLSessionFileTransferClient(configuration: configuration)
    }

    private func completedResult(from task: any HTTPTransferTask) async throws -> HTTPTransferResult {
        var completed: HTTPTransferResult?
        for try await event in task.events() {
            if case .completed(let result) = event {
                #expect(completed == nil)
                completed = result
            }
        }
        return try #require(completed)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPFileTransferClientTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @Sendable () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for asynchronous condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
