# Feature Specification: Secure Session

**Feature Branch**: `develop`
**Created**: 2026-09-03
**Status**: Implemented
**Input**: User description: "Extract persisted credentials, serialized refresh, and session observation."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restore and Use a Session (Priority: P1)

As an application integrator, I can adopt credentials, restore them after relaunch, and request a
currently valid access token.

**Why this priority**: Session continuity is the primary consumer outcome.
**Independent Test**: Adopt credentials, recreate the session owner, restore, and obtain the token.

**Acceptance Scenarios**:

1. **Given** valid credentials, **When** they are adopted and restored, **Then** every field is preserved.
2. **Given** a token outside the expiration leeway, **When** access is requested, **Then** it is returned without refresh.
3. **Given** legacy credentials with the former principal field name, **When** restored, **Then** the principal is retained.

---

### User Story 2 - Renew Expired Credentials Once (Priority: P2)

As an application integrator, concurrent requests for an expired session cause one refresh operation
and all callers receive the same outcome.

**Why this priority**: Refresh-token rotation makes duplicate refreshes unsafe.
**Independent Test**: Request tokens concurrently and assert exactly one adapter invocation.

**Acceptance Scenarios**:

1. **Given** expired credentials, **When** several callers request access concurrently, **Then** one refresh occurs.
2. **Given** another caller already installed a newer access token, **When** stale-token refresh is requested, **Then** the newer session is returned without another refresh.
3. **Given** a classified refresh failure, **When** its policy says invalidate, **Then** the session is cleared; otherwise it is retained.

---

### User Story 3 - Observe Lifecycle Changes (Priority: P3)

As an application integrator, I can observe adoption, refresh, and clearing without polling.

**Why this priority**: Application state must react consistently to authentication changes.
**Independent Test**: Subscribe, mutate the session, and verify ordered change values.

**Acceptance Scenarios**:

1. **Given** an active observer, **When** credentials are adopted and cleared, **Then** both changes are emitted in order.
2. **Given** an apparent reinstall, **When** restore uses the default policy, **Then** orphaned credentials are discarded.

### Edge Cases

- Missing or malformed persisted credentials restore as no session.
- A persistence failure must not leave an in-memory session that cannot survive relaunch.
- Cancellation by one waiter must not create a second simultaneous refresh.
- Refresh failure descriptions must not expose either token.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Credentials MUST include access token, refresh token, expiry, and opaque principal identifier.
- **FR-002**: Consumers MUST be able to restore, adopt, clear, and observe a session.
- **FR-003**: Token validity MUST account for a configurable expiration leeway.
- **FR-004**: Concurrent refresh demand MUST be serialized into exactly one adapter call.
- **FR-005**: Refresh failures MUST explicitly direct the store to preserve or invalidate the session.
- **FR-006**: The default reinstall policy MUST discard credentials not associated with the current installation marker.
- **FR-007**: A preserve policy MUST be available for consumers that intentionally retain credentials.
- **FR-008**: Legacy credentials using the prior principal field name MUST restore without sign-out.
- **FR-009**: No public error or description MUST contain credential values.

### Key Entities

- **Session Credentials**: Tokens, expiry, and an opaque principal identifier.
- **Refresh Result**: New credentials or a classified failure with a retention disposition.
- **Session State**: Absent, valid, expiring, refreshing, or failed with retained/cleared credentials.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred simultaneous expired-token requests cause exactly one refresh operation.
- **SC-002**: All lifecycle transitions are observable in their committed order.
- **SC-003**: Existing compatible credentials migrate with a 0% forced-sign-out rate in tests.
- **SC-004**: Every classified invalidating failure removes persisted and in-memory credentials.

## Assumptions

- Each backend supplies its own refresh adapter and decides how ambiguous failures are classified.
- Refresh tokens may be single-use, so general retries are prohibited.
- The consuming application chooses stable storage and installation-marker keys.
