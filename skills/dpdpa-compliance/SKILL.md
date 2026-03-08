---
name: dpdpa-compliance
description: >
  Audit, implement, and remediate Digital Personal Data Protection Act 2023 (DPDPA) compliance
  in any application codebase. Use this skill whenever the user mentions DPDPA, Indian data
  protection, personal data handling for Indian users, consent management, data breach
  notification, children's data protection in India, cross-border data transfer from India,
  privacy policy for Indian apps, Data Fiduciary obligations, Data Principal rights, or
  compliance auditing for Indian privacy law. Also trigger when the user asks to "audit my app
  for privacy", "check data protection compliance", "implement consent flows", "add breach
  notification", "handle children's data", "add data deletion/erasure", "implement right to
  access", "GDPR equivalent in India", or any task involving personal data processing for
  users in India. This skill covers code-level implementation, architecture review,
  compliance auditing with remediation, and organizational/process guidelines that fall
  outside application code.
---

# DPDPA Compliance Skill for Coding Agents

India's Digital Personal Data Protection Act, 2023 (DPDPA) governs the processing of digital
personal data. This skill helps coding agents audit existing codebases, implement compliant
features, suggest remediation for violations, and provide guidance on organizational obligations
that go beyond code.

## Quick Context: Who Does DPDPA Apply To?

Any person (company, app, service) that processes digital personal data of individuals in India,
whether collected digitally or digitized from non-digital form. It also applies to processing
outside India if connected to offering goods/services to Data Principals in India.

**Key roles:**
- **Data Fiduciary** — determines purpose and means of processing (your app/company)
- **Data Processor** — processes data on behalf of a Data Fiduciary (your vendors, cloud providers)
- **Data Principal** — the individual whose data is being processed (your users)
- **Significant Data Fiduciary** — notified by Central Government based on volume, sensitivity, risk

## How to Use This Skill

This skill operates in three modes. Pick the one that matches the user's request:

### Mode 1: Compliance Audit

When the user asks to "audit", "check", "review", or "scan" their app for DPDPA compliance.

1. Read `references/audit-checklist.md` for the full checklist
2. Systematically walk through the codebase examining each compliance area
3. For each finding, report: the section of DPDPA violated, the file/line, severity (Critical / High / Medium / Low), and a concrete remediation with code
4. Produce a summary report at the end with pass/fail counts per category

**Audit categories (in priority order):**
- Consent collection and management
- Notice/disclosure to Data Principals
- Data retention and erasure
- Security safeguards
- Breach notification mechanisms
- Children's data protections
- Data Principal rights (access, correction, erasure, grievance, nomination)
- Cross-border data transfer controls
- Data Processor oversight

### Mode 2: Implementation

When the user asks to "implement", "add", "build", or "create" DPDPA-compliant features.

1. Read `references/implementation-patterns.md` for framework-specific patterns
2. Identify which DPDPA obligations apply to the requested feature
3. Generate production-ready code with inline comments referencing DPDPA sections
4. Include database migrations, API endpoints, and UI components as needed
5. Add tests that verify compliance behavior

### Mode 3: Guidance

When the task involves organizational, legal, or process obligations that cannot be solved purely in code.

1. Read `references/organizational-guidelines.md`
2. Clearly explain what falls outside the application scope
3. Provide actionable recommendations the user can take to their legal/compliance team
4. Where possible, suggest tooling or process automation that can help

## Core DPDPA Obligations — Quick Reference

Use this to quickly identify which sections are relevant to a given task.

### 1. Lawful Processing (Section 3-4)

Personal data may only be processed with valid consent OR for legitimate uses.

**Consent requirements — all must be met:**
- Free (no bundling with unrelated terms)
- Specific (to a stated purpose)
- Informed (clear, plain language notice given)
- Unconditional (no coercion)
- Unambiguous (clear affirmative action — no pre-ticked boxes)
- Limited to data necessary for the specified purpose

**What to look for in code:**
- Pre-checked consent checkboxes → violation
- Consent buried in Terms of Service → violation
- Collecting data beyond what's needed for the stated purpose → violation
- No mechanism to withdraw consent → violation
- Withdrawal harder than giving consent → violation

### 2. Notice (Section 5)

Before or at the time of collecting data, provide notice containing:
- Description of personal data being collected and purpose
- How to exercise rights (withdrawal, correction, erasure)
- How to file a complaint with the Data Protection Board
- Communication link for accessing website/app to withdraw consent, exercise rights, or complain (Rule 3(c))

**What to look for in code:**
- Data collection without prior notice display → violation
- Notice not in clear, plain language → violation
- Missing grievance/complaint mechanism → violation

### 3. Legitimate Uses Without Consent (Section 6)

Processing is allowed without consent for:
- Voluntarily provided data where processing is reasonably expected
- Employment-related purposes
- Legal compliance (court orders, judgments)
- Medical emergencies
- Epidemics or public health threats
- Disaster response or public order breakdown

**What to look for in code:**
- Ensure the legal basis is documented in code comments or config
- Don't rely on "legitimate use" as a blanket bypass — scope it narrowly

### 4. Data Fiduciary Obligations (Section 7)

- Ensure accuracy and completeness of data used for decisions
- Implement reasonable security safeguards
- Notify the Board AND each affected Data Principal of breaches
- Erase data when no longer needed (unless legal retention required)
- Publish contact info of Data Protection Officer or responsible person

