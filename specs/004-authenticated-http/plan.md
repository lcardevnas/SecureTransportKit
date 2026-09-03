# Implementation Plan: Authenticated HTTP

**Branch**: `develop` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-authenticated-http/spec.md`

## Summary

Compose the generic JSON transport with the secure session actor. An explicit authenticated wrapper
adds Bearer credentials and performs at most one refresh/replay for configured challenge statuses.

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: Foundation, HTTPTransport, SecureSession
**Storage**: Delegated to SecureSession
**Testing**: Swift Testing with captured transport and refresh fakes
**Target Platform**: iOS 18+, macOS 15+
**Project Type**: Reusable composition library
**Performance Goals**: Successful calls add no round trip; challenged calls add at most one refresh and replay
**Constraints**: No general retry/backoff, endpoint, DTO, or server-error interpretation
**Scale/Scope**: One session store shared by any number of repositories and concurrent requests

## Constitution Check

- PASS Library-first: composition is an independent product.
- PASS Neutrality: authentication challenges and replay safety are consumer-configurable.
- PASS Dependencies: imports only the two declared lower-level capabilities.
- PASS Concurrency/security: token state remains actor-owned and no token enters diagnostics.
- PASS Test-first/compatibility: retry counts and header behavior have contract tests.
- PASS Post-design re-check: the decorator cannot recursively replay.

## Project Structure

### Documentation (this feature)

```text
specs/004-authenticated-http/{spec.md,plan.md,research.md,data-model.md,quickstart.md,tasks.md}
specs/004-authenticated-http/contracts/public-api.md
```

### Source Code (repository root)

```text
Sources/AuthenticatedHTTP/AuthenticatedHTTPClient.swift
Tests/AuthenticatedHTTPTests/AuthenticatedHTTPClientTests.swift
```

**Structure Decision**: Authentication is a decorator target, leaving plain HTTP available for
public calls and making credential attachment an explicit type-level choice.

## Complexity Tracking

No constitution violations.
