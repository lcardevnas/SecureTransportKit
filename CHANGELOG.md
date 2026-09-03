# Changelog

All notable public API changes to this package are documented here. The format follows Keep a
Changelog and versions follow Semantic Versioning.

## [0.1.0] - 2026-09-03

### Added

- `SecureStorage` opaque-value contract and configurable Keychain implementation.
- `SecureSession` actor with persistence, migration, serialized refresh, reinstall policy, and updates.
- `HTTPTransport` request/response types, URLSession client, JSON client, safe path construction, and
  classified failures.
- `AuthenticatedHTTP` opt-in Bearer decoration with configurable, single refresh/replay behavior.
- Spec Kit v1.0.0 project artifacts and Codex integration for living specifications.
