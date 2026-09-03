# SecureTransportKit

Reusable, endpoint-free infrastructure for Apple-platform applications. The package targets Swift 6,
iOS 18+, and macOS 15+ and has no third-party dependencies.

## Products

| Product | Responsibility | Dependencies |
|---|---|---|
| `SecureStorage` | Store opaque bytes in Keychain | Foundation, Security |
| `SecureSession` | Persist credentials, serialize refresh, publish lifecycle changes | SecureStorage |
| `HTTPTransport` | Build and execute generic HTTP/JSON requests | Foundation |
| `AuthenticatedHTTP` | Add Bearer authentication and one challenge replay | SecureSession, HTTPTransport |

Applications retain base URLs, route components, backend DTOs, refresh adapters, and translation from
generic transport failures to domain errors. `AuthenticatedHTTP` is opt-in: use the plain
`JSONAPIClient` for requests that must never receive session credentials.

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
request construction and escaping, transport classification, Bearer isolation, and bounded replay.

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
