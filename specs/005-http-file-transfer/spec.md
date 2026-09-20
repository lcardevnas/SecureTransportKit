# Feature Specification: HTTP File Transfer

**Feature Branch**: `main`

**Created**: 2026-09-17

**Status**: Ready for planning

**Input**: User description: "Add an application-neutral, memory-safe HTTP file-transfer product with uploads, multipart bodies, downloads, progress, cancellation, bounded response data, and source-compatible HTTP response helpers."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upload Files Without Loading Them Into Memory (Priority: P1)

A library consumer uploads a regular file or a multipart form containing text, small data, and file parts while keeping large file bytes out of process memory.

**Why this priority**: Large-file upload is the primary capability missing from the existing in-memory request contract.

**Independent Test**: Upload a fixture through a deterministic local transport, inspect the received bytes and headers, and verify that the source and generated multipart data are file-backed and temporary data is removed afterward.

**Acceptance Scenarios**:

1. **Given** a readable regular file, **When** a consumer starts a file upload, **Then** the file is transferred without first materializing the whole file as an in-memory body.
2. **Given** text, small data, and file multipart parts, **When** a consumer starts the upload, **Then** the receiver obtains a correctly delimited multipart body with the declared field names, filename, and content types.
3. **Given** an unreadable, missing, or non-regular source URL, **When** an upload is started, **Then** the event stream fails with a generic file-transfer error before any network request begins.

---

### User Story 2 - Observe and Cancel a Transfer (Priority: P2)

A library consumer observes monotonic byte progress for an upload or download and can stop work through either the transfer handle or cancellation of the stream-consuming task.

**Why this priority**: Progress and reliable cancellation are required for responsive applications and safe interruption recovery.

**Independent Test**: Drive a deterministic transfer through multiple progress callbacks, cancel it through each supported route, and verify one thrown cancellation outcome, one underlying cancellation, and cleanup of temporary data.

**Acceptance Scenarios**:

1. **Given** a transfer with a known total size, **When** byte callbacks arrive, **Then** the stream emits nondecreasing completed byte counts and the known total.
2. **Given** a transfer whose total size is unknown, **When** progress arrives, **Then** the stream represents the total as absent rather than inventing a value.
3. **Given** an active transfer, **When** the handle is cancelled or the consuming task stops by cancellation, **Then** the underlying operation is cancelled exactly once, the stream finishes by throwing cancellation, and owned temporary files are removed.
4. **Given** a transfer that has already completed or failed, **When** cancellation is requested, **Then** no second terminal outcome or underlying cancellation occurs.

---

### User Story 3 - Publish Complete Downloads Safely (Priority: P3)

A library consumer downloads a response to a chosen destination and sees that destination only after a fully received, accepted response can be published atomically.

**Why this priority**: A partial or rejected file at the final destination could be mistaken for a valid application asset.

**Independent Test**: Download accepted and rejected deterministic responses into a directory containing both empty and pre-existing destinations, then verify atomic publication and preservation behavior.

**Acceptance Scenarios**:

1. **Given** a complete response with an accepted status, **When** the download finishes, **Then** the completed event identifies the final destination and the full content is available there.
2. **Given** a rejected response, timeout, cancellation, offline failure, or invalid response, **When** the transfer terminates, **Then** no partial final file is published and any pre-existing destination remains unchanged.
3. **Given** an accepted response and an existing destination, **When** publication succeeds, **Then** the old destination is replaced as one final filesystem operation.

---

### User Story 4 - Interpret Transfer Metadata Safely (Priority: P4)

A library consumer receives status and header metadata without accidentally retaining an arbitrarily large response body and can interpret common retry and request-correlation headers without automatic retry policy.

**Why this priority**: Metadata supports application-owned recovery and diagnostics while preserving endpoint safety and memory bounds.

**Independent Test**: Exercise accepted and rejected responses containing large bodies, retry headers, request identifiers, and secret request values; verify bounded data, parsed metadata, and secret-safe diagnostics.

**Acceptance Scenarios**:

1. **Given** any transfer response, **When** its metadata is returned or embedded in an unsuccessful-status error, **Then** response bytes retained in memory never exceed 64 KiB.
2. **Given** a valid delta-seconds or HTTP-date retry header, **When** retry metadata is requested, **Then** the corresponding interval is returned; malformed or missing values return no interval.
3. **Given** a common request-identifier header with arbitrary casing, **When** request metadata is requested, **Then** its value is available without provider-specific interpretation.
4. **Given** authorization, body data, multipart field metadata, or file names, **When** any failure is described or diagnosed, **Then** none of those values appear in the diagnostic text.

### Edge Cases

