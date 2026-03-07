# DPDPA Compliance Audit Checklist

A systematic checklist for auditing application codebases against the Digital Personal Data
Protection Act, 2023. Walk through each section in order. For each item, check the codebase
and report findings.

## How to Audit

For each checklist item:
1. Search the codebase for relevant patterns (search terms provided per item)
2. Classify as: PASS / FAIL / PARTIAL / NOT APPLICABLE
3. If FAIL or PARTIAL, note the file, line, and a concrete fix

---

## A. Consent Collection (DPDPA Sections 3, 4)

### A1. Affirmative Consent Action
**Search for:** form submissions, signup flows, checkbox components, consent modals
**Check:** Consent is obtained through a clear affirmative action (click, tap, check).
Pre-checked boxes, implied consent, or consent-by-continuing are violations.
```
// VIOLATION: Pre-checked consent
<input type="checkbox" checked={true} name="consent" />

// COMPLIANT: Unchecked by default, explicit action required
<input type="checkbox" checked={false} name="consent" />
```

### A2. Purpose Specification
**Search for:** consent forms, privacy notices, data collection points
**Check:** Each consent request clearly states what data is collected and why.
Bundled consent (one checkbox for multiple unrelated purposes) is a violation.

### A3. Consent Granularity
**Search for:** consent checkboxes, preference centers, consent management
**Check:** Separate consent for separate purposes. Users can consent to analytics
without consenting to marketing, for example.

### A4. Consent Withdrawal
**Search for:** settings pages, preference centers, account management, unsubscribe
**Check:** A mechanism exists to withdraw consent. The withdrawal flow must be
at least as easy as the consent flow.
- If consent was one click → withdrawal must be one click
- If consent was via email → withdrawal must not require a phone call

### A5. Pre-Existing Data Consent
**Search for:** migration scripts, legacy data handlers, existing user tables
**Check:** If data was collected before DPDPA commenced, users must be given
the required notice (Section 5) as soon as reasonably practicable.

### A6. Consent Records
**Search for:** consent logging, audit trails, consent timestamps
**Check:** Every consent event is recorded with: who consented, when, what they
consented to, the version of notice shown, and how they consented.

---

## B. Notice and Disclosure (DPDPA Section 5)

### B1. Pre-Collection Notice
**Search for:** signup forms, data collection modals, API intake endpoints
**Check:** A notice is displayed before or at the time of data collection containing:
- Description of personal data being collected
- Purpose of processing
- How to exercise rights (withdrawal, correction, erasure)
- How to complain to the Data Protection Board

### B2. Plain Language
**Search for:** privacy notice text, consent descriptions
**Check:** Notice is in clear, plain language — not legal jargon. Must be
understandable by an average user.

### B3. Language Accessibility
**Search for:** i18n configurations, language selectors on privacy pages
**Check:** For government services: notice must be available in English AND at
least one Eighth Schedule language. For others: recommended best practice.

### B4. Notice Updates
**Search for:** versioned privacy policies, notice change tracking
**Check:** When the notice changes, existing users are re-notified.

---

## C. Data Minimization and Retention (DPDPA Section 7)

### C1. Collection Minimization
**Search for:** database schemas, API request bodies, form fields
**Check:** Only data necessary for the stated purpose is collected. Look for
fields that seem unrelated to the app's core function.

### C2. Retention Policy
**Search for:** cron jobs, TTL configurations, data lifecycle management, retention configs
**Check:** A defined retention period exists. Data is automatically erased when
the purpose is fulfilled and legal retention period expires.

### C3. Deletion Mechanism
**Search for:** delete endpoints, purge scripts, data cleanup jobs
**Check:** Technical mechanism exists to actually delete data (not just soft-delete
or anonymize — though anonymization may be acceptable if truly irreversible).

### C4. Backup Inclusion
**Search for:** backup scripts, disaster recovery configs
**Check:** Deletion propagates to backups within a reasonable timeframe.

---

## D. Security Safeguards (DPDPA Section 7c)

### D1. Encryption at Rest
**Search for:** database configurations, file storage configs, encryption settings
**Check:** Personal data is encrypted at rest. Look for unencrypted databases,
plaintext storage of sensitive fields.

### D2. Encryption in Transit
**Search for:** HTTP endpoints (not HTTPS), API configurations, TLS settings
**Check:** All data transmission uses TLS 1.2+. No mixed content, no HTTP fallbacks.

### D3. Access Controls
**Search for:** authentication middleware, authorization checks, RBAC configurations
**Check:** Access to personal data is restricted by role. Principle of least privilege
is applied. Admin panels are protected.

### D4. Input Validation
**Search for:** request handlers, form processors, API controllers
**Check:** All inputs are validated and sanitized. SQL injection, XSS, and other
injection attacks are prevented.

