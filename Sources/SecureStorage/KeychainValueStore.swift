import Foundation
import Security

/// Device-only Keychain protection levels supported by ``KeychainValueStore``.
public enum KeychainAccessibility: Sendable {
    /// Makes the value available only while the device is unlocked and prevents migration to a new device.
    case whenUnlockedThisDeviceOnly

    /// Makes the value available after the first unlock following a restart and prevents device migration.
    case afterFirstUnlockThisDeviceOnly

    fileprivate var value: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

/// Errors produced while accessing a value through ``KeychainValueStore``.
public enum SecureStorageError: Error, Equatable, Sendable {
    /// Security.framework returned an unexpected status code.
    case unexpectedStatus(OSStatus)

    /// Security.framework reported success but returned a value of an unexpected type.
    case unexpectedValue
}

/// Native Keychain storage with an explicit, device-only accessibility policy.
public struct KeychainValueStore: SecureValueStore, Sendable {
    /// The protection level applied whenever a value is inserted or replaced.
    public let accessibility: KeychainAccessibility

    /// Creates a native Keychain-backed value store.
    ///
    /// - Parameter accessibility: The protection level for stored values. The default remains
    ///   available to background work after the first device unlock and never migrates to another device.
    public init(accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) {
        self.accessibility = accessibility
    }

    /// Stores opaque bytes in the generic-password Keychain class.
    ///
    /// Existing bytes at the same key are replaced atomically.
    ///
    /// - Parameters:
    ///   - data: The bytes to store.
    ///   - key: The service, account, and optional access group identifying the value.
    /// - Throws: ``SecureStorageError`` when Security.framework rejects the operation.
    public func write(_ data: Data, for key: SecureValueKey) throws {
        let lookup = Self.query(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.value,
        ]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw SecureStorageError.unexpectedStatus(updateStatus)
        }

        var insertion = lookup
        attributes.forEach { insertion[$0.key] = $0.value }
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecureStorageError.unexpectedStatus(addStatus)
        }
    }

    /// Reads opaque bytes from the generic-password Keychain class.
    ///
    /// - Parameter key: The service, account, and optional access group identifying the value.
    /// - Returns: The stored bytes, or `nil` when the item does not exist.
    /// - Throws: ``SecureStorageError`` when Security.framework rejects the operation or returns
    ///   a non-data value.
    public func read(_ key: SecureValueKey) throws -> Data? {
        var query = Self.query(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SecureStorageError.unexpectedStatus(status)
        }
        guard let data = result as? Data else { throw SecureStorageError.unexpectedValue }
        return data
    }

    /// Deletes opaque bytes from the generic-password Keychain class.
    ///
    /// - Parameter key: The service, account, and optional access group identifying the value.
    /// - Throws: ``SecureStorageError`` when Security.framework rejects the operation. A missing
    ///   item is treated as a successful deletion.
    public func delete(_ key: SecureValueKey) throws {
        let status = SecItemDelete(Self.query(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.unexpectedStatus(status)
        }
    }

    private static func query(for key: SecureValueKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account,
        ]
        if let accessGroup = key.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
