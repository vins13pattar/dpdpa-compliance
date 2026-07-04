# AGENTS.md

This repository contains an Agent Skill for DPDPA (Digital Personal Data Protection Act, 2023)
compliance. The skill helps coding agents audit, implement, and remediate data protection
compliance for applications serving users in India.

## Repository Structure

```
dpdpa-compliance/
├── README.md                                 # Repository documentation
├── AGENTS.md                                 # This file — agent guidance
├── CHANGELOG.md                              # Releases tied to MeitY notifications
├── CONTRIBUTING.md                           # Add-a-check workflow, pattern guidelines
├── LICENSE                                   # MIT license
├── package.json                              # npm package: dpdpa-audit CLI
├── cli/
│   └── dpdpa-audit.js                        # Standalone CLI wrapping the scanner (Node)
├── python/
│   └── src/dpdpa_audit/                      # PyPI package (bundles a synced scanner copy)
├── tests/
│   ├── run-tests.sh                          # Scanner + CLI test suite
│   └── fixtures/                             # Known-vulnerable / known-compliant apps
└── skills/
    └── dpdpa-compliance/                     # The skill
        ├── SKILL.md                          # Main skill definition
        ├── scripts/
        │   └── audit-scan.sh                 # Automated codebase scanner (52 checks)
        └── references/
            ├── audit-checklist.md            # 52-point audit checklist
            ├── implementation-patterns.md    # Node, Python, Laravel, React, RN, SQL,
            │                                 #   Consent Manager integration
            ├── implementation-patterns-go-rails-spring.md  # Go, Rails, Spring Boot
            ├── organizational-guidelines.md  # Non-code obligations
            └── dpdpa-full-text.md            # Act + DPDP Rules 2025 full text
```

## Working with This Skill

- **SKILL.md** is the entry point — read it first to understand the three operating modes
- **references/** contain deep-dive documents — load only when needed for a specific task
- **scripts/audit-scan.sh** runs a pattern-based scan and outputs a markdown report
- **tests/run-tests.sh** must stay green — run it after any change to the scanner or CLI;
  changes to scanner checks need matching fixture coverage (see CONTRIBUTING.md)

## Conventions

- Skill directory: kebab-case (`dpdpa-compliance`)
- SKILL.md: Always uppercase, always this exact filename
- References: kebab-case markdown files
- Scripts: kebab-case bash scripts with `#!/bin/bash` and `set -e`
- All DPDPA section references use the format "Section X" matching the Act's numbering
