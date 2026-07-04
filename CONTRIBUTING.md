# Contributing

Thanks for helping make DPDPA compliance accessible to every dev team. This
project is the only open-source developer tooling in a space dominated by
commercial platforms — contributions here have outsized reach.

## Ground rules

- **Technical guidance, not legal advice.** Every pattern and check must cite
  the DPDPA section or DPDP Rules 2025 rule it implements. If you can't cite
  it, it doesn't go in.
- **Tests are the contract.** The scanner is regex-based heuristics; the test
  suite (`tests/run-tests.sh`) is what keeps it honest. Changes to
  `audit-scan.sh` must keep the suite green, and new checks need fixture
  coverage.
- Run the suite locally before opening a PR: `npm test` (needs bash + node ≥ 18).

## Adding or changing a scanner check

1. Add the check to `skills/dpdpa-compliance/scripts/audit-scan.sh` following
   the existing `finding` / `pass` helper pattern. Cite the section/rule in the
   finding text.
2. Add the same check to `skills/dpdpa-compliance/references/audit-checklist.md`
   so agent-driven audits and script-driven audits stay in sync.
3. Make the **vulnerable fixture** (`tests/fixtures/vulnerable-app/`) trigger
   the finding, and the **compliant fixture** (`tests/fixtures/compliant-app/`)
   pass it. Watch out: comments in fixtures are scanned too — don't name the
   pattern keywords in prose (that's how we once made a fixture "compliant" by
   describing its own bugs).
4. Add assertions for both outcomes in `tests/run-tests.sh`.
5. Beware substring matches: `grep 'dpo'` once matched "en**dpo**int". Use
   `\b` word boundaries for short tokens.
6. The Python package bundles a copy of the scanner. After editing it, sync:
   `cp skills/dpdpa-compliance/scripts/audit-scan.sh python/src/dpdpa_audit/data/audit-scan.sh`
   — the test suite fails if the two files differ.

## Adding framework patterns

Framework patterns live in `skills/dpdpa-compliance/references/`:

- `implementation-patterns.md` — Node.js, Python/Django, Laravel, React,
  React Native, SQL, Consent Manager integration
- `implementation-patterns-go-rails-spring.md` — Go, Rails, Spring Boot

For a new framework (Flutter, Next.js, FastAPI, …), cover at minimum:
consent recording + withdrawal (Sections 4-6), data export (Section 11),
erasure with the Rule 8(2) 48-hour notice (Section 12), grievance with the
Rule 14(3) 90-day SLA (Section 13), and children's data gating (Section 9).
Keep code idiomatic for the framework and comment each block with the
section/rule it implements.

## Updating for MeitY notifications

When MeitY notifies amendments, new rules, or Consent Manager registrations:

1. Update `references/dpdpa-full-text.md` with the notified text.
2. Propagate to `SKILL.md`, the checklist, patterns, and scanner as needed.
3. Update the "last verified" date and dates table in `SKILL.md`.
4. Add a `CHANGELOG.md` entry referencing the gazette notification number.

## Translations

Consent notice and privacy notice templates in Eighth Schedule languages are
very welcome — Rule 3 requires clear, plain language, and for government
services notices must be available in English plus an Eighth Schedule
language. Keep the English source next to the translation so reviewers can
diff meaning.

## Releases

Versioning is semver on the npm package (`dpdpa-audit`). Scanner behaviour
changes are minor versions; check removals or output-format changes are major.
