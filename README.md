# SecureTransportKit

Reusable, endpoint-free infrastructure for Apple-platform applications. The package targets Swift 6,
iOS 18+, and macOS 15+ and has no third-party dependencies.

## Products

| Product | Responsibility | Dependencies |
|---|---|---|
| `SecureStorage` | Store opaque bytes in Keychain | Foundation, Security |
| `SecureSession` | Persist credentials, serialize refresh, publish lifecycle changes | SecureStorage |
| `HTTPTransport` | Build and execute generic HTTP/JSON requests | Foundation |
| `HTTPFileTransfer` | Upload and download files with progress, cancellation, bounded response data, and atomic publication | HTTPTransport |
| `AuthenticatedHTTP` | Add Bearer authentication and one challenge replay | SecureSession, HTTPTransport |

Applications retain base URLs, route components, backend DTOs, refresh adapters, and translation from
generic transport failures to domain errors. `AuthenticatedHTTP` is opt-in: use the plain
`JSONAPIClient` for requests that must never receive session credentials. `HTTPFileTransfer` never
chooses endpoints, multipart field names, retries, idempotency, or authentication replay.

## File transfers

`HTTPFileTransfer` uploads regular files directly and renders multipart forms to a task-owned
temporary file. Downloads are status-validated and staged before one final move or replacement at
the requested destination. Progress is best-effort; cancellation finishes the event stream by
throwing and removes owned temporary data.

```swift
import HTTPFileTransfer
import HTTPTransport

let client = URLSessionFileTransferClient()
let transfer = client.download(
    FileDownloadRequest(
        url: downloadURL,
        authorization: .bearer(accessToken),
        destinationURL: destinationURL
    )
)

for try await event in transfer.events() {
    switch event {
    case .progress(let progress):
        updateProgress(progress.completedByteCount, total: progress.totalByteCount)
    case .completed(let result):
        useDownloadedFile(result.fileURL)
    }
}
```

Upload response data and rejected download response data are limited to 64 KiB. `retryAfter` and
`requestID` on `HTTPResponse` expose generic metadata only; applications decide whether a transfer
is safe to retry. For unsafe operations, do not layer automatic `AuthenticatedHTTP` challenge replay
around the transfer.

## Installation

Add this directory as a local Swift package and link only the products the target uses. No endpoint or
application configuration is bundled. Start with the independent validation guides under
[`specs/`](specs/) or the complete fake-backend composition in
[`Examples/ExampleApp.swift`](Examples/ExampleApp.swift).

## Verification

```sh
swift test
```

The suite covers Keychain behavior, credential migration and lifecycle, concurrent refresh,
request construction and escaping, transport classification, file-backed multipart construction,
transfer progress and cancellation, atomic downloads, Bearer isolation, and bounded replay.

## Spec Kit workflow

The package carries the official Spec Kit project state and Codex integration. Each numbered feature
contains `spec.md`, `research.md`, `plan.md`, `data-model.md`, `contracts/`, `quickstart.md`, and
`tasks.md`. For an observable contract change:

1. Update `spec.md` first.
2. Run `$speckit-plan` and `$speckit-tasks` to realign derived artifacts.
3. Run `$speckit-implement` for executable work.
4. Run `$speckit-analyze` and `$speckit-converge` until artifacts and code agree.
5. Record public API changes in `CHANGELOG.md`.

The governing rules are in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## License

MIT. See [LICENSE](LICENSE).
