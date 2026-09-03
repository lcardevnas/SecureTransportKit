# Research: Secure Storage

## Decision: Use opaque `Data` behind a minimal protocol

**Rationale**: Encoding belongs to credential or domain owners. Opaque bytes keep storage reusable
and make fakes trivial.
**Alternatives considered**: A generic Codable store coupled persistence to one serialization policy;
a token-specific store was too narrow.

## Decision: Update before add for replacement

**Rationale**: Keychain items are uniquely identified by service/account/access group. Updating first
provides deterministic replacement without a destructive gap.
**Alternatives considered**: Delete then add can lose a valid value if insertion fails.

## Decision: Default to after-first-unlock, this-device-only

**Rationale**: Background access after first unlock works while preventing migration to another device.
**Alternatives considered**: When-unlocked can block background refresh; synchronizable storage changes
the threat and lifecycle model.
