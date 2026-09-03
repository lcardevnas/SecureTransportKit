# SecureTransportKit Agent Guide

Read `.specify/memory/constitution.md` and the affected numbered feature before changing public
behavior. The current `spec.md` is behavioral authority; `contracts/` and `plan.md` describe its public
Swift design.

- Write documentation and comments in English.
- Treat documentation as part of the public contract: every public API or behavior change MUST
  update its DocC comments and every affected README, `spec.md`, `contracts/`, and `quickstart.md`
  in the same change.
- Keep all products endpoint-free and application-neutral.
- Preserve the declared dependency graph in `Package.swift`.
- Never include credential values in errors, logs, debug output, or test messages.
- Add public-contract and concurrency tests before implementation changes.
- Update `CHANGELOG.md` for public API or behavior changes.
- Run `swift test` and the neutrality scan before declaring completion.
- Use the official Spec Kit skills under `.agents/skills`; do not invent parallel spec formats.
- Update `spec.md` first, realign derived artifacts, then run analyze and converge.
- Do not commit unless the user explicitly requests it.

The consuming application owns base URLs, endpoints, wire DTOs, domain errors, and refresh-failure
classification.
