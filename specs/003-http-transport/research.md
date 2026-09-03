# Research: HTTP Transport

## Decision: Separate raw execution from URL and JSON policy

**Rationale**: `HTTPClient` is easy to fake, while `JSONAPIClient` owns base URL, request construction,
status validation, and coding.
**Alternatives considered**: Exposing only URLSession prevents deterministic consumers and tests;
putting decoding into every repository duplicates behavior.

## Decision: Build paths from individual components

**Rationale**: Treating every dynamic value as a component prevents `/` from changing route shape and
preserves opaque identifiers.
**Alternatives considered**: Appending a prebuilt string conflates route syntax with data; manual
percent encoding is error-prone.

## Decision: Accept 2xx plus explicit status exceptions

**Rationale**: Most requests share the success range while conditional requests legitimately use 304.
**Alternatives considered**: One global set is too broad; forcing repositories to catch a status error
for an expected result misclassifies control flow.

## Decision: Classify connectivity at the URLSession boundary

**Rationale**: Stable offline, cancelled, and timeout cases let repositories translate into domain
errors without importing platform error codes.
**Alternatives considered**: Passing raw errors leaks implementation and produces inconsistent mapping.
