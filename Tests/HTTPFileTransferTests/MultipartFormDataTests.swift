import Foundation
@testable import HTTPFileTransfer
import Testing

struct MultipartFormDataTests {
    @Test func rendersOrderedTextDataAndFileParts() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.bin")
        try Data("file-body".utf8).write(to: source)
        let form = MultipartFormData(
            parts: [
                .text(name: "title", value: "hello"),
                .data(
                    name: "preview",
                    data: Data("small-body".utf8),
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
            boundary: "test-boundary"
        )

        let prepared = try MultipartFileWriter.prepare(.multipart(form))
        defer { prepared.temporaryURL.map { try? FileManager.default.removeItem(at: $0) } }
        let body = try String(decoding: Data(contentsOf: prepared.fileURL), as: UTF8.self)

        #expect(prepared.contentType == "multipart/form-data; boundary=test-boundary")
        #expect(body.hasPrefix("--test-boundary\r\n"))
        #expect(body.contains("name=\"title\"\r\n\r\nhello"))
        #expect(body.contains("name=\"preview\"; filename=\"preview.bin\""))
        #expect(body.contains("small-body"))
        #expect(body.contains("name=\"asset\"; filename=\"asset.bin\""))
        #expect(body.contains("file-body"))
        #expect(body.hasSuffix("--test-boundary--\r\n"))
    }

    @Test func streamsLargeFileIntoTemporaryMultipartFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("large.bin")
        FileManager.default.createFile(atPath: source.path, contents: nil)
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: 32 * 1024 * 1024)
        try handle.close()

        let prepared = try MultipartFileWriter.prepare(
            .multipart(
                MultipartFormData(
                    parts: [
                        .file(
                            name: "file",
                            url: source,
                            filename: "large.bin",
                            contentType: "application/octet-stream"
                        )
                    ],
                    boundary: "large-boundary"
                )
            )
        )
        defer { prepared.temporaryURL.map { try? FileManager.default.removeItem(at: $0) } }

        let size = try prepared.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        #expect((size ?? 0) > 32 * 1024 * 1024)
        #expect(prepared.fileURL != source)
    }

    @Test func rejectsMissingDirectoriesAndHeaderInjection() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: HTTPFileTransferError.invalidSourceFile) {
            try MultipartFileWriter.prepare(.file(url: directory, contentType: "application/octet-stream"))
        }
        #expect(throws: HTTPFileTransferError.invalidMultipartMetadata) {
            try MultipartFileWriter.prepare(
                .multipart(
                    MultipartFormData(
                        parts: [.text(name: "unsafe\r\nheader", value: "value")],
                        boundary: "boundary"
                    )
                )
            )
        }
        #expect(throws: HTTPFileTransferError.invalidMultipartMetadata) {
            try MultipartFileWriter.prepare(
                .multipart(MultipartFormData(parts: [], boundary: "unsafe\r\nboundary"))
            )
        }
    }

    @Test func generatedBoundaryIsUniqueAndSafe() {
        let first = MultipartFormData(parts: [])
        let second = MultipartFormData(parts: [])
        #expect(first.boundary != second.boundary)
        #expect(!first.boundary.contains("\r"))
        #expect(!first.boundary.contains("\n"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPFileTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
