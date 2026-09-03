# Tasks: Secure Storage

**Input**: Design documents from `specs/001-secure-storage/`
**Tests**: Public storage contracts require test-first coverage.

## Phase 1: Setup

- [x] T001 Declare the SecureStorage product and test target in Package.swift

## Phase 2: Foundational

- [x] T002 [P] Define value identity and store protocol in Sources/SecureStorage/SecureValueStore.swift
- [x] T003 [P] Add storage contract tests in Tests/SecureStorageTests/KeychainValueStoreTests.swift

## Phase 3: User Story 1 - Persist a Secret (Priority: P1)

**Independent Test**: Round-trip and replace opaque bytes using a recreated store.

- [x] T004 [US1] Implement Keychain read and replacement in Sources/SecureStorage/KeychainValueStore.swift
- [x] T005 [US1] Verify round-trip and replacement in Tests/SecureStorageTests/KeychainValueStoreTests.swift

## Phase 4: User Story 2 - Remove a Secret (Priority: P2)

**Independent Test**: Delete existing and missing values without retaining data.

- [x] T006 [US2] Implement idempotent deletion in Sources/SecureStorage/KeychainValueStore.swift
- [x] T007 [US2] Verify existing and repeated deletion in Tests/SecureStorageTests/KeychainValueStoreTests.swift

## Phase 5: User Story 3 - Configure Storage Scope (Priority: P3)

**Independent Test**: Isolate keys and verify the configured accessibility attribute.

- [x] T008 [US3] Implement access-group and accessibility configuration in Sources/SecureStorage/KeychainValueStore.swift
- [x] T009 [US3] Verify key isolation and accessibility in Tests/SecureStorageTests/KeychainValueStoreTests.swift

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T010 [P] Document the contract in specs/001-secure-storage/contracts/public-api.md
- [x] T011 Run the SecureStorage scenario in specs/001-secure-storage/quickstart.md

## Dependencies & Execution Order

T001 blocks T002-T003. Each story then depends on T002-T003 and is independently testable.

## Parallel Opportunities

Protocol and initial contract-test work use different files; documentation can proceed beside tests.

## Implementation Strategy

Deliver US1 as the MVP, add deletion, then expose explicit scope and policy controls.
