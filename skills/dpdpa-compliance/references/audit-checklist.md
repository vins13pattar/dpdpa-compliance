# DPDPA Compliance Audit Checklist

A systematic 52-point checklist for auditing application codebases against the Digital Personal Data
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

### A7. Consent Version Tracking
**Search for:** consent_version, notice_version, policy_version in consent records
**Check:** Each consent record stores which version of the privacy notice was shown
at the time of consent. When the notice is updated, new consent is collected against
the new version, and historical records reference the exact version the user agreed to.
```
// VIOLATION: Consent stored without notice version
{ userId: "u123", consentedAt: "2024-01-15", purpose: "marketing" }

// COMPLIANT: Consent record includes notice version
{ userId: "u123", consentedAt: "2024-01-15", purpose: "marketing", noticeVersion: "2.1" }
```

### A8. Consent Expiry and Renewal
**Search for:** consent_expiry, consent_renewal, consent_ttl, reconfirm_consent
**Check:** Consent has a defined validity period and users are prompted to renew
consent periodically. Stale consent (e.g., granted years ago with no reconfirmation)
should not be treated as perpetually valid.
```
// COMPLIANT: Consent with expiry and renewal check
if (consent.grantedAt < Date.now() - CONSENT_TTL) {
  promptConsentRenewal(user);
}
```

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

### C5. Anonymization Validation
**Search for:** anonymize, pseudonymize, mask, hash_pii, de_identify
**Check:** If anonymization is used as an alternative to deletion, verify that it
is truly irreversible and cannot be re-identified. Pseudonymization (where a mapping
key exists to reverse the process) does not qualify as anonymization under DPDPA.
```
// VIOLATION: Reversible pseudonymization treated as anonymization
const anonymize = (email) => encrypt(email, SECRET_KEY); // can be decrypted

// COMPLIANT: Irreversible anonymization
const anonymize = (email) => {
  // One-way hash with no stored mapping — cannot be reversed
  return crypto.createHash('sha256').update(email + salt).digest('hex');
};
```

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

### D7. Hardcoded Secrets and Credentials
**Search for:** source code for hardcoded API keys, passwords, tokens, connection strings
**Check:** No API keys, database passwords, tokens, or connection strings are hardcoded
in source files. Hardcoded credentials risk unauthorized access to personal data stores.
Use environment variables, secrets managers, or vault services instead.
```
// VIOLATION: Hardcoded database credentials
const db = mysql.connect({
  host: "db.example.com",
  password: "SuperSecret123"
});

// COMPLIANT: Credentials from environment/secrets manager
const db = mysql.connect({
  host: process.env.DB_HOST,
  password: await secretsManager.get("db-password")
});
```

### D8. Personal Data in Error Responses
**Search for:** error handlers, catch blocks, API error responses
**Check:** Stack traces and error messages do not leak personal data (emails, names,
user IDs) to end users. Error responses should return generic messages in production
while logging detailed errors server-side.
```
// VIOLATION: Leaking personal data in error response
catch (err) {
  res.status(500).json({ error: `Failed to process user ${user.email}: ${err.stack}` });
}

// COMPLIANT: Generic error to client, detailed log server-side
catch (err) {
  logger.error("Processing failed", { userId: user.id, error: err.stack });
  res.status(500).json({ error: "An internal error occurred. Please try again." });
}
```

### D9. Secure Session Management
**Search for:** session configuration, cookie settings, token expiry
**Check:** Sessions accessing personal data use secure flags (HttpOnly, Secure,
SameSite), have reasonable expiry times, and are invalidated on logout.
```
// VIOLATION: Insecure session cookie configuration
app.use(session({ cookie: { secure: false } }));

// COMPLIANT: Secure session configuration
app.use(session({
  cookie: {
    secure: true,
    httpOnly: true,
    sameSite: 'strict',
    maxAge: 30 * 60 * 1000 // 30 minutes
  },
  rolling: true
}));
```

### D10. Rate Limiting on Data Endpoints
**Search for:** rate_limit, throttle, rateLimit on endpoints that serve personal data
**Check:** Endpoints that serve personal data have rate limiting to prevent bulk
extraction. Without rate limits, an attacker or rogue insider could scrape all
personal data records.
```
// COMPLIANT: Rate limiting on personal data endpoint
app.get('/api/users/:id/profile',
  rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }),
  authMiddleware,
  profileController.get
);
```

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

