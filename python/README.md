# dpdpa-audit

Audit any codebase for compliance with India's **Digital Personal Data
Protection Act, 2023 (DPDPA)** and the **DPDP Rules, 2025** — 52 automated
checks, no AI agent required.

The core obligations become enforceable on **13 May 2027**, with penalties up
to ₹250 crore per breach category. This tool scans a repository and writes a
Markdown report with findings mapped to DPDPA sections, severity ratings, and
remediation guidance.

## Install and run

```bash
pipx install dpdpa-audit          # or: pip install dpdpa-audit / uvx dpdpa-audit
dpdpa-audit                        # scan the current directory
dpdpa-audit ./my-app -o report.md
dpdpa-audit . --fail-on high       # CI gate: exit non-zero on Critical/High findings
```

Requires Python ≥ 3.9 and `bash` on PATH (Linux, macOS, WSL, Git Bash).

## What it checks

52 checks across consent collection, notice, data minimization and retention,
security safeguards, breach notification, children's data protection, Data
Principal rights, cross-border transfer, processor oversight, and Consent
Manager integration — each citing the section of the Act or the DPDP Rules
2025 it verifies.

This is the Python distribution of the scanner from
[vins13pattar/dpdpa-compliance](https://github.com/vins13pattar/dpdpa-compliance),
which also ships an npm CLI and an Agent Skill for Claude Code, Cursor,
Copilot, and 37+ other coding agents. The full project includes framework
implementation patterns (Node, Django, Laravel, Go, Rails, Spring Boot, React,
React Native) and organizational compliance guidance.

**Disclaimer:** technical compliance guidance, not legal advice.
