# Quickstart: Authenticated HTTP

## Prerequisites

- Link `AuthenticatedHTTP`; provide a configured `JSONAPIClient` and `SecureSessionStore`.
- Use the plain JSON client for public operations and the decorator only for protected operations.

## Validation Scenario

Wrap a generic request in `AuthenticatedHTTPRequest` and call `sendRaw`. A fake transport should
return 401 once and success next; a fake refresh adapter should return replacement credentials. Verify
the first request has the old Bearer value, the replay has the new value, and only two sends occur.

For non-replayable operations, construct the wrapper with
`retriesAuthenticationChallenge: false`. Run `swift test --filter AuthenticatedHTTPTests`; expect
Bearer attachment, one-refresh replay, second-challenge termination, opt-out, and plain-request
isolation scenarios to pass.