- A source file can disappear or become unreadable between validation and transfer; the stream must fail without exposing its path or multipart name.
- Progress callbacks can repeat a byte count or report an unknown/negative expected count; repeated counts are allowed, regressions are suppressed, and negative totals become absent.
- Cancellation can race with completion; exactly one terminal outcome wins and cleanup runs once.
- An event consumer can subscribe after the operation has already produced events; it must still receive the latest buffered progress or terminal outcome.
- Multipart names, filenames, content types, and boundaries containing line breaks must be rejected to prevent header injection.
- A destination parent can be missing or unwritable; the transfer fails without altering an existing destination.
- A response can contain headers whose keys differ only by case; lookup remains case-insensitive.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The package MUST expose an independently importable file-transfer capability without changing the existing storage, session, JSON transport, or authenticated-request contracts.
- **FR-002**: Consumers MUST be able to start file uploads and downloads through sendable request values and receive a sendable task handle immediately.
- **FR-003**: A transfer task MUST expose one asynchronous event stream and an explicit cancellation operation.
- **FR-004**: A successful transfer MUST emit exactly one terminal completed event and finish the stream immediately afterward; an error or cancellation MUST finish by throwing and emit no completed event.
- **FR-005**: Cancelling the consuming task or calling the handle's cancellation operation MUST cancel an active underlying transfer at most once and MUST be harmless after termination.
- **FR-006**: Upload requests MUST support a regular file body and multipart bodies containing text, small in-memory data, and regular file parts.
- **FR-007**: Multipart data MUST be assembled into a task-owned temporary file rather than one combined in-memory value, and the temporary file MUST be removed after success, failure, or cancellation.
- **FR-008**: Every file source MUST be validated as a readable regular file before network execution begins.
- **FR-009**: Transfer progress MUST be monotonic, use byte counts, and represent an unavailable total as absent.
- **FR-010**: Accepted downloads MUST be staged and atomically published at the requested destination only after status validation; all other outcomes MUST leave an existing destination unchanged and MUST NOT publish a partial final file.
- **FR-011**: Successful upload results MUST contain response metadata and no result file URL; successful download results MUST contain response metadata and the final destination URL.
- **FR-012**: Transfer failures caused by cancellation, timeout, offline connectivity, or a non-HTTP response MUST use the same public classifications as the existing HTTP transport.
- **FR-013**: Retained upload response data and rejected download response data MUST be truncated to at most 65,536 bytes; successful download response metadata MUST carry no downloaded body bytes.
- **FR-014**: Authorization MUST remain explicit and limited to generic bearer authorization; callers remain responsible for API-key and idempotency headers.
- **FR-015**: The capability MUST NOT automatically retry any transfer or replay an authentication challenge.
- **FR-016**: Public diagnostics MUST NOT contain authorization values, request body bytes, multipart field values, multipart file names, or source/destination paths.
- **FR-017**: Existing response values MUST offer case-insensitive interpretation of delta-seconds and valid HTTP-date retry headers and common request-identifier headers.
- **FR-018**: The package MUST remain endpoint-free and contain no application, marketplace, provider, payment, or media-processing policy.
- **FR-019**: All public values crossing concurrency boundaries MUST be sendable, and shared mutable transfer state MUST have an explicit concurrency-isolation strategy.
- **FR-020**: All existing package behavior and tests MUST remain source-compatible and continue to pass unchanged.

### Key Entities

- **File Upload Request**: Destination URL, method, headers, optional bearer authorization, file-backed body description, accepted statuses, and optional timeout.
- **Multipart Form**: A boundary and ordered text, small-data, or file parts with injection-safe metadata.
- **File Download Request**: Source URL, headers, optional bearer authorization, final destination, accepted statuses, and optional timeout.
- **Transfer Task**: A cancellable handle that owns one operation, its event lifecycle, and any temporary multipart data.
- **Transfer Event**: Either monotonic progress or the single successful completion result.
- **Transfer Result**: Bounded response metadata plus an optional final file URL whose presence distinguishes a completed download from an upload.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A test transfer using a 32 MiB source completes without constructing any 32 MiB in-memory request body or multipart aggregate.
- **SC-002**: Across deterministic success, failure, timeout, offline, and cancellation scenarios, every event stream produces exactly one terminal outcome and zero events afterward.
- **SC-003**: Across repeated progress callbacks, 100% of emitted completed byte counts are nondecreasing and unknown totals are represented without a numeric sentinel.
- **SC-004**: Across accepted, rejected, interrupted, and replacement download scenarios, 100% of final destinations contain either the prior complete file or the new complete file, never partial content.
- **SC-005**: No retained transfer response body exceeds 65,536 bytes in deterministic tests.
- **SC-006**: Automated diagnostics tests find zero occurrences of supplied tokens, body markers, multipart values, filenames, or filesystem paths.
- **SC-007**: All existing and new package tests pass without real network access, and the neutrality scan reports zero application-specific identifiers.

## Assumptions

- The package continues to support iOS 18+ and macOS 15+ in Swift 6 language mode; the first consuming use case is macOS but the new product remains portable across declared package platforms.
- One event stream is consumed per transfer task. The implementation buffers only the latest progress while preserving the terminal outcome for a late subscriber.
- The 64 KiB response-data ceiling applies equally to successful uploads and rejected uploads/downloads; applications needing larger response bodies should perform a separate application-owned request.
- Atomic publication means the final destination changes in one replace-or-move operation after any cross-volume staging is complete.
- Retry, resumability across process launches, queues, endpoint construction, DTOs, authentication refresh, and provider-specific policy remain outside this feature.
