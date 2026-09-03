# Tasks: Authenticated HTTP

**Input**: Design documents from `specs/004-authenticated-http/`
**Tests**: Header isolation and bounded replay contracts require test-first coverage.

## Phase 1: Setup

- [x] T001 Declare AuthenticatedHTTP dependencies and tests in Package.swift

## Phase 2: Foundational

- [x] T002 Define the authenticated wrapper contract in Sources/AuthenticatedHTTP/AuthenticatedHTTPClient.swift
- [x] T003 Add transport and refresh fakes in Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift

## Phase 3: User Story 1 - Send an Authenticated Request (Priority: P1)

**Independent Test**: Compare captured authenticated and plain request headers.

- [x] T004 [US1] Implement typed Bearer attachment in Sources/AuthenticatedHTTP/AuthenticatedHTTPClient.swift
- [x] T005 [US1] Verify plain requests never receive credentials in Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift

## Phase 4: User Story 2 - Recover from a Challenge (Priority: P2)

**Independent Test**: One challenge causes one refresh/replay and a second challenge terminates.

- [x] T006 [US2] Implement non-recursive refresh and replay in Sources/AuthenticatedHTTP/AuthenticatedHTTPClient.swift
- [x] T007 [US2] Verify new-token replay and second-challenge bounds in Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift
- [x] T008 [US2] Verify concurrent challenges share one refresh in Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift

## Phase 5: User Story 3 - Control Replay Policy (Priority: P3)

**Independent Test**: Disabled replay causes one send and no refresh; custom status triggers once.

- [x] T009 [US3] Expose replay and challenge configuration in Sources/AuthenticatedHTTP/AuthenticatedHTTPClient.swift
- [x] T010 [US3] Verify replay opt-out and custom challenge status in Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T011 [P] Document the contract in specs/004-authenticated-http/contracts/public-api.md
- [x] T012 Run the AuthenticatedHTTP scenario in specs/004-authenticated-http/quickstart.md

## Dependencies & Execution Order

T001 blocks T002-T003. US1 is the MVP; US2 depends on session refresh; US3 configures US2 behavior.

## Parallel Opportunities

Documentation and independent behavior tests can run beside source review.

## Implementation Strategy

Deliver explicit authenticated sending, then bounded refresh/replay, then per-request policy controls.
