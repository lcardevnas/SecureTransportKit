import Foundation

/// An ordered multipart form that is rendered to a temporary file before upload.
public struct MultipartFormData: Sendable {
    /// A supported multipart form part.
    public enum Part: Sendable {
        /// UTF-8 text associated with a field name.
        case text(name: String, value: String)
        /// Small in-memory bytes with explicit file metadata.
        case data(name: String, data: Data, filename: String, contentType: String)
        /// A readable regular file copied incrementally from its URL.
        case file(name: String, url: URL, filename: String, contentType: String)
    }

    /// The boundary written between parts.
    public let boundary: String

    /// Parts in wire order.
    public let parts: [Part]

    /// Creates a multipart form.
    ///
    /// - Parameters:
    ///   - parts: Parts in wire order.
    ///   - boundary: An explicit boundary for interoperability or deterministic tests. Passing
    ///     `nil` generates a unique boundary. Unsafe line breaks fail when transfer preparation
    ///     begins.
    public init(parts: [Part], boundary: String? = nil) {
        self.parts = parts
        self.boundary = boundary ?? "SecureTransportKit-\(UUID().uuidString)"
    }
}
