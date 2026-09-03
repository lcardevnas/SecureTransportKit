import Foundation

/// A stable location for one secret value.
public struct SecureValueKey: Hashable, Sendable {
    /// The namespace that owns the value, such as an application or subsystem identifier.
    public var service: String

    /// The logical name of the value within ``service``.
    public var account: String

    /// The optional Keychain access group used to share the value between entitled targets.
    public var accessGroup: String?

    /// Creates a stable location for a secret value.
    ///
    /// - Parameters:
    ///   - service: The namespace that owns the value.
    ///   - account: The logical name of the value within the service.
    ///   - accessGroup: An optional Keychain access group. The consuming application must provide
    ///     the corresponding entitlement when this value is non-`nil`.
    public init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
}

/// Synchronous by design: Keychain operations are short, atomic system calls.
public protocol SecureValueStore: Sendable {
    /// Stores opaque data at a stable key, replacing any existing value.
    ///
    /// - Parameters:
    ///   - data: The bytes to store. Implementations must not inspect or log their contents.
    ///   - key: The stable location at which to store the bytes.
    /// - Throws: An implementation-specific storage error when the write cannot be completed.
    func write(_ data: Data, for key: SecureValueKey) throws

    /// Reads opaque data from a stable key.
    ///
    /// - Parameter key: The stable location to read.
    /// - Returns: The stored bytes, or `nil` when no value exists.
    /// - Throws: An implementation-specific storage error when the lookup cannot be completed.
    func read(_ key: SecureValueKey) throws -> Data?

    /// Removes the value at a stable key.
    ///
    /// Deleting a missing value is expected to succeed.
    ///
    /// - Parameter key: The stable location to clear.
    /// - Throws: An implementation-specific storage error when deletion cannot be completed.
    func delete(_ key: SecureValueKey) throws
}
