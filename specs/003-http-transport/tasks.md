# Tasks: HTTP Transport

**Input**: Design documents from `specs/003-http-transport/`
**Tests**: Public construction, status, coding, and failure contracts require test-first coverage.

## Phase 1: Setup

- [x] T001 Declare the independent HTTPTransport product and tests in Package.swift

## Phase 2: Foundational

- [x] T002 [P] Define request, response, method, and error values in Sources/HTTPTransport/HTTPTypes.swift
- [x] T003 [P] Define the raw client boundary in Sources/HTTPTransport/HTTPClient.swift
- [x] T004 [P] Add captured transport fakes in Tests/HTTPTransportTests/JSONAPIClientTests.swift

## Phase 3: User Story 1 - Execute an Endpoint-Free Request (Priority: P1)

**Independent Test**: Capture methods, query, headers, body, timeout, status, and response data.

- [x] T005 [US1] Implement URL and request construction in Sources/HTTPTransport/JSONAPIClient.swift
- [x] T006 [US1] Verify all methods body timeout 204 and raw headers in Tests/HTTPTransportTests/JSONAPIClientTests.swift

## Phase 4: User Story 2 - Preserve Dynamic Path Values (Priority: P2)

**Independent Test**: Decode the built URL and verify each opaque value remains one segment.

- [x] T007 [US2] Implement independent segment escaping in Sources/HTTPTransport/JSONAPIClient.swift
- [x] T008 [US2] Verify slash and opaque-token escaping in Tests/HTTPTransportTests/JSONAPIClientTests.swift

## Phase 5: User Story 3 - Classify Outcomes (Priority: P3)

**Independent Test**: Exercise accepted/rejected statuses and each transport error category.

- [x] T009 [US3] Implement status and URL error classification in Sources/HTTPTransport/HTTPClient.swift
- [x] T010 [US3] Implement JSON coding classification in Sources/HTTPTransport/JSONAPIClient.swift
- [x] T011 [US3] Verify offline timeout cancellation invalid response and decoding in Tests/HTTPTransportTests/JSONAPIClientTests.swift

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T012 [P] Document the contract in specs/003-http-transport/contracts/public-api.md
- [x] T013 Run the HTTPTransport scenario in specs/003-http-transport/quickstart.md

## Dependencies & Execution Order

T001 blocks T002-T004. US1 is the MVP; US2 and US3 extend independently testable behavior.

## Parallel Opportunities

Public values, raw execution, and tests use separate files during foundation work.

## Implementation Strategy

Deliver raw endpoint-free execution, then harden path safety and stable outcome classification.
