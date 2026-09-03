# Feature Specification: Authenticated HTTP

**Feature Branch**: `develop`
**Created**: 2026-09-03
**Status**: Implemented
**Input**: User description: "Compose HTTP transport and secure sessions for Bearer authentication and one refresh retry."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send an Authenticated Request (Priority: P1)

As a repository author, I can explicitly mark a request as authenticated and have the current access
token applied without handling credentials in repository code.

**Why this priority**: Centralized credential attachment removes duplicated and unsafe header logic.
**Independent Test**: Send one authenticated and one plain request and inspect captured headers.

**Acceptance Scenarios**:

1. **Given** a valid session, **When** an authenticated request is sent, **Then** it carries the current Bearer token.
2. **Given** a plain transport request, **When** it is sent outside the authenticated decorator, **Then** no session credential is attached.

---

### User Story 2 - Recover from an Authentication Challenge (Priority: P2)

As a repository author, a replay-safe request challenged by the server refreshes the session and is
replayed once with the new token.

**Why this priority**: This removes duplicated refresh loops while preserving rotating-token safety.
**Independent Test**: Return one challenge followed by success and assert one refresh and two sends.

**Acceptance Scenarios**:

1. **Given** a default authentication challenge, **When** refresh succeeds, **Then** the request is rebuilt and sent once with the new token.
2. **Given** the replay is challenged again, **When** its response is returned, **Then** no second refresh or replay occurs.
3. **Given** concurrent challenged requests with the same stale token, **When** they request refresh, **Then** the shared session performs one refresh.

---

### User Story 3 - Control Replay Policy (Priority: P3)

As a repository author, I can disable replay for unsafe operations and configure which statuses count
as authentication challenges.

**Why this priority**: Some writes are not safe to repeat and some backends use a different challenge.
**Independent Test**: Disable replay, return a challenge, and verify one send and zero refreshes.

**Acceptance Scenarios**:

1. **Given** replay is disabled, **When** a challenge occurs, **Then** the original failure is returned without refresh.
2. **Given** a custom challenge set, **When** a listed status occurs, **Then** the one-refresh policy applies.

### Edge Cases

- No active session fails before a request is sent.
- A refresh failure follows its session retention disposition and does not replay the request.
- A non-challenge HTTP failure is returned unchanged.
- The decorator performs no general retry, delay, or endpoint-specific interpretation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Only explicitly authenticated requests MUST receive a session Bearer token.
- **FR-002**: The default authentication challenge status MUST be 401.
- **FR-003**: A challenged request MUST trigger at most one refresh and at most one replay.
- **FR-004**: A replay MUST use the refreshed access token and preserve every other request attribute.
- **FR-005**: A second challenge MUST be returned without another refresh.
- **FR-006**: Consumers MUST be able to disable automatic replay per request.
- **FR-007**: Consumers MUST be able to configure authentication challenge statuses per request.
- **FR-008**: The module MUST NOT implement general retries, backoff, endpoints, DTOs, or domain-error interpretation.
- **FR-009**: Concurrent challenges for the same stale access token MUST share one refresh result.

### Key Entities

- **Authenticated Request**: A transport request plus replay and challenge policies.
- **Authentication Challenge**: A configured response status eligible for one refresh attempt.
- **Replay Attempt**: A single rebuilt request using the latest access token.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every challenged request performs no more than two total network sends.
- **SC-002**: Every second challenge performs zero additional refresh calls.
- **SC-003**: One hundred concurrent challenges using one stale token cause exactly one refresh.
- **SC-004**: Plain requests receive session credentials in 0% of test executions.

## Assumptions

- Repository authors decide whether a request is safe to replay.
- The session adapter owns backend-specific refresh behavior and failure classification.
- Consumers use the plain HTTP client for public requests.
