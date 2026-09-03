import Foundation

/// Opaque credentials owned by the session engine, not by UI state.
public struct SessionCredentials: Codable, Hashable, Sendable {
    /// The short-lived token presented to authenticated services.
    public var accessToken: String

    /// The secret used by the consuming application's adapter to renew the session.
    public var refreshToken: String

    /// The instant at which ``accessToken`` stops being valid.
    public var expiresAt: Date

    /// An opaque, backend-defined identifier for the authenticated principal.
    public var subjectID: String

    /// Creates a complete set of session credentials.
    ///
    /// The values are intentionally opaque. This package never parses, logs, or assigns backend
    /// meaning to either token or the principal identifier.
    ///
    /// - Parameters:
    ///   - accessToken: The short-lived token used to authorize requests.
    ///   - refreshToken: The secret passed to ``SessionRefreshClient`` when renewal is required.
    ///   - expiresAt: The absolute expiration instant for the access token.
    ///   - subjectID: An opaque identifier for the authenticated principal.
    public init(accessToken: String, refreshToken: String, expiresAt: Date, subjectID: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.subjectID = subjectID
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt, subjectID, userID
    }

    /// Decodes credentials while preserving compatibility with the legacy `userID` field.
    ///
    /// New payloads should use `subjectID`. When it is absent, decoding falls back to `userID` so
    /// existing installations can restore credentials without signing out.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try values.decode(String.self, forKey: .accessToken)
        refreshToken = try values.decode(String.self, forKey: .refreshToken)
        expiresAt = try values.decode(Date.self, forKey: .expiresAt)
        subjectID = try values.decodeIfPresent(String.self, forKey: .subjectID)
            ?? values.decode(String.self, forKey: .userID)
    }

    /// Encodes credentials using the current `subjectID` field name.
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(accessToken, forKey: .accessToken)
        try values.encode(refreshToken, forKey: .refreshToken)
        try values.encode(expiresAt, forKey: .expiresAt)
        try values.encode(subjectID, forKey: .subjectID)
    }
}
