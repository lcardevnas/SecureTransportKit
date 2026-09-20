# Public API Contract: HTTPFileTransfer

```swift
import Foundation
import HTTPTransport

public protocol HTTPFileTransferClient: Sendable {
    func upload(_ request: FileUploadRequest) -> any HTTPTransferTask
    func download(_ request: FileDownloadRequest) -> any HTTPTransferTask
}

public protocol HTTPTransferTask: Sendable {
    func events() -> AsyncThrowingStream<HTTPTransferEvent, any Error>
    func cancel()
}

public enum HTTPTransferEvent: Sendable {
    case progress(HTTPTransferProgress)
    case completed(HTTPTransferResult)
}

public struct HTTPTransferProgress: Sendable, Equatable {
    public let completedByteCount: Int64
    public let totalByteCount: Int64?
    public init(completedByteCount: Int64, totalByteCount: Int64?)
}

public struct HTTPTransferResult: Sendable {
    public let response: HTTPResponse
    public let fileURL: URL?
    public init(response: HTTPResponse, fileURL: URL?)
}

public struct FileUploadRequest: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let authorization: HTTPAuthorization?
    public let body: FileUploadBody
    public let acceptedStatus: AcceptedHTTPStatus
    public let timeout: TimeInterval?

    public init(
        url: URL,
        method: HTTPMethod,
        headers: [String: String] = [:],
        authorization: HTTPAuthorization? = nil,
        body: FileUploadBody,
        acceptedStatus: AcceptedHTTPStatus = .successful,
        timeout: TimeInterval? = nil
    )
}

public enum FileUploadBody: Sendable {
    case file(url: URL, contentType: String)
    case multipart(MultipartFormData)
}

public struct FileDownloadRequest: Sendable {
    public let url: URL
    public let headers: [String: String]
    public let authorization: HTTPAuthorization?
    public let destinationURL: URL
    public let acceptedStatus: AcceptedHTTPStatus
    public let timeout: TimeInterval?

    public init(
        url: URL,
        headers: [String: String] = [:],
        authorization: HTTPAuthorization? = nil,
        destinationURL: URL,
        acceptedStatus: AcceptedHTTPStatus = .successful,
        timeout: TimeInterval? = nil
    )
}

public struct MultipartFormData: Sendable {
    public enum Part: Sendable {
        case text(name: String, value: String)
        case data(name: String, data: Data, filename: String, contentType: String)
        case file(name: String, url: URL, filename: String, contentType: String)
    }

    public let boundary: String
    public let parts: [Part]
    public init(parts: [Part], boundary: String? = nil)
}

public enum HTTPFileTransferError: Error, Sendable {
    case invalidSourceFile
    case invalidMultipartMetadata
    case invalidDestination
    case temporaryFileFailure
    case destinationPublicationFailure
}

public struct URLSessionFileTransferClient: HTTPFileTransferClient, Sendable {
    public init(configuration: URLSessionConfiguration = .default)
    public func upload(_ request: FileUploadRequest) -> any HTTPTransferTask
    public func download(_ request: FileDownloadRequest) -> any HTTPTransferTask
}
```

## Event and Cancellation Contract

- A concrete task exposes one stream intended for one consumer.
- Progress is best-effort, nondecreasing, and keeps only the newest pending progress event.
- Negative or unavailable expected byte counts become `nil`.
- Success yields exactly one `.completed` event and then finishes normally.
- Failure and cancellation finish by throwing and never yield `.completed`.
- Calling `cancel()` or cancelling stream consumption requests cancellation of an active underlying URL-session task once. Cancellation after a terminal transition has no effect.
- Multipart temporary files and download staging files are removed after every terminal outcome.

## Response and Publication Contract

- Upload responses retain at most 65,536 body bytes.
- Rejected downloads expose at most 65,536 response bytes through `HTTPTransportError.unsuccessful`; accepted downloads use empty `HTTPResponse.data`.
- An upload result has `fileURL == nil`; an accepted download result has `fileURL == destinationURL`.
- A download is staged on the destination volume and status-validated before one final move or replace. Failure never changes an existing destination.

## HTTPTransport Additions

```swift
extension HTTPResponse {
    public var retryAfter: TimeInterval? { get }
    public var requestID: String? { get }
}

extension HTTPTransportError: CustomStringConvertible {
    public var description: String { get }
}
```

`retryAfter` parses nonnegative delta-seconds and IMF-fixdate, RFC 850, and ANSI C `asctime` HTTP dates. `requestID` checks common non-secret headers case-insensitively. The helpers do not retry, log, or surface values automatically. Error descriptions classify failures without printing associated response bytes or diagnostic strings.
