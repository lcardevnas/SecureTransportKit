import Foundation
import HTTPTransport

/// A file-transfer client backed by dedicated Foundation URL sessions.
///
/// Each transfer owns its delegate bridge, session, temporary data, and terminal lifecycle. The
/// client performs no automatic retry or authentication replay.
public struct URLSessionFileTransferClient: HTTPFileTransferClient, Sendable {
    private let configurationBox: SessionConfigurationBox

    /// Creates a URL-session file-transfer client.
    ///
    /// - Parameter configuration: The baseline session configuration copied for each transfer.
    public init(configuration: URLSessionConfiguration = .default) {
        self.configurationBox = SessionConfigurationBox(configuration)
    }

    /// Starts a file or multipart upload.
    public func upload(_ request: FileUploadRequest) -> any HTTPTransferTask {
        let transfer = URLSessionTransferTask(kind: .upload(request.acceptedStatus))
        let configuration = configurationBox.copy()
        Task.detached {
            do {
                let prepared = try MultipartFileWriter.prepare(request.body)
                transfer.startUpload(request, prepared: prepared, configuration: configuration)
            } catch {
                transfer.fail(error)
            }
        }
        return transfer
    }

    /// Starts a download that publishes only complete, accepted content.
    public func download(_ request: FileDownloadRequest) -> any HTTPTransferTask {
        let transfer = URLSessionTransferTask(
            kind: .download(request.acceptedStatus, destination: request.destinationURL)
        )
        let configuration = configurationBox.copy()
        Task.detached {
            do {
                try Self.validateDestination(request.destinationURL)
                transfer.startDownload(request, configuration: configuration)
            } catch {
                transfer.fail(error)
            }
        }
        return transfer
    }

    private static func validateDestination(_ destination: URL) throws {
        guard destination.isFileURL else { throw HTTPFileTransferError.invalidDestination }
        let parent = destination.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              FileManager.default.isWritableFile(atPath: parent.path) else {
            throw HTTPFileTransferError.invalidDestination
        }
        var destinationIsDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: destination.path, isDirectory: &destinationIsDirectory),
           destinationIsDirectory.boolValue {
            throw HTTPFileTransferError.invalidDestination
        }
    }
}

private final class SessionConfigurationBox: @unchecked Sendable {
    private let lock = NSLock()
    private let configuration: URLSessionConfiguration

    init(_ configuration: URLSessionConfiguration) {
        self.configuration = configuration.copy() as! URLSessionConfiguration
    }

    func copy() -> URLSessionConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return configuration.copy() as! URLSessionConfiguration
    }
}

final class URLSessionTransferTask: NSObject, HTTPTransferTask, @unchecked Sendable {
    enum Kind: Sendable {
        case upload(AcceptedHTTPStatus)
        case download(AcceptedHTTPStatus, destination: URL)
    }

    static let maximumResponseBytes = 65_536

    private let kind: Kind
    private let lock = NSLock()
    private let stream: AsyncThrowingStream<HTTPTransferEvent, any Error>
    private let continuation: AsyncThrowingStream<HTTPTransferEvent, any Error>.Continuation

    private var terminal = false
    private var cancelRequested = false
    private var session: URLSession?
    private var underlyingTask: URLSessionTask?
    private var temporaryUploadURL: URL?
    private var responseData = Data()
    private var lastCompletedByteCount: Int64 = -1
    private var stagedDownloadURL: URL?
    private var stagingDirectoryURL: URL?
    private var downloadResponse: HTTPResponse?
    private var downloadPreparationError: (any Error)?

    init(kind: Kind) {
        self.kind = kind
        let pair = AsyncThrowingStream<HTTPTransferEvent, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        self.stream = pair.stream
        self.continuation = pair.continuation
        super.init()
        pair.continuation.onTermination = { @Sendable [weak self] termination in
            if case .cancelled = termination { self?.cancel() }
        }
    }

    func events() -> AsyncThrowingStream<HTTPTransferEvent, any Error> { stream }

    func cancel() {
        let task: URLSessionTask?
        lock.lock()
        guard !terminal, !cancelRequested else {
            lock.unlock()
            return
        }
        cancelRequested = true
        task = underlyingTask
        lock.unlock()

        task?.cancel()
        finish(throwing: HTTPTransportError.cancelled)
    }

