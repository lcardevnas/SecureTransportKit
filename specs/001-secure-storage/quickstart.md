# Quickstart: Secure Storage

## Prerequisites

- iOS 18+ or macOS 15+
- Add the local package and link the `SecureStorage` product.

## Validation Scenario

```swift
import SecureStorage

let store = KeychainValueStore()
let key = SecureValueKey(service: "com.example.sample", account: "session")
try store.write(Data("secret".utf8), for: key)
let restored = try store.read(key)
try store.delete(key)
precondition(String(decoding: restored, as: UTF8.self) == "secret")
```

Run `swift test --filter SecureStorageTests`. Expect round-trip, replacement, and deletion tests to
pass. A real application must use its own stable service/account values and declare an entitlement
before setting an access group.
