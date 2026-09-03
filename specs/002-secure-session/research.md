# Research: Secure Session

## Decision: Actor-own all mutable session state

**Rationale**: One isolation domain can atomically compare stale access tokens, share an in-flight
refresh, persist replacements, and publish changes.
**Alternatives considered**: Locks increase cancellation risk; caller-side serialization duplicates
security-critical behavior.

## Decision: Backend adapters classify retention

**Rationale**: Only a backend knows whether a failed refresh token may be reused. The reusable module
must execute, not infer, that policy.
**Alternatives considered**: Invalidating only selected HTTP errors would leak backend semantics.

## Decision: Installation marker defaults to discard orphaned credentials

**Rationale**: Secure storage can survive app deletion while normal preferences do not. The missing
marker provides a conservative reinstall signal.
**Alternatives considered**: Always preserve silently restores identity after reinstall; always clear
prevents consumers from choosing preservation.

## Decision: Decode the legacy principal key

**Rationale**: The extracted schema renames an application-shaped field to an opaque principal without
forcing sign-out.
**Alternatives considered**: A one-time external rewrite adds fragile migration ordering.
