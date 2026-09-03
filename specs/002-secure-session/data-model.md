# Data Model: Secure Session

## SessionCredentials

- `accessToken`: opaque non-empty credential.
- `refreshToken`: opaque non-empty credential.
- `expiresAt`: absolute expiry instant.
- `subjectID`: opaque principal identifier; accepts legacy encoded key `userID`.

## SessionRefreshResult

- `success(SessionCredentials)` installs a complete replacement.
- `failure(SessionRefreshFailure)` carries a safe classification and disposition.

## RefreshFailureDisposition

- `preserveSession`: keep current persisted and in-memory credentials.
- `invalidateSession`: delete both persisted and in-memory credentials.

## State Transitions

`absent -> adopted -> valid -> expiring -> refreshing -> valid`. Failure branches from `refreshing`
to the prior session when preserved or `absent` when invalidated. `clear` reaches `absent` from every
state. Restore reaches `valid/expiring` only when data and reinstall policy permit it.