    func startUpload(
        _ request: FileUploadRequest,
        prepared: PreparedUpload,
        configuration: URLSessionConfiguration
    ) {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        apply(headers: request.headers, authorization: request.authorization, to: &urlRequest)
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue(prepared.contentType, forHTTPHeaderField: "Content-Type")
        }
        if let timeout = request.timeout { urlRequest.timeoutInterval = timeout }

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.uploadTask(with: urlRequest, fromFile: prepared.fileURL)
        attachAndResume(task: task, session: session, temporaryUploadURL: prepared.temporaryURL)
    }

    func startDownload(_ request: FileDownloadRequest, configuration: URLSessionConfiguration) {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = HTTPMethod.get.rawValue
        apply(headers: request.headers, authorization: request.authorization, to: &urlRequest)
        if let timeout = request.timeout { urlRequest.timeoutInterval = timeout }

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: urlRequest)
        attachAndResume(task: task, session: session, temporaryUploadURL: nil)
    }

    func fail(_ error: any Error) {
        finish(throwing: Self.classify(error))
    }

    func recordProgress(completed: Int64, total: Int64) {
        let progress: HTTPTransferProgress?
        lock.lock()
        if terminal || completed < 0 || completed < lastCompletedByteCount {
            progress = nil
        } else {
            lastCompletedByteCount = completed
            progress = HTTPTransferProgress(
                completedByteCount: completed,
                totalByteCount: total >= 0 ? total : nil
            )
        }
        lock.unlock()
        if let progress { continuation.yield(.progress(progress)) }
    }

    var temporaryUploadURLSnapshot: URL? {
        lock.lock()
        defer { lock.unlock() }
        return temporaryUploadURL
    }

    private func attachAndResume(
        task: URLSessionTask,
        session: URLSession,
        temporaryUploadURL: URL?
    ) {
        let shouldStart: Bool
        lock.lock()
        if terminal {
            shouldStart = false
        } else {
            self.session = session
            underlyingTask = task
            self.temporaryUploadURL = temporaryUploadURL
            shouldStart = true
        }
        lock.unlock()

        if shouldStart {
            task.resume()
        } else {
            task.cancel()
            session.invalidateAndCancel()
            temporaryUploadURL.map { try? FileManager.default.removeItem(at: $0) }
        }
    }

    private func finish(with result: HTTPTransferResult) {
        guard beginTerminalTransition() else { return }
        cleanupAndInvalidateSession()
        continuation.yield(.completed(result))
        continuation.finish()
    }

    private func finish(throwing error: any Error) {
        guard beginTerminalTransition() else { return }
        cleanupAndInvalidateSession()
        continuation.finish(throwing: error)
    }

    private func beginTerminalTransition() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !terminal else { return false }
        terminal = true
        return true
    }

    private func cleanupAndInvalidateSession() {
        let session: URLSession?
        let temporaryUploadURL: URL?
        let stagingDirectoryURL: URL?
        lock.lock()
        session = self.session
        temporaryUploadURL = self.temporaryUploadURL
        stagingDirectoryURL = self.stagingDirectoryURL
        self.session = nil
        self.underlyingTask = nil
        self.temporaryUploadURL = nil
        self.stagingDirectoryURL = nil
        self.stagedDownloadURL = nil
        lock.unlock()

        temporaryUploadURL.map { try? FileManager.default.removeItem(at: $0) }
        stagingDirectoryURL.map { try? FileManager.default.removeItem(at: $0) }
        session?.finishTasksAndInvalidate()
    }

    private func appendBoundedResponseData(_ data: Data) {
        lock.lock()
        let remaining = max(0, Self.maximumResponseBytes - responseData.count)
        if remaining > 0 { responseData.append(data.prefix(remaining)) }
        lock.unlock()
    }

    private func completeUpload(task: URLSessionTask) {
        guard let response = task.response as? HTTPURLResponse else {
            finish(throwing: HTTPTransportError.invalidResponse)
            return
        }
        let data: Data
        lock.lock()
        data = responseData
        lock.unlock()
        let resultResponse = Self.response(from: response, data: data)
        guard acceptedStatus.contains(resultResponse.statusCode) else {
            finish(throwing: HTTPTransportError.unsuccessful(resultResponse))
            return
        }
        finish(with: HTTPTransferResult(response: resultResponse, fileURL: nil))
    }

    private func completeDownload(task: URLSessionTask) {
        if let error = storedDownloadPreparationError {
            finish(throwing: Self.classify(error))
            return
        }
        guard let response = task.response as? HTTPURLResponse else {
            finish(throwing: HTTPTransportError.invalidResponse)
            return
        }
        if let rejected = storedDownloadResponse, !acceptedStatus.contains(rejected.statusCode) {
            finish(throwing: HTTPTransportError.unsuccessful(rejected))
            return
        }
        guard acceptedStatus.contains(response.statusCode) else {
            finish(throwing: HTTPTransportError.unsuccessful(Self.response(from: response, data: Data())))
            return
        }
        do {
            let destination = try publishStagedDownload()
            finish(
                with: HTTPTransferResult(
                    response: Self.response(from: response, data: Data()),
                    fileURL: destination
                )
            )
        } catch {
            finish(throwing: HTTPFileTransferError.destinationPublicationFailure)
        }
    }

    private var acceptedStatus: AcceptedHTTPStatus {
        switch kind {
        case .upload(let acceptedStatus), .download(let acceptedStatus, _): acceptedStatus
        }
    }

    private var storedDownloadPreparationError: (any Error)? {
        lock.lock()
        defer { lock.unlock() }
        return downloadPreparationError
    }

    private var storedDownloadResponse: HTTPResponse? {
        lock.lock()
        defer { lock.unlock() }
        return downloadResponse
    }

    private func stageDownload(at location: URL, response: HTTPURLResponse) {
        if !acceptedStatus.contains(response.statusCode) {
            let data = Self.readPrefix(from: location)
            lock.lock()
            downloadResponse = Self.response(from: response, data: data)
            lock.unlock()
            return
        }

        guard case .download(_, let destination) = kind else { return }
        var createdDirectory: URL?
        do {
            let parent = destination.deletingLastPathComponent()
            let directory = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: parent,
                create: true
            )
            createdDirectory = directory
            let staged = directory.appendingPathComponent(UUID().uuidString, isDirectory: false)
            try FileManager.default.copyItem(at: location, to: staged)

            lock.lock()
            if terminal {
                lock.unlock()
                try? FileManager.default.removeItem(at: directory)
            } else {
                stagingDirectoryURL = directory
                stagedDownloadURL = staged
                lock.unlock()
            }
        } catch {
            createdDirectory.map { try? FileManager.default.removeItem(at: $0) }
            lock.lock()
            downloadPreparationError = HTTPFileTransferError.temporaryFileFailure
            lock.unlock()
        }
    }

    private func publishStagedDownload() throws -> URL {
        guard case .download(_, let destination) = kind else {
            throw HTTPFileTransferError.destinationPublicationFailure
        }
        let staged: URL?
        lock.lock()
        staged = stagedDownloadURL
        lock.unlock()
        guard let staged else { throw HTTPFileTransferError.destinationPublicationFailure }

        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
        return destination
    }

    private static func readPrefix(from url: URL) -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: maximumResponseBytes)) ?? Data()
    }

    private static func response(from response: HTTPURLResponse, data: Data) -> HTTPResponse {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            result[String(describing: entry.key)] = String(describing: entry.value)
        }
        return HTTPResponse(data: data, statusCode: response.statusCode, headers: headers)
    }

    private static func classify(_ error: any Error) -> any Error {
        if let error = error as? HTTPTransportError { return error }
        if let error = error as? HTTPFileTransferError { return error }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return HTTPTransportError.cancelled
            case .timedOut: return HTTPTransportError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return HTTPTransportError.offline
            default: return HTTPTransportError.transport("The transport operation failed.")
            }
        }
        if error is CancellationError { return HTTPTransportError.cancelled }
        return HTTPTransportError.transport("The transport operation failed.")
    }

    private func apply(
        headers: [String: String],
        authorization: HTTPAuthorization?,
        to request: inout URLRequest
    ) {
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        switch authorization {
        case .bearer(let token): request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case nil: break
        }
    }
}

extension URLSessionTransferTask: URLSessionDataDelegate, URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        recordProgress(completed: totalBytesSent, total: totalBytesExpectedToSend)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        recordProgress(completed: totalBytesWritten, total: totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let response = downloadTask.response as? HTTPURLResponse else { return }
        stageDownload(at: location, response: response)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        appendBoundedResponseData(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            finish(throwing: Self.classify(error))
            return
        }
        switch kind {
        case .upload: completeUpload(task: task)
        case .download: completeDownload(task: task)
        }
    }
}
