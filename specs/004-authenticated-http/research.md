# Research: Authenticated HTTP

## Decision: Use an explicit authenticated request wrapper

**Rationale**: Credential attachment becomes opt-in at the call site; the plain client has no session
dependency and therefore cannot leak credentials automatically.
**Alternatives considered**: A client that decorates every request risks sending tokens to public or
third-party URLs; a Boolean inside the base request couples transport to session behavior.

## Decision: Catch only configured unsuccessful statuses

**Rationale**: Connectivity, decoding, and unrelated server failures must not refresh credentials.
**Alternatives considered**: Refreshing on any error wastes single-use refresh tokens and hides faults.

## Decision: Replay inline exactly once

**Rationale**: A non-recursive second send makes the upper bound obvious and returns a second challenge
unchanged.
**Alternatives considered**: Recursive middleware can loop; a general retry engine exceeds scope.

## Decision: Deduplicate refresh in the session actor

**Rationale**: Refresh serialization is session state behavior shared by all consumers, not an HTTP
client concern.
**Alternatives considered**: Per-client locking fails when several clients share one credential set.
