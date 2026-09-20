import Foundation
@testable import HTTPFileTransfer
import HTTPTransport
import Testing

private func requireSendable<T: Sendable>(_: T.Type) {}

struct FileTransferContractTests {
    @Test func publicValuesAreSendableAndConstructible() {
        requireSendable(FileUploadRequest.self)
        requireSendable(FileUploadBody.self)
        requireSendable(FileDownloadRequest.self)
        requireSendable(MultipartFormData.self)
        requireSendable(HTTPTransferProgress.self)
        requireSendable(HTTPTransferResult.self)
        requireSendable(HTTPTransferEvent.self)
        requireSendable(HTTPFileTransferError.self)

        let source = URL(fileURLWithPath: "/temporary/source")
        let destination = URL(fileURLWithPath: "/temporary/destination")
        let form = MultipartFormData(
            parts: [
                .text(name: "caption", value: "hello"),
                .data(
                    name: "preview",
                    data: Data([0x01]),
                    filename: "preview.bin",
                    contentType: "application/octet-stream"
                ),
                .file(
                    name: "asset",
                    url: source,
                    filename: "asset.bin",
                    contentType: "application/octet-stream"
                ),
            ],
            boundary: "fixed-boundary"
        )
        let upload = FileUploadRequest(
            url: URL(string: "https://example.com/upload")!,
            method: .post,
            authorization: .bearer("opaque"),
            body: .multipart(form),
            timeout: 12
        )
        let download = FileDownloadRequest(
            url: URL(string: "https://example.com/download")!,
            destinationURL: destination
        )

        #expect(upload.method == .post)
        #expect(upload.timeout == 12)
        #expect(download.destinationURL == destination)
        #expect(form.boundary == "fixed-boundary")
        #expect(form.parts.count == 3)
    }

    @Test func transferErrorsHaveValueFreeDescriptions() {
        let marker = "private-file-name"
        for error in [
            HTTPFileTransferError.invalidSourceFile,
            .invalidMultipartMetadata,
            .invalidDestination,
            .temporaryFileFailure,
            .destinationPublicationFailure,
        ] {
            #expect(!String(describing: error).contains(marker))
        }
    }
}