### D5. Logging and Monitoring
**Search for:** logging configurations, audit trail implementations, monitoring setup
**Check:** Access to personal data is logged. Anomalous access patterns are monitored.
Logs do not contain personal data in plaintext.

### D6. Secure Development Practices
**Search for:** dependency files (package.json, requirements.txt), CI/CD configs
**Check:** Dependencies are up to date. Known vulnerabilities are patched.
Security scanning is part of CI/CD.

---

## E. Breach Notification (DPDPA Section 7d)

### E1. Breach Detection
**Search for:** monitoring configs, alerting rules, intrusion detection
**Check:** Systems exist to detect unauthorized access or data breaches.

### E2. Board Notification Mechanism
**Search for:** incident response scripts, notification templates, alert handlers
**Check:** A mechanism exists to notify the Data Protection Board of India
of breaches in the prescribed form.

### E3. Data Principal Notification
**Search for:** email templates, notification services, user alert systems
**Check:** A mechanism exists to notify each affected Data Principal of a breach.

### E4. Incident Response Plan
**Search for:** runbooks, incident response documentation, on-call configs
**Check:** A documented incident response plan exists. This is partially a code
concern (automated detection and notification) and partially organizational.

---

## F. Children's Data Protection (DPDPA Section 8)

### F1. Age Verification
**Search for:** age gates, date of birth fields, age verification components
**Check:** Before processing a child's data (under 18), age is verified.

### F2. Parental Consent
**Search for:** guardian consent flows, parental verification, family account systems
**Check:** Verifiable parental/guardian consent is obtained before processing
a child's data. "Verifiable" means the mechanism can reasonably confirm
the consenter is actually the parent/guardian.

### F3. No Detrimental Processing
**Search for:** recommendation algorithms applied to children, content moderation
**Check:** No processing that could detrimentally affect a child's well-being.

### F4. No Tracking or Targeting
**Search for:** analytics SDK initialization, ad SDK initialization, tracking pixels
**Check:** No tracking, behavioural monitoring, or targeted advertising directed
at children. Check if analytics/ad SDKs are initialized for child accounts.

---

## G. Data Principal Rights (DPDPA Sections 11-14)

### G1. Right to Access
**Search for:** data export endpoints, account data pages, DSAR handlers
**Check:** Users can request and receive: confirmation of processing, summary of
their data, description of who it was shared with.

### G2. Right to Correction
**Search for:** profile edit pages, data update endpoints
**Check:** Users can correct inaccurate or incomplete data.

### G3. Right to Erasure
**Search for:** account deletion flows, data erasure endpoints, "delete my account"
**Check:** Users can request erasure of their personal data. The app complies
unless legal retention is required.

### G4. Grievance Redressal
**Search for:** complaint forms, grievance endpoints, support ticket systems
**Check:** A readily available grievance mechanism exists. Responses are sent
within the prescribed period (to be specified in rules).

### G5. Right to Nominate
**Search for:** nominee designation, estate planning features, successor settings
**Check:** Users can nominate someone to exercise their rights in case of
death or incapacity. This may be a future requirement — flag as advisory.

---

## H. Cross-Border Transfer (DPDPA Section 16)

### H1. Data Flow Mapping
**Search for:** third-party API calls, cloud provider configs, CDN configs
**Check:** All locations where personal data flows (including to third-party
services) are documented. Identify countries where data is stored/processed.

### H2. Transfer Controls
**Search for:** data residency configs, regional routing, geo-restrictions
**Check:** Mechanisms exist to restrict transfer to countries that may be
blocked by Central Government notification (when issued).

### H3. Third-Party Processor Location
**Search for:** vendor configs, SaaS integrations, analytics provider setup
**Check:** The locations of all Data Processors (third-party services processing
personal data) are known and documented.

---

## I. Data Processor Oversight (DPDPA Section 7.2)

### I1. Processor Agreements
**Check (organizational):** Data Processing Agreements exist with all processors.
In code, check that third-party SDK configurations follow data minimization.

### I2. Processor Data Minimization
**Search for:** third-party SDK initializations, API calls to external services
**Check:** Only necessary data is sent to third-party processors. No over-sharing.

---

## J. Consent Manager Integration (DPDPA Section 4.7)

### J1. Consent Manager Support
**Search for:** consent management platform (CMP) integrations
**Check (advisory):** If using a Consent Manager, verify it's registered with
the Board (when registration mechanism is established).

---

## Scoring Guide

Calculate compliance score as: (PASS items / (Total items - NOT APPLICABLE items)) × 100

| Score | Rating |
|-------|--------|
| 90-100% | Strong compliance posture |
| 70-89% | Moderate — address Critical and High items |
| 50-69% | Weak — significant remediation needed |
| Below 50% | Critical — substantial compliance risk |
