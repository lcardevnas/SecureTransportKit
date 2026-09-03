import Foundation
import SecureStorage
import Testing

struct KeychainValueStoreTests {
    @Test func roundTripOverwriteAndDelete() throws {
        let store = KeychainValueStore()
        let key = SecureValueKey(
            service: "secure-transport-kit.tests",
            account: UUID().uuidString
        )
        defer { try? store.delete(key) }

        try store.write(Data("first".utf8), for: key)
        #expect(try store.read(key) == Data("first".utf8))
        try store.write(Data("second".utf8), for: key)
        #expect(try store.read(key) == Data("second".utf8))
        try store.delete(key)
        #expect(try store.read(key) == nil)
        try store.delete(key)
    }

    @Test func missingValueIsNil() throws {
        let store = KeychainValueStore()
        let key = SecureValueKey(service: "secure-transport-kit.tests", account: UUID().uuidString)
        #expect(try store.read(key) == nil)
    }

    @Test func keysAreIsolatedAndDefaultAccessibilityIsDeviceOnly() throws {
        let store = KeychainValueStore()
        let service = "secure-transport-kit.tests.\(UUID())"
        let first = SecureValueKey(service: service, account: "first")
        let second = SecureValueKey(service: service, account: "second")
        defer {
            try? store.delete(first)
            try? store.delete(second)
        }

        try store.write(Data("one".utf8), for: first)
        try store.write(Data("two".utf8), for: second)
        #expect(try store.read(first) == Data("one".utf8))
        #expect(try store.read(second) == Data("two".utf8))

        if case .afterFirstUnlockThisDeviceOnly = store.accessibility {} else {
            Issue.record("Default accessibility was not device-only after first unlock")
        }
    }
}
