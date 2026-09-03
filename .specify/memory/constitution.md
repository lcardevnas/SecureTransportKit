<!--
Sync Impact Report
- Version change: 1.0.0 -> 1.0.1
- Added principles: Library-First; Application-Neutral Infrastructure; Explicit Dependency Direction;
  Swift 6 Concurrency Safety; Secret-Safe Diagnostics; Test-First Contracts; Semantic
  Compatibility; Artifact Convergence
- Added sections: Platform and Dependency Constraints; Spec-Driven Development Workflow
- Removed sections: none
- Deferred items: none
-->
# AppBuildingBlocks Constitution

## Core Principles

### I. Library-First
Every capability MUST be delivered as a cohesive library product with one clearly stated
responsibility. A product MUST be independently importable, testable, and documented. Shared code
MUST NOT be grouped only for organizational convenience. Rationale: independent products remain
usable without forcing consumers to adopt unrelated infrastructure.

### II. Application-Neutral Infrastructure
Library source, tests, examples, and public documentation MUST NOT contain application brands,
production hosts, product identifiers, application DTOs, or concrete endpoint paths. Backend routes,
wire schemas, and domain-error translation MUST remain in the consuming application. Rationale:
infrastructure is reusable only when its contracts describe capabilities rather than one backend.

### III. Explicit Dependency Direction
Product dependencies MUST be declared and directed from higher-level composition toward lower-level
capabilities. SecureStorage and HTTPTransport MUST remain independent. SecureSession MAY depend on
SecureStorage. AuthenticatedHTTP MAY depend on SecureSession and HTTPTransport. A product MUST NOT
import another product accidentally or through an implementation leak. Rationale: dependency
direction makes each product's adoption cost and isolation verifiable.

### IV. Swift 6 Concurrency Safety
Public values crossing concurrency boundaries MUST be `Sendable`. Mutable shared state MUST have an
explicit isolation model, normally an actor. Refresh coordination and change observation MUST be
tested under concurrent use. Unsafe isolation escapes require a documented justification in the
feature plan. Rationale: reusable infrastructure must not transfer race conditions into consumers.

### V. Secret-Safe Diagnostics
Access tokens, refresh tokens, credentials, and stored secret bytes MUST NOT appear in logs, error
descriptions, debug descriptions, test failure messages, or telemetry. Public errors MUST classify
failures without embedding secret material. Rationale: reusable security infrastructure must be safe
under routine debugging and failure reporting.

### VI. Test-First Public Contracts (NON-NEGOTIABLE)
Changes to public behavior MUST begin with executable contract tests. Security, concurrency,
persistence migration, request construction, and retry boundaries MUST have focused tests before a
change is considered implemented. Tests MUST exercise observable behavior rather than private
implementation details. Rationale: consumers depend on contracts that refactoring cannot silently
change.

### VII. Semantic Compatibility
Public API changes MUST follow semantic versioning and be recorded in `CHANGELOG.md`. Breaking
changes require a major version decision and a migration note. Additive behavior requires a minor
version decision; compatible fixes require a patch decision. Rationale: package consumers need a
predictable upgrade path even while the package remains local.

### VIII. Artifact Convergence
The current `spec.md` defines required behavior; `plan.md` and contracts define the approved design;
tests and code prove delivery. When a contract changes, the specification MUST be updated first,
derived artifacts MUST be realigned, and Spec Kit analysis/convergence MUST report no actionable gap
before completion. Public symbols MUST have accurate English DocC comments, and all affected README
and quickstart material MUST be updated in the same change. Rationale: synchronized artifacts give
humans and AI agents the same authority.

## Platform and Dependency Constraints

- The package MUST support iOS 18 or later and macOS 15 or later using Swift 6 language mode.
- Production products MUST use only Apple platform frameworks and the Swift standard library.
- Public contracts MUST avoid SwiftData, UI frameworks, and consuming-application model types.
- Defaults MUST be secure and conservative; weaker behavior requires explicit consumer configuration.
- Each product MUST compile and test independently through Swift Package Manager.

## Spec-Driven Development Workflow

1. Update the numbered feature's `spec.md` before changing observable behavior.
2. Reconcile `research.md`, `plan.md`, `data-model.md`, `contracts/`, and `quickstart.md`.
3. Generate `tasks.md` in user-story order with tests before implementation tasks.
4. Implement tasks incrementally and mark a task complete only after its acceptance check passes.
5. Run package tests, application integration tests, neutrality scans, and Spec Kit convergence.
6. Review public API compatibility and update `CHANGELOG.md` before release or extraction.

Reviewers MUST reject undocumented contract drift, secret exposure, undeclared dependency direction,
or completion claims unsupported by tests.

## Governance

This constitution supersedes local conventions within `Packages/AppBuildingBlocks`. Amendments MUST
be proposed by updating this file, documenting the impact on existing specs and consumers, and
choosing a semantic constitution version. A principle removal or incompatible redefinition requires a
major version; a new principle or material expansion requires a minor version; clarification requires
a patch version. Every plan MUST include a Constitution Check before design and after contracts are
defined. Exceptions MUST be explicit in the plan's Complexity Tracking section and approved before
implementation.

**Version**: 1.0.1 | **Ratified**: 2026-09-03 | **Last Amended**: 2026-09-03
