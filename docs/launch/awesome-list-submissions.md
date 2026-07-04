# Awesome-List Submissions

Ready-to-PR entries for community lists. Each list has its own contribution
format — check its CONTRIBUTING.md before opening the PR. One PR per list,
entry only (no other changes), alphabetical position within the section.

## Target lists

| List | Section to add under | Notes |
|------|----------------------|-------|
| [awesome-privacy (pluja)](https://github.com/pluja/awesome-privacy) | Developer tools | Consumer-leaning; pitch the CLI |
| [awesome-privacy-engineering](https://github.com/trackingexposed/awesome-privacy-engineering) or similar | Compliance tooling | Best topical fit |
| [awesome-compliance](https://github.com/search?q=awesome-compliance) | Data protection / privacy | Verify the maintained fork before PRing |
| [awesome-security](https://github.com/sbilly/awesome-security) | Big lists move slowly | Web / auditing |
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Skills | Agent-skill angle |
| [awesome-india](https://github.com/dexbleeker/awesome-india) or regional dev lists | Tools | India-specific relevance |

## Entry text (Markdown, adapt bullet style per list)

Short:

```markdown
- [dpdpa-compliance](https://github.com/vins13pattar/dpdpa-compliance) - Open-source scanner and AI agent skill for India's DPDPA (Digital Personal Data Protection Act) — 52 automated checks, framework code patterns, CI gate.
```

Long:

```markdown
- [dpdpa-compliance](https://github.com/vins13pattar/dpdpa-compliance) - Audit any codebase for compliance with India's DPDP Act 2023 + DPDP Rules 2025. Standalone CLI (`npx dpdpa-audit`) with 52 checks mapped to sections of the Act, plus an Agent Skill for Claude Code/Cursor/Copilot that generates compliant consent, erasure, and breach-notification code for Node, Django, Laravel, Go, Rails, and Spring Boot. MIT.
```

## PR description template

```markdown
Adding dpdpa-compliance — open-source developer tooling for India's DPDPA
(enforceable 13 May 2027, penalties to ₹250 crore). The compliance tooling
space for this law is otherwise entirely commercial platforms; this is a
free CLI + AI agent skill: 52 automated checks with section citations,
framework implementation patterns, tested against fixture apps in CI.
MIT licensed, active, accepting contributions.
```

## GitHub repo metadata (set in repo Settings — cannot be set from a fork/PR)

- **Topics:** `dpdpa`, `dpdp-act`, `data-protection`, `privacy`, `compliance`,
  `india`, `audit`, `agent-skills`, `claude-code`, `security-tools`
- **Description:** "Open-source DPDPA (India) compliance: 52-check codebase
  scanner + AI agent skill. Audit before the 13 May 2027 deadline."
- **Website:** https://vins13pattar.github.io/dpdpa-compliance/
- Enable **Discussions** (Settings → General → Features) for compliance Q&A
```
