# Public Contract: SecureStorage

```swift
public struct SecureValueKey: Hashable, Sendable {
    public init(service: String, account: String, accessGroup: String? = nil)
}

public protocol SecureValueStore: Sendable {
    func write(_ value: Data, for key: SecureValueKey) throws
    func read(_ key: SecureValueKey) throws -> Data?
    func delete(_ key: SecureValueKey) throws
}

public struct KeychainValueStore: SecureValueStore, Sendable {
    public init(accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly)
}
```

Missing data is returned as `nil`. Error cases report platform operation and status without payload
bytes. Adding enum cases is allowed; changing default
accessibility or key identity is breaking.
