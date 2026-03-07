# AGENTS.md

This repository contains an Agent Skill for DPDPA (Digital Personal Data Protection Act, 2023)
compliance. The skill helps coding agents audit, implement, and remediate data protection
compliance for applications serving users in India.

## Repository Structure

```
dpdpa-compliance/
├── README.md                                 # Repository documentation
├── AGENTS.md                                 # This file — agent guidance
├── LICENSE                                   # MIT license
└── skills/
    └── dpdpa-compliance/                     # The skill
        ├── SKILL.md                          # Main skill definition
        ├── scripts/
        │   └── audit-scan.sh                 # Automated codebase scanner
        └── references/
            ├── audit-checklist.md            # 50+ point audit checklist
            ├── implementation-patterns.md    # Code patterns for multiple frameworks
            ├── organizational-guidelines.md  # Non-code obligations
            └── dpdpa-full-text.md            # Full Act text
```

## Working with This Skill

- **SKILL.md** is the entry point — read it first to understand the three operating modes
- **references/** contain deep-dive documents — load only when needed for a specific task
- **scripts/audit-scan.sh** runs a pattern-based scan and outputs a markdown report

## Conventions

- Skill directory: kebab-case (`dpdpa-compliance`)
- SKILL.md: Always uppercase, always this exact filename
- References: kebab-case markdown files
- Scripts: kebab-case bash scripts with `#!/bin/bash` and `set -e`
- All DPDPA section references use the format "Section X" matching the Act's numbering
