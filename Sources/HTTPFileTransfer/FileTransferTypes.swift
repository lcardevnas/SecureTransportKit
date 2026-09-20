import Foundation
import HTTPTransport

/// Starts memory-bounded file uploads and downloads.
///
/// The client executes only fully formed URLs. Endpoint selection, DTOs, retry policy,
/// idempotency, and authentication refresh remain the caller's responsibility.
public protocol HTTPFileTransferClient: Sendable {
    /// Starts a file-backed upload and returns its cancellation and event handle immediately.
    func upload(_ request: FileUploadRequest) -> any HTTPTransferTask

    /// Starts a download whose accepted result is published at the requested destination.
    func download(_ request: FileDownloadRequest) -> any HTTPTransferTask
}

/// Observes and cancels one file transfer.
///
/// A task's stream is intended for one consumer. Success emits exactly one
/// ``HTTPTransferEvent/completed(_:)`` event and then finishes normally. Failure and cancellation
/// finish by throwing without a completed event. Cancelling stream consumption cancels an active
/// underlying transfer; calling ``cancel()`` after termination has no effect.
public protocol HTTPTransferTask: Sendable {
    /// Returns the transfer's progress and terminal-success stream.
    func events() -> AsyncThrowingStream<HTTPTransferEvent, any Error>

    /// Cancels the transfer if it is active.
    func cancel()
}

/// An observable file-transfer event.
public enum HTTPTransferEvent: Sendable {
    /// Best-effort byte progress. Completed counts never decrease across emitted events.
    case progress(HTTPTransferProgress)
    /// The single terminal success event.
    case completed(HTTPTransferResult)
}

/// Byte progress reported by the underlying transport.
public struct HTTPTransferProgress: Sendable, Equatable {
    /// The nonnegative number of bytes transferred so far.
    public let completedByteCount: Int64

    /// The expected total byte count, or `nil` when the transport does not know it.
    public let totalByteCount: Int64?

    /// Creates a progress value.
    public init(completedByteCount: Int64, totalByteCount: Int64?) {
        self.completedByteCount = completedByteCount
        self.totalByteCount = totalByteCount
    }
}

/// Metadata produced by a successful file transfer.
public struct HTTPTransferResult: Sendable {
    /// The accepted HTTP status, headers, and bounded response data.
    ///
    /// Uploads retain at most 65,536 response bytes. Downloads return empty response data because
    /// their bytes are published to ``fileURL``.
    public let response: HTTPResponse

    /// `nil` for an upload, or the final caller-selected destination for a download.
    public let fileURL: URL?

    /// Creates a transfer result.
    public init(response: HTTPResponse, fileURL: URL?) {
        self.response = response
        self.fileURL = fileURL
    }
}

/// A fully formed file-upload request.
public struct FileUploadRequest: Sendable {
    /// The absolute destination URL.
    public let url: URL
    /// The HTTP method used for the upload.
    public let method: HTTPMethod
    /// Caller-supplied request headers.
    public let headers: [String: String]
    /// Optional explicit bearer authorization.
    public let authorization: HTTPAuthorization?
    /// The file-backed request body.
    public let body: FileUploadBody
    /// The status-code policy checked before completion.
    public let acceptedStatus: AcceptedHTTPStatus
    /// Optional timeout in seconds.
    public let timeout: TimeInterval?

    /// Creates a file-upload request.
    public init(
        url: URL,
        method: HTTPMethod,
        headers: [String: String] = [:],
        authorization: HTTPAuthorization? = nil,
        body: FileUploadBody,
        acceptedStatus: AcceptedHTTPStatus = .successful,
        timeout: TimeInterval? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.authorization = authorization
        self.body = body
        self.acceptedStatus = acceptedStatus
        self.timeout = timeout
    }
}

/// A file-backed upload body.
public enum FileUploadBody: Sendable {
    /// Uploads one readable regular file with the supplied media type.
    case file(url: URL, contentType: String)
    /// Uploads an incrementally generated temporary multipart file.
    case multipart(MultipartFormData)
}

/// A fully formed file-download request.
public struct FileDownloadRequest: Sendable {
    /// The absolute source URL.
    public let url: URL
    /// Caller-supplied request headers.
    public let headers: [String: String]
    /// Optional explicit bearer authorization.
    public let authorization: HTTPAuthorization?
    /// The final destination where accepted complete content is atomically published.
    public let destinationURL: URL
    /// The status-code policy checked before publication.
    public let acceptedStatus: AcceptedHTTPStatus
    /// Optional timeout in seconds.
    public let timeout: TimeInterval?

    /// Creates a file-download request.
    public init(
        url: URL,
        headers: [String: String] = [:],
        authorization: HTTPAuthorization? = nil,
        destinationURL: URL,
        acceptedStatus: AcceptedHTTPStatus = .successful,
        timeout: TimeInterval? = nil
    ) {
        self.url = url
        self.headers = headers
        self.authorization = authorization
        self.destinationURL = destinationURL
        self.acceptedStatus = acceptedStatus
        self.timeout = timeout
    }
}

/// Application-neutral validation and filesystem failures raised by file transfers.
///
/// Cases carry no values so descriptions cannot reveal paths, multipart names, or file names.
public enum HTTPFileTransferError: Error, Sendable, CustomStringConvertible {
    /// A source is missing, unreadable, or not a regular file.
    case invalidSourceFile
    /// Multipart boundary or header metadata is unsafe.
    case invalidMultipartMetadata
    /// The destination parent is missing, not a directory, or not writable.
    case invalidDestination
    /// Task-owned temporary data could not be created or written.
    case temporaryFileFailure
    /// Complete accepted download data could not be published at the destination.
    case destinationPublicationFailure

    /// A stable, value-free diagnostic classification.
    public var description: String {
        switch self {
        case .invalidSourceFile: "The source file is not a readable regular file."
        case .invalidMultipartMetadata: "Multipart metadata is invalid."
        case .invalidDestination: "The download destination is invalid."
        case .temporaryFileFailure: "Temporary transfer data could not be prepared."
        case .destinationPublicationFailure: "The downloaded file could not be published."
        }
    }
}
