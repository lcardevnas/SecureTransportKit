# Implementation Plan: HTTP File Transfer

**Branch**: `main` | **Date**: 2026-09-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-http-file-transfer/spec.md`

## Summary

Add an independent `HTTPFileTransfer` library product that depends only on `HTTPTransport`. It will execute file-backed uploads and downloads with a dedicated URL-loading delegate bridge, bounded response capture, monotonic progress, cancellation propagation, temporary-file ownership, and atomic destination publication. Source-compatible response metadata helpers remain in `HTTPTransport`; the consuming application retains endpoints, DTOs, retry, replay, authentication-refresh, and idempotency policy.

## Technical Context

**Language/Version**: Swift 6 language mode

**Primary Dependencies**: Foundation and the existing `HTTPTransport` product; no third-party production dependencies

**Storage**: Caller-owned source/destination files plus task-owned temporary multipart and download-staging files

**Testing**: Swift Testing with deterministic `URLProtocol` interception and focused internal state tests; no real network calls

**Target Platform**: iOS 18+ and macOS 15+

**Project Type**: Multi-product Swift package library

**Performance Goals**: Stream 32 MiB fixtures without constructing an equivalently sized request `Data`; retain at most 65,536 response bytes; keep progress buffering constant-size

**Constraints**: Sendable public API, explicit synchronization for delegate state, one terminal stream outcome, no automatic retries, no secret-bearing diagnostics, atomic final download publication

**Scale/Scope**: One task per transfer; file and multipart uploads, downloads, progress, cancellation, response metadata helpers, tests, DocC, README, and changelog

## Constitution Check

*GATE: Passed before research and re-checked after contract design.*

- **Library-First**: `HTTPFileTransfer` is independently importable, testable, and documented.
- **Application-Neutral Infrastructure**: contracts contain no endpoints, DTOs, providers, brands, or application policy.
- **Explicit Dependency Direction**: `HTTPFileTransfer -> HTTPTransport`; no reverse dependency and no changes to other product dependencies.
- **Swift 6 Concurrency Safety**: public values are `Sendable`; mutable delegate/task state is lock-isolated behind an `@unchecked Sendable` reference with a documented invariant.
- **Secret-Safe Diagnostics**: file-transfer errors are value-free categories and HTTP error descriptions redact bodies and credentials.
- **Test-First Public Contracts**: public-contract, concurrency, cleanup, and filesystem tests precede implementation tasks.
- **Semantic Compatibility**: additions are source-compatible and recorded as the next minor release in `CHANGELOG.md`.
- **Artifact Convergence**: spec, research, plan, data model, contract, quickstart, tasks, code, and documentation are updated together; analysis and convergence run before completion.

Post-design result: all gates pass. The two private unsafe compiler escapes are the delegate bridge,
whose mutable state is protected by `NSLock`, and an immutable configuration-copy box needed because
Foundation does not expose value semantics for session configuration. Tests cover cancellation and
completion races, and neither reference escapes through public API.

## Project Structure

### Documentation (this feature)

```text
specs/005-http-file-transfer/
├── spec.md
├── research.md
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── public-api.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── HTTPTransport/
│   └── HTTPTypes.swift
└── HTTPFileTransfer/
    ├── FileTransferTypes.swift
    ├── MultipartFormData.swift
    ├── MultipartFileWriter.swift
    └── URLSessionFileTransferClient.swift
Tests/
├── HTTPTransportTests/
│   └── HTTPResponseMetadataTests.swift
└── HTTPFileTransferTests/
    ├── FileTransferContractTests.swift
    ├── MultipartFormDataTests.swift
    └── URLSessionFileTransferClientTests.swift
```

**Structure Decision**: Preserve the existing product-per-target Swift package layout. Public values and multipart construction are separated from the delegate bridge so contract and file-writing behavior can be tested independently.

## Complexity Tracking

No constitution violations require justification.
