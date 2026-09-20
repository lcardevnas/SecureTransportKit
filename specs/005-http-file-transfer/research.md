# Research: HTTP File Transfer

## File-backed upload execution

- **Decision**: Use `URLSessionUploadTask` created from a file URL for both raw files and generated multipart files.
- **Rationale**: It keeps large request bytes out of `HTTPRequest.body` and avoids assembling a complete multipart payload in memory.
- **Alternatives considered**: `data(for:)` and `uploadTask(from:)` were rejected because they require an in-memory aggregate; custom input streams add complexity without improving the file-backed contract.

## Delegate and concurrency isolation

- **Decision**: Give each public transfer handle a dedicated private delegate bridge and URL session. Protect all lifecycle state with `NSLock`, make terminal transition and cleanup idempotent, and invalidate the session at termination.
- **Rationale**: URL-loading callbacks are delegate-based and can race with cancellation. A per-transfer bridge avoids task-routing tables and makes exactly-once terminal behavior locally enforceable.
- **Alternatives considered**: One shared session/actor routing every callback was rejected as broader shared mutable state; blocking delegate callbacks on an actor was rejected as unnecessary and harder to reason about.

## Event buffering and task cancellation

- **Decision**: Create the event stream when the transfer handle is created, retain only the newest pending progress event, and use stream termination to request cancellation. A terminal completion is yielded once and followed immediately by stream finish; failures finish by throwing.
- **Rationale**: Constant-size progress buffering prevents a slow observer from growing memory usage. Stream termination links structured-concurrency cancellation to the underlying operation.
- **Alternatives considered**: Unbounded buffering was rejected; separate callback closures were rejected because they weaken `Sendable` and cancellation semantics.

## Multipart representation

- **Decision**: Represent multipart content as ordered enum parts: text, small data, or file. Generate a random boundary unless supplied for deterministic tests. Reject CR/LF in boundary and header metadata, validate every file, and write incrementally to a unique temporary file.
- **Rationale**: A closed value model is sendable, testable, application-neutral, and prevents header injection without closures or `Any`.
- **Alternatives considered**: Builder closures and provider-specific field types were rejected; concatenating `Data` was rejected for memory safety.

## Bounded response capture

- **Decision**: Retain at most 65,536 bytes from upload response callbacks and from rejected download temporary files. Accepted downloads return response metadata with empty `data`.
- **Rationale**: Status and headers remain useful while a server cannot force a multi-megabyte error body into memory.
- **Alternatives considered**: Omitting every response body is safer but less useful for generic error decoding; an unbounded body violates the work order.

## Atomic download publication

- **Decision**: Validate status first, copy the completed URL-session temporary file into an item-replacement directory on the destination volume, then use one move or replace operation for the final destination.
- **Rationale**: Staging handles a URL-session temporary file on another volume while ensuring the caller-visible path changes only after the complete file is ready.
- **Alternatives considered**: Moving directly from the session temporary URL can fail across volumes; streaming directly into the final destination can expose partial data.

## HTTP metadata helpers

- **Decision**: Parse nonnegative delta-seconds and the three HTTP-date formats accepted by HTTP specifications. Search `X-Request-ID`, `Request-ID`, `X-Correlation-ID`, `X-Amzn-RequestId`, and `CF-Ray` case-insensitively in that order.
- **Rationale**: The helpers remain read-only and provider-neutral; applications still decide whether and how to display or use the values.
- **Alternatives considered**: Automatic retry/backoff and provider-specific typed identifiers were rejected as unsafe endpoint policy.

## Diagnostics

- **Decision**: Add a value-free `HTTPFileTransferError` for validation/filesystem categories, classify network failures with `HTTPTransportError`, and provide a redacted `HTTPTransportError.description` that never prints response bodies or associated diagnostics verbatim.
- **Rationale**: Default enum reflection can reveal associated response bytes. Stable redacted descriptions satisfy the constitution without changing error matching.
- **Alternatives considered**: Passing localized filesystem/network descriptions through was rejected because paths, request data, or credentials can appear in those strings.
