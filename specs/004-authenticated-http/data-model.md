# Data Model: Authenticated HTTP

## AuthenticatedHTTPRequest<Response>

- `request`: complete generic HTTP request.
- `retriesAuthenticationChallenge`: whether one replay is allowed.
- `authenticationChallengeStatuses`: statuses that trigger refresh; defaults to 401.

## Execution States

`prepared -> token acquired -> first send -> success/failure`. A configured challenge with replay
enabled transitions to `refreshing -> replaying -> success/failure`. `replaying` is terminal after one
send and can never transition back to refresh.

## Invariants

- The base request is copied before authorization changes.
- Only the authorization value differs between first send and replay.
- Plain `JSONAPIClient` execution never consults a session store.
