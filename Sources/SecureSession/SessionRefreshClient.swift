import Foundation

/// Determines whether credentials remain usable after a failed refresh attempt.
public enum RefreshFailureDisposition: Sendable {
    /// Keeps the current credentials so the application may decide how to recover.
    case retainSession

    /// Removes the current credentials because they must no longer be reused.
    case invalidateSession
}

/// A secret-safe classification of a failed session refresh.
///
/// The failure deliberately carries no free-form message or underlying error, preventing tokens or
/// backend response details from crossing the reusable session boundary accidentally.
public struct SessionRefreshFailure: Error, Equatable, Sendable {
    /// The required effect of the failure on the stored session.
    public var disposition: RefreshFailureDisposition

    /// Creates a refresh failure with an explicit session-retention policy.
    ///
    /// - Parameter disposition: Whether the current credentials must be retained or invalidated.
    public init(disposition: RefreshFailureDisposition) {
        self.disposition = disposition
    }
}

/// The backend-neutral result of exchanging a refresh token.
public enum SessionRefreshResult: Sendable {
    /// The backend accepted the refresh token and returned replacement credentials.
    case success(SessionCredentials)

    /// The refresh failed with an explicit session-retention policy.
    case failure(SessionRefreshFailure)
}

/// Adapts an application's refresh operation to ``SecureSessionStore``.
///
/// Implementations own the endpoint, request and response DTOs, and interpretation of ambiguous
/// backend failures. They must never log the supplied refresh token.
public protocol SessionRefreshClient: Sendable {
    /// Exchanges a refresh token for replacement credentials.
    ///
    /// - Parameter refreshToken: The opaque secret stored with the current session.
    /// - Returns: Replacement credentials or a classified, secret-safe failure.
    func refresh(using refreshToken: String) async -> SessionRefreshResult
}
