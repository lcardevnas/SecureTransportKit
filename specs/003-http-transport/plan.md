# Implementation Plan: HTTP Transport

**Branch**: `develop` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-http-transport/spec.md`

## Summary

Provide endpoint-free request construction, a raw client boundary, URLSession execution, injectable
JSON coding, per-segment escaping, accepted-status policies, and stable transport error categories.

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: Foundation, FoundationNetworking where available
**Storage**: None
**Testing**: Swift Testing with captured/fake HTTP clients
**Target Platform**: iOS 18+, macOS 15+
**Project Type**: Reusable library
**Performance Goals**: No additional network round trip; request construction is linear in input size
**Constraints**: No routes, domain DTOs, general retries, or third-party dependencies
**Scale/Scope**: JSON-oriented application requests and raw responses

## Constitution Check

- PASS Library-first: independent `HTTPTransport` product and tests.
- PASS Neutrality: base URL and every route component come from consumers.
- PASS Dependencies: no dependency on session or secure-storage products.
- PASS Concurrency/security: public crossings are `Sendable`; auth is not described in errors.
- PASS Test-first/compatibility: methods, escaping, statuses, coding, and failures are contractual.
- PASS Post-design re-check: injected coding preserves consumer-specific JSON rules.

## Project Structure

### Documentation (this feature)

```text
specs/003-http-transport/{spec.md,plan.md,research.md,data-model.md,quickstart.md,tasks.md}
specs/003-http-transport/contracts/public-api.md
```

### Source Code (repository root)

```text
Sources/HTTPTransport/
├── HTTPTypes.swift
├── HTTPClient.swift
└── JSONAPIClient.swift
Tests/HTTPTransportTests/JSONAPIClientTests.swift
```

**Structure Decision**: Raw execution and JSON convenience share one product while repositories
remain responsible for routes and error translation.

## Complexity Tracking

No constitution violations.
