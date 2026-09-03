# Tasks: Secure Session

**Input**: Design documents from `specs/002-secure-session/`
**Tests**: Public lifecycle, migration, and concurrency contracts require test-first coverage.

## Phase 1: Setup

- [x] T001 Declare SecureSession dependency direction and tests in Package.swift

## Phase 2: Foundational

- [x] T002 [P] Define credentials and legacy decoding in Sources/SecureSession/SessionCredentials.swift
- [x] T003 [P] Define refresh results and dispositions in Sources/SecureSession/SessionRefreshClient.swift
- [x] T004 [P] Add deterministic fakes in Tests/SecureSessionTests/SecureSessionStoreTests.swift

## Phase 3: User Story 1 - Restore and Use a Session (Priority: P1)

**Independent Test**: Adopt, recreate, restore, and obtain an unexpired token.

- [x] T005 [US1] Implement persistence and token validity in Sources/SecureSession/SecureSessionStore.swift
- [x] T006 [US1] Verify restoration and legacy migration in Tests/SecureSessionTests/SecureSessionStoreTests.swift
- [x] T007 [US1] Clear malformed persisted credentials in Sources/SecureSession/SecureSessionStore.swift

## Phase 4: User Story 2 - Renew Expired Credentials Once (Priority: P2)

**Independent Test**: Concurrent callers share one refresh and apply retention disposition.

- [x] T008 [US2] Implement serialized refresh in Sources/SecureSession/SecureSessionStore.swift
- [x] T009 [US2] Verify refresh concurrency and failure policy in Tests/SecureSessionTests/SecureSessionStoreTests.swift

## Phase 5: User Story 3 - Observe Lifecycle Changes (Priority: P3)

**Independent Test**: Observe ordered adoption and clearing values and reinstall behavior.

- [x] T010 [US3] Implement session streams and reinstall policy in Sources/SecureSession/SecureSessionStore.swift
- [x] T011 [US3] Verify stream ordering and preserve policy in Tests/SecureSessionTests/SecureSessionStoreTests.swift

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T012 [P] Document the contract in specs/002-secure-session/contracts/public-api.md
- [x] T013 Run the SecureSession scenario in specs/002-secure-session/quickstart.md

## Dependencies & Execution Order

T001 blocks T002-T004. US1 establishes persistence; US2 and US3 can then be verified independently.

## Parallel Opportunities

Credential, refresh-contract, and fake definitions occupy different files.

## Implementation Strategy

Deliver restored valid sessions first, then refresh serialization, then lifecycle observation.
