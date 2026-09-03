# Quickstart: Secure Session

## Prerequisites

- Link `SecureSession`; it brings `SecureStorage` as an implementation dependency.
- Implement `SessionRefreshClient` by adapting the consuming backend's refresh operation.

## Validation Scenario

Construct `SecureSessionStore` with the adapter and a configuration containing application-owned
storage and marker keys. Adopt credentials, call `accessToken()`, recreate the store, and call
`restore()`. Advance the supplied `now` value inside the leeway and verify the adapter is invoked once.

Run `swift test --filter SecureSessionTests`. Expected outcomes:

- credentials survive store recreation;
- concurrent token requests share one refresh;
- preserve and invalidate dispositions produce different final states;
- the legacy principal field restores without sign-out.

The adapter must classify ambiguous failures according to the backend's refresh-token semantics.