### E5. Breach Severity Classification
**Search for:** breach_severity, breach_level, incident_classification, risk_rating
**Check:** A system exists to classify breaches by severity (e.g., low, medium, high,
critical) to determine notification urgency and scope. Severity classification drives
whether the Board and Data Principals must be notified immediately or within standard
timelines.

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

### F5. Child Account Identification
**Search for:** is_child, is_minor, child_flag, account_type.*child, age_group in database schemas or models
**Check:** Child accounts are explicitly flagged in the database so that differential
processing rules can be enforced. Without an explicit flag, it is difficult to apply
the stricter requirements of Section 8 at the code level.
```
// VIOLATION: No way to distinguish child accounts
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name TEXT,
  email TEXT,
  date_of_birth DATE
);

// COMPLIANT: Explicit child flag for differential processing
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name TEXT,
  email TEXT,
  date_of_birth DATE,
  is_child BOOLEAN DEFAULT FALSE,
  parental_consent_verified BOOLEAN DEFAULT FALSE
);
```

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

### G6. Rights Request Response Tracking
**Search for:** sla, response_deadline, request_status, days_remaining, due_date in rights/DSAR handling code
**Check:** A mechanism tracks response times to ensure rights requests are fulfilled
within the prescribed period. Each request should have a recorded receipt date,
a calculated deadline, and a status that is monitored for overdue requests.
```
// COMPLIANT: DSAR request with SLA tracking
const dsarRequest = {
  id: "dsar-2024-001",
  type: "erasure",
  receivedAt: "2024-01-15T10:00:00Z",
  deadline: "2024-02-14T10:00:00Z", // 30-day SLA
  status: "in_progress",
  daysRemaining: 15
};
```

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

## K. Legitimate Uses (DPDPA Section 6)

### K1. Voluntary Data Provision
**Search for:** terms of service acceptance, voluntary submission forms, user-initiated data sharing
**Check:** When a Data Principal voluntarily provides data for a specific purpose
(e.g., filling a form for a service), processing is permitted without separate consent
— but only for that stated purpose. Verify that voluntarily provided data is not
repurposed beyond the original stated purpose.
```
// VIOLATION: Voluntarily submitted support ticket data repurposed for marketing
const handleSupportTicket = (ticket) => {
  saveTicket(ticket);
  marketingService.addLead(ticket.email, ticket.name); // repurposing
};

// COMPLIANT: Data used only for the stated purpose
const handleSupportTicket = (ticket) => {
  saveTicket(ticket);
  // email and name used only for support resolution
};
```

### K2. State Function Processing
**Search for:** government integrations, public service APIs, statutory function handlers
**Check (advisory):** Processing for functions of the State — subsidies, benefits,
licenses, permits — is a legitimate use under Section 6. If your application integrates
with government services, document the statutory basis for each integration and ensure
data processed under this ground is not used for unrelated purposes.

### K3. Legal Obligation Processing
**Search for:** court order handlers, legal hold mechanisms, regulatory compliance, statutory retention
**Check (advisory):** Processing required by law (court orders, regulatory requirements)
is a legitimate use under Section 6. Check that legal holds prevent deletion of data
subject to legal proceedings, and that the legal basis is documented for each such
processing activity.
```
// COMPLIANT: Legal hold prevents deletion of data under court order
const handleDeletionRequest = async (userId) => {
  const legalHold = await checkLegalHold(userId);
  if (legalHold.active) {
    logger.info("Deletion deferred due to legal hold", { userId, holdId: legalHold.id });
    return { status: "deferred", reason: "legal_hold" };
  }
  await deleteUserData(userId);
  return { status: "completed" };
};
```

---

## Scoring Guide

Calculate compliance score as: (PASS items / (Total items - NOT APPLICABLE items)) x 100

This checklist contains 52 items across 11 sections (A through K).

| Score | Rating |
|-------|--------|
| 90-100% | Strong compliance posture |
| 70-89% | Moderate — address Critical and High items |
| 50-69% | Weak — significant remediation needed |
| Below 50% | Critical — substantial compliance risk |
