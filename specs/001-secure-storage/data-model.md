# Data Model: Secure Storage

## SecureValueKey

- `service`: non-empty consumer namespace.
- `account`: non-empty logical value name.
- `accessGroup`: optional entitlement-owned sharing group.

Identity is the tuple of all three fields. The key contains no secret payload.

## KeychainAccessibility

- `afterFirstUnlockThisDeviceOnly` (default)
- `whenUnlockedThisDeviceOnly`

The value maps to a platform accessibility policy at write time.

## Stored Value Lifecycle

`absent -> created -> replaced -> deleted/absent`. Repeated deletion remains `absent`. Storage failures
do not change the contract-visible state.