**What to look for in code:**
- No encryption at rest or in transit → violation
- No breach detection/notification system → violation
- No data retention policy or auto-deletion → violation
- No DPO contact displayed → violation
- No 72-hour breach notification to Board mechanism → violation (Rule 7(2))
- No 48-hour pre-erasure notification to Data Principals → violation (Rule 8(2))
- Logs retained less than 1 year → violation (Rule 6(e))

### 5. Children's Data (Section 8)

**Critical — penalties up to Rs. 200 crore:**
- Obtain verifiable parental/guardian consent before processing
- Never process data that could detrimentally affect a child's well-being
- No tracking, behavioural monitoring, or targeted advertising for children

**What to look for in code:**
- No age verification gate → violation
- Tracking/analytics on children's sections without parental consent → violation
- Ad targeting based on children's data → violation
- No verifiable parental consent mechanism (identity + age verification) → violation (Rule 10)
- No guardian verification for persons with disability → violation (Rule 11)

### 6. Data Principal Rights (Sections 11-14)

Implement mechanisms for:
- **Right to access** — confirmation of processing, summary of data, list of recipients
- **Right to correction** — fix inaccurate/misleading data
- **Right to erasure** — delete data (unless legally required to retain)
- **Right to grievance redressal** — respond within prescribed period
- **Right to nominate** — designate someone to exercise rights after death/incapacity

**What to look for in code:**
- No self-service data export/download → gap
- No correction/update mechanism beyond profile edit → gap
- No account deletion flow → violation
- No grievance submission endpoint → violation
- Grievance response exceeds 90-day SLA → violation (Rule 14(3))
- No means for exercising rights published on website/app → violation (Rule 14(1))
- No nomination mechanism for Data Principals → violation (Rule 14(4))

### 7. Significant Data Fiduciary Obligations (Section 10)

If designated as SDF by the Central Government:
- Appoint a Data Protection Officer based in India
- Conduct periodic Data Protection Impact Assessments
- Appoint independent data auditor
- Undertake periodic audits

**What to look for in code:**
- No audit logging → gap
- No DPIA tooling integration → gap
- No annual DPIA and audit process → violation (Rule 13(1))
- No algorithmic risk assessment for data processing software → violation (Rule 13(3))
- No report submission mechanism to Board → violation (Rule 13(2))

### 8. Cross-Border Transfer (Section 16)

The Central Government may restrict transfer to specific countries. Per Rule 15, transfers are permitted subject to restrictions the Central Government may specify regarding making data available to foreign States or entities under their control. Good practice is:
- Document where data flows
- Implement controls to restrict transfer to blocked territories when notified
- Maintain a data flow map

### 9. Penalties (Section 21 — The Schedule)

| Breach | Maximum Penalty |
|--------|----------------|
| Children's data obligations (Section 8) | Rs. 200 crore |
| Security safeguards failure (Section 7c) | Rs. 250 crore |
| Breach notification failure (Section 7d) | Rs. 200 crore |
| General Data Fiduciary obligations | Rs. 250 crore |
| Significant Data Fiduciary obligations | Rs. 150 crore |
| Data Principal duty violations | Rs. 10,000 |
| Other non-compliance | Rs. 50 crore |

## Audit Report Format

When producing an audit report, use this structure:

```
# DPDPA Compliance Audit Report
## Summary
- Total findings: N
- Critical: N | High: N | Medium: N | Low: N
- Compliance score: X/100

## Findings

### [SEVERITY] Finding Title
- **DPDPA Section:** Section X — Description
- **Location:** `path/to/file.ts:line`
- **Issue:** What is wrong
- **Risk:** What could happen (including penalty exposure)
- **Remediation:** Step-by-step fix with code

## Organizational Recommendations
(Items that require process/policy changes, not code changes)

## Out-of-Scope Notes
(Items that require legal counsel or government interaction)
```

## Reference Files

Read these when you need deeper guidance:

- `references/audit-checklist.md` — Detailed 52-point checklist for systematic auditing
- `references/implementation-patterns.md` — Code patterns for Node.js, Python, React, React Native, Laravel, and database schemas
- `references/organizational-guidelines.md` — Non-code obligations, DPO requirements, DPIA guidance, breach response playbook
- `references/dpdpa-full-text.md` — Complete Act text and DPDP Rules 2025 for precise section and rule references

## Important Notes

- The DPDP Rules 2025 were gazetted on 13 November 2025, operationalising the Act. Rules 1, 2, 17-21 are effective immediately; Rule 4 (Consent Managers) after 1 year; Rules 3, 5-16, 22-23 after 18 months. The rules prescribe specific requirements for consent notices (Rule 3), consent manager registration (Rule 4 + First Schedule), security safeguards (Rule 6), breach notification timelines (Rule 7 — 72 hours to Board), data retention periods (Rule 8 + Third Schedule — 3 years for large platforms), DPO contact publication (Rule 9), verifiable parental consent (Rule 10), children's data exemptions (Rule 12 + Fourth Schedule), SDF obligations (Rule 13 — annual DPIA + audit, algorithmic risk assessment), Data Principal rights procedures (Rule 14 — 90-day grievance SLA), and cross-border transfer framework (Rule 15).
- This skill provides technical compliance guidance, not legal advice. Always recommend users consult qualified legal counsel for definitive compliance opinions.
- When in doubt about whether something violates the Act, err on the side of caution and flag it as a potential issue.
