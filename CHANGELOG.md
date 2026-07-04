# Changelog

All notable changes to this project. Versions are tied to the regulatory
timeline where relevant — when MeitY notifies new rules or amendments, the
knowledge base is re-verified and the "last verified" date in `SKILL.md`
is updated.

## Regulatory timeline this project tracks

| Date | Event |
|------|-------|
| 11 August 2023 | DPDP Act 2023 receives Presidential assent |
| 13 November 2025 | DPDP Rules 2025 notified (G.S.R. 844(E)); Rules 1, 2, 17-21 in force |
| ~13 November 2026 | Rule 4 in force — Consent Manager registration opens |
| 13 May 2027 | Rules 3, 5-16, 22-23 in force — core obligations enforceable, penalties up to ₹250 crore |

## [2.1.0] — 2026-07-04

### Added
- **Standalone CLI**: `npx dpdpa-audit` scans any repo without an AI agent —
  wraps the same 52-check scanner, adds `--fail-on <severity>` for CI gates.
- **Go, Ruby on Rails, and Spring Boot implementation patterns**
  (`references/implementation-patterns-go-rails-spring.md`).
- **Consent Manager integration pattern** (Pattern 13): provider-agnostic
  adapter, webhook handling, and reconciliation job, ready for Board-registered
  Consent Managers when Rule 4 registration opens (~November 2026).
- **Test suite**: known-vulnerable and known-compliant fixture apps with 55
  assertions over scanner and CLI behaviour (`tests/run-tests.sh`), wired into
  GitHub Actions CI.
- **Regulatory verification stamp** in `SKILL.md`: "last verified" date and
  enforcement-date table.
- `CONTRIBUTING.md` with the add-a-check workflow.

### Fixed
- Scanner check G4 (grievance mechanism) matched the substring `dpo` inside
  unrelated words such as "endpoint", silently passing the check on most
  codebases. Now uses a word boundary.

## [2.0.0] — 2026-03-08

### Added
- Audit checklist expanded to 52 checks; scanner rewritten around it.
- DPDP Rules 2025 integrated across the knowledge base: Rule 3 notice
  requirements, Rule 7 72-hour breach notification, Rule 8 retention and
  48-hour pre-erasure notice, Rule 10 verifiable parental consent, Rule 13
  SDF obligations, Rule 14 90-day grievance SLA, Rule 15 cross-border framework.
- Documentation site (`docs/`) and hero banner.

## [1.0.0] — 2026-03-07

### Added
- Initial release: DPDPA compliance agent skill with audit, implement, and
  guidance modes; 
  implementation patterns for Node.js/Express, Python/Django, PHP/Laravel,
  React, React Native/Expo, and SQL schemas; organizational guidelines;
  full Act text reference; automated codebase scanner.
