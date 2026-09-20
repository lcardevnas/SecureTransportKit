# Quickstart: HTTP File Transfer

## Prerequisites

- macOS 15 or later with a Swift 6 toolchain.
- Repository root as the working directory.
- No external service credentials or network access.

## Validate the Package

```sh
swift test
```

Expected: existing product tests and all `HTTPFileTransfer` tests pass with no real network calls.

## Validate File Upload

Run the focused tests that upload a regular fixture and a multipart form through the deterministic test protocol.

Expected:

- the request method, bearer header, content type, and timeout match the request value;
- the raw source is file-backed;
- multipart text, small data, and file parts arrive with the expected boundary and ordering;
- the multipart temporary file is removed after completion.

## Validate Progress and Cancellation

Run the focused progress and cancellation tests.

Expected:

- emitted byte counts never decrease;
- unknown totals are `nil`;
- cancellation through the handle and stream consumer each throws `HTTPTransportError.cancelled`;
- the underlying task and cleanup execute once despite cancellation/completion races.

## Validate Atomic Download Publication

Run the accepted, rejected, interrupted, and replacement download tests.

Expected:

- only an accepted complete response appears at the final destination;
- rejected and interrupted transfers preserve any prior destination exactly;
- the completed result identifies the destination and contains no downloaded response body in memory.

## Validate Metadata and Secret Safety

Run the response metadata and diagnostics tests.

Expected:

- delta-seconds and all supported HTTP-date values parse; malformed or absent values return `nil`;
- common request-ID headers are located case-insensitively;
- response capture never exceeds 65,536 bytes;
- tokens, body markers, multipart values, filenames, and paths do not appear in error descriptions.

## Neutrality Scan

Search production source, package documentation, and feature artifacts for consuming-application brands, hosts, endpoints, DTOs, and provider policy. Generic protocol terminology in the work-order provenance is not production package content.

Expected: zero application-specific identifiers in `Sources/`, `README.md`, and public API contracts.

## Validation Record

Validated on 2026-09-17 with Swift 6 on macOS:

- 49 Swift Testing tests passed across the existing and new package products.
- The deterministic `HTTPFileTransfer` suite passed 19 tests with no real network calls.
- The neutrality scan returned zero matches for the consuming-application and provider identifiers
  prohibited by this feature.
- Spec Kit analysis found complete requirement/task coverage, and convergence found no remaining
  actionable implementation gap.
