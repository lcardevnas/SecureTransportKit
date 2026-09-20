# Tasks: HTTP File Transfer

**Input**: Design documents from `specs/005-http-file-transfer/`
**Tests**: Public-contract, concurrency, cleanup, filesystem, and metadata tests are mandatory and precede implementation.

## Phase 1: Setup

- [x] T001 Add the `HTTPFileTransfer` product, target, and test target with one-way `HTTPTransport` dependency in Package.swift
- [x] T002 Create public type and multipart source files in Sources/HTTPFileTransfer/FileTransferTypes.swift and Sources/HTTPFileTransfer/MultipartFormData.swift

## Phase 2: Foundational Contracts

- [x] T003 [P] Add compile-time construction and Sendable contract tests in Tests/HTTPFileTransferTests/FileTransferContractTests.swift
- [x] T004 [P] Add retry, request-ID, and redacted-diagnostic tests in Tests/HTTPTransportTests/HTTPResponseMetadataTests.swift
- [x] T005 Define the public request, event, result, task, client, and generic error contracts with DocC in Sources/HTTPFileTransfer/FileTransferTypes.swift
- [x] T006 Define multipart part values, generated or explicit boundaries, and DocC in Sources/HTTPFileTransfer/MultipartFormData.swift
- [x] T007 Implement response metadata helpers and redacted error descriptions in Sources/HTTPTransport/HTTPTypes.swift

## Phase 3: User Story 1 - File-Backed Uploads (Priority: P1)

**Goal**: Upload regular files and multipart forms without a whole-file in-memory request body.

**Independent Test**: Deterministic uploads reproduce raw and multipart fixture bytes, reject invalid files/metadata before network execution, and remove generated temporary data.

- [x] T008 [US1] Add raw-file, multipart ordering/boundary, 32 MiB streaming, validation, and cleanup tests in Tests/HTTPFileTransferTests/MultipartFormDataTests.swift
- [x] T009 [US1] Implement readable regular-file and injection-safe metadata validation in Sources/HTTPFileTransfer/MultipartFileWriter.swift
- [x] T010 [US1] Implement incremental multipart temporary-file construction and cleanup ownership in Sources/HTTPFileTransfer/MultipartFileWriter.swift
- [x] T011 [US1] Add deterministic URLProtocol upload request and bounded-response tests in Tests/HTTPFileTransferTests/URLSessionFileTransferClientTests.swift
- [x] T012 [US1] Implement upload request construction, explicit bearer authorization, timeout, file-backed upload tasks, bounded response capture, and accepted-status validation in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift

## Phase 4: User Story 2 - Progress and Cancellation (Priority: P2)

**Goal**: Emit monotonic progress and terminate exactly once under explicit, structured, or raced cancellation.

**Independent Test**: Synthetic delegate callbacks prove known/unknown totals, regression suppression, one terminal outcome, one underlying cancellation, and cleanup.

- [x] T013 [US2] Add monotonic progress, unknown-total, explicit cancellation, stream cancellation, and cancellation-race tests in Tests/HTTPFileTransferTests/URLSessionFileTransferClientTests.swift
- [x] T014 [US2] Implement constant-size event buffering, monotonic progress normalization, exactly-once terminal transitions, and stream termination cancellation in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift
- [x] T015 [US2] Implement idempotent underlying-task cancellation, session invalidation, and owned-file cleanup in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift

## Phase 5: User Story 3 - Atomic Downloads (Priority: P3)

**Goal**: Publish only complete accepted downloads while preserving existing destinations on every failure.

**Independent Test**: Accepted, rejected, interrupted, replacement, and invalid-destination cases leave only complete old or new destination content.

- [x] T016 [US3] Add accepted, rejected, interrupted, replacement, bounded-error-body, and invalid-destination tests in Tests/HTTPFileTransferTests/URLSessionFileTransferClientTests.swift
- [x] T017 [US3] Implement download request execution, response/status validation, and bounded rejected-body capture in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift
- [x] T018 [US3] Implement same-volume staging and one-operation destination move/replacement in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift

## Phase 6: User Story 4 - Safe Transfer Metadata (Priority: P4)

**Goal**: Expose useful generic metadata within memory and secrecy bounds without adding retry policy.

**Independent Test**: Transfer errors and responses stay bounded and secret-safe while metadata helpers parse every documented form.

- [x] T019 [US4] Add transfer-specific timeout, offline, invalid-response, cancellation, body-bound, and secret-diagnostic tests in Tests/HTTPFileTransferTests/URLSessionFileTransferClientTests.swift
- [x] T020 [US4] Complete common network-error classification and secret-safe failure mapping in Sources/HTTPFileTransfer/URLSessionFileTransferClient.swift

## Phase 7: Documentation and Validation

- [x] T021 [P] Add the product boundary and concise usage example to README.md
- [x] T022 [P] Record the additive product and helpers under the next minor release in CHANGELOG.md
- [x] T023 Verify every public declaration has accurate English DocC across Sources/HTTPFileTransfer and Sources/HTTPTransport/HTTPTypes.swift
- [x] T024 Run `swift test` and record successful scenario coverage in specs/005-http-file-transfer/quickstart.md
- [x] T025 Run the neutrality scan across Sources, README.md, and specs/005-http-file-transfer/contracts/public-api.md
- [x] T026 Run Spec Kit analysis and convergence against specs/005-http-file-transfer/spec.md, plan.md, and tasks.md

## Dependencies & Execution Order

- T001-T002 establish the product layout.
- T003-T007 establish test-first public contracts and block all user-story implementation.
- US1 is the MVP and provides upload preparation used by US2 cleanup tests.
- US2 lifecycle behavior is shared by downloads and blocks US3.
- US4 validates cross-cutting classification after upload and download execution exist.
- Documentation tasks can run after public contracts stabilize; validation follows all implementation.

## Parallel Opportunities

- T003 and T004 affect separate test targets.
- T021 and T022 affect separate documentation files.
- Within each user story, tests are written and observed failing before the corresponding implementation tasks.

## Implementation Strategy

Deliver the public contract and metadata helpers first, then a complete file-backed upload slice. Add shared lifecycle semantics before atomic downloads, finish cross-cutting failure classification, and close with documentation, full tests, neutrality scanning, analysis, and convergence.
