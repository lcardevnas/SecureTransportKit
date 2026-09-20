import Foundation

struct PreparedUpload: Sendable {
    let fileURL: URL
    let contentType: String
    let temporaryURL: URL?
}

enum MultipartFileWriter {
    static let copyBufferSize = 64 * 1024

    static func prepare(_ body: FileUploadBody) throws -> PreparedUpload {
        switch body {
        case .file(let url, let contentType):
            guard safeHeaderValue(contentType) else {
                throw HTTPFileTransferError.invalidMultipartMetadata
            }
            try validateRegularFile(url)
            return PreparedUpload(fileURL: url, contentType: contentType, temporaryURL: nil)
        case .multipart(let form):
            return try prepare(form)
        }
    }

    static func prepare(_ form: MultipartFormData) throws -> PreparedUpload {
        guard !form.boundary.isEmpty, safeHeaderValue(form.boundary) else {
            throw HTTPFileTransferError.invalidMultipartMetadata
        }
        try validate(form.parts)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureTransportKit-\(UUID().uuidString)", isDirectory: false)
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw HTTPFileTransferError.temporaryFileFailure
        }

        do {
            let output = try FileHandle(forWritingTo: outputURL)
            defer { try? output.close() }
            for part in form.parts {
                try write(Data("--\(form.boundary)\r\n".utf8), to: output)
                switch part {
                case .text(let name, let value):
                    try write(
                        Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8),
                        to: output
                    )
                    try write(Data(value.utf8), to: output)
                case .data(let name, let data, let filename, let contentType):
                    try write(fileHeader(name: name, filename: filename, contentType: contentType), to: output)
                    try write(data, to: output)
                case .file(let name, let url, let filename, let contentType):
                    try write(fileHeader(name: name, filename: filename, contentType: contentType), to: output)
                    try copyFile(at: url, to: output)
                }
                try write(Data("\r\n".utf8), to: output)
            }
            try write(Data("--\(form.boundary)--\r\n".utf8), to: output)
            try output.synchronize()
        } catch let error as HTTPFileTransferError {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw HTTPFileTransferError.temporaryFileFailure
        }

        return PreparedUpload(
            fileURL: outputURL,
            contentType: "multipart/form-data; boundary=\(form.boundary)",
            temporaryURL: outputURL
        )
    }

    static func validateRegularFile(_ url: URL) throws {
        guard url.isFileURL,
              FileManager.default.isReadableFile(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true else {
            throw HTTPFileTransferError.invalidSourceFile
        }
    }

    private static func validate(_ parts: [MultipartFormData.Part]) throws {
        for part in parts {
            switch part {
            case .text(let name, _):
                guard safeHeaderValue(name) else { throw HTTPFileTransferError.invalidMultipartMetadata }
            case .data(let name, _, let filename, let contentType):
                guard safeHeaderValue(name), safeHeaderValue(filename), safeHeaderValue(contentType) else {
                    throw HTTPFileTransferError.invalidMultipartMetadata
                }
            case .file(let name, let url, let filename, let contentType):
                guard safeHeaderValue(name), safeHeaderValue(filename), safeHeaderValue(contentType) else {
                    throw HTTPFileTransferError.invalidMultipartMetadata
                }
                try validateRegularFile(url)
            }
        }
    }

    private static func safeHeaderValue(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { $0.value != 10 && $0.value != 13 }
    }

    private static func fileHeader(name: String, filename: String, contentType: String) -> Data {
        let value =
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n" +
            "Content-Type: \(contentType)\r\n\r\n"
        return Data(value.utf8)
    }

    private static func write(_ data: Data, to output: FileHandle) throws {
        do {
            try output.write(contentsOf: data)
        } catch {
            throw HTTPFileTransferError.temporaryFileFailure
        }
    }

    private static func copyFile(at url: URL, to output: FileHandle) throws {
        let input: FileHandle
        do {
            input = try FileHandle(forReadingFrom: url)
        } catch {
            throw HTTPFileTransferError.invalidSourceFile
        }
        defer { try? input.close() }

        do {
            while let chunk = try input.read(upToCount: copyBufferSize), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
        } catch let error as HTTPFileTransferError {
            throw error
        } catch {
            throw HTTPFileTransferError.invalidSourceFile
        }
    }
}
