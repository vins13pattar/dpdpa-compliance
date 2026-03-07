# DPDPA Organizational Guidelines

Obligations under the Digital Personal Data Protection Act, 2023 that cannot be fully addressed
in application code. These require organizational policies, legal processes, and human oversight.
When these come up during an audit or implementation task, surface them clearly to the user
with actionable next steps.

---

## 1. Data Protection Officer (DPO) Appointment

**DPDPA Section 7f, 10.2a**

### Who Needs a DPO?

- **All Data Fiduciaries** must publish contact information of a DPO or a person who can
  answer questions about data processing (Section 7f)
- **Significant Data Fiduciaries** must formally appoint a DPO who is based in India and
  serves as the point of contact for grievance redressal (Section 10.2a)

### What Coding Agents Can Do

- Add DPO contact information to the application (footer, settings, privacy page)
- Create a grievance submission form routed to the DPO
- Set up email routing to the DPO address

### What Requires Human Action

- Actually appointing a qualified DPO
- Defining the DPO's authority and reporting structure
- Ensuring the DPO has adequate resources and independence
- For Significant Data Fiduciaries: ensuring the DPO is based in India

### Recommendation Template

> **Action Required: DPO Appointment**
>
> Your application processes personal data, making you a Data Fiduciary under DPDPA.
> You must publish contact information for a person who can answer data processing
> questions (Section 7f). If designated as a Significant Data Fiduciary, you must
> formally appoint a DPO based in India (Section 10.2a).
>
> **Next steps:**
> 1. Designate a DPO or responsible person
> 2. Provide their contact details for inclusion in the application
> 3. Establish a grievance handling process with defined SLAs

---

## 2. Data Protection Impact Assessment (DPIA)

**DPDPA Section 10.2c**

### Who Needs a DPIA?

Significant Data Fiduciaries must undertake periodic DPIAs.

### What Coding Agents Can Do

- Generate a data flow map from the codebase (what data goes where)
- Identify all personal data fields in the database schema
- List all third-party services that receive personal data
- Create a template DPIA document pre-filled with technical findings

### What Requires Human Action

- Assessing the necessity and proportionality of processing
- Evaluating risks to Data Principals' rights
- Consulting with stakeholders and the DPO
- Defining risk mitigation measures
- Periodic review and updates

### DPIA Template Structure

```markdown
# Data Protection Impact Assessment

## 1. Project Overview
- Name:
- Description:
- Data Fiduciary:
- DPO:
- Date:

## 2. Data Processing Description
- What personal data is collected:
- Purpose of processing:
- Legal basis (consent / legitimate use):
- Data flow diagram: [attach]

## 3. Necessity and Proportionality
- Is the processing necessary for the stated purpose?
- Could the purpose be achieved with less data?
- Are retention periods proportionate?

## 4. Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Unauthorized access | | | |
| Data breach | | | |
| Inaccurate profiling | | | |
| Cross-border exposure | | | |

## 5. Safeguards and Measures
- Technical measures:
- Organizational measures:
- Contractual measures:

## 6. Sign-off
- DPO approval:
- Management approval:
- Review date:
```

---

## 3. Data Processing Agreements (DPAs)

**DPDPA Section 7.2**

### The Obligation

The Data Fiduciary is responsible for all acts, omissions, and operations of its Data Processors.
This means contractual safeguards are essential.

### What Coding Agents Can Do

- Identify all third-party services in the codebase (SDK imports, API calls, cloud configs)
- Generate a list of Data Processors with what data they receive
- Flag processors where no DPA might exist

### What Requires Human Action

- Negotiating and executing DPAs with each processor
- Ensuring DPAs include: processing scope, security obligations, breach notification
  obligations, sub-processor approval requirements, data return/deletion on termination
- Periodic review of processor compliance

### Data Processor Inventory Template

| Processor | Service | Data Shared | Purpose | Location | DPA Status |
|-----------|---------|-------------|---------|----------|------------|
| AWS | Cloud hosting | All app data | Infrastructure | Mumbai (ap-south-1) | ☐ Review |
| SendGrid | Email | Email, name | Transactional email | US | ☐ Needed |
| Google Analytics | Analytics | Usage data, IP | Analytics | US | ☐ Needed |
| Razorpay | Payments | Payment info | Payment processing | India | ☐ Review |

---

## 4. Breach Response Playbook

**DPDPA Section 7d**

### The Obligation

On detecting a personal data breach, the Data Fiduciary must inform:
1. The Data Protection Board of India — in prescribed form and manner
2. Each affected Data Principal — in prescribed form and manner

### What Coding Agents Can Do

- Implement automated breach detection (anomaly detection, access monitoring)
- Build notification pipelines (email templates, Board reporting API integration)
- Create incident logging and tracking systems

### What Requires Human Action

- Defining the incident response team and escalation chain
- Conducting forensic investigation
- Making the determination of whether a breach has occurred
- Communicating with the Board and affected individuals
- Managing legal and PR consequences
- Post-incident review and remediation

### Breach Response Procedure

```
PHASE 1: DETECTION (0-1 hours)
├── Automated alert triggered
├── On-call engineer assesses severity
├── Escalate to Incident Commander if confirmed
└── Activate incident response team

PHASE 2: CONTAINMENT (1-4 hours)
├── Isolate affected systems
├── Preserve evidence for forensics
├── Assess scope: what data, how many users
└── Document all actions taken

PHASE 3: NOTIFICATION (As prescribed — err on speed)
├── Prepare Board notification (prescribed form TBD)
├── Prepare Data Principal notifications
├── Notify DPO
├── Legal counsel review of notifications
└── Send notifications

PHASE 4: RECOVERY (Days)
├── Remediate vulnerability
├── Restore systems
├── Verify containment
└── Monitor for further indicators

PHASE 5: POST-INCIDENT (Weeks)
├── Root cause analysis
├── Update security measures
├── Update DPIA if needed
├── Board follow-up reporting
└── Internal lessons learned
```

---

## 5. Records of Processing Activities (ROPA)

**Best Practice (not explicitly mandated but strongly implied by Section 7)**

### What Coding Agents Can Do

- Auto-generate a ROPA from codebase analysis (data models, APIs, third-party integrations)
- Create a living document that updates as code changes

### ROPA Template

| Processing Activity | Personal Data | Legal Basis | Data Subjects | Recipients | Retention | Safeguards |
|---------------------|---------------|-------------|---------------|------------|-----------|------------|
| User registration | Name, email, phone | Consent | Users | DB, email provider | Account lifetime + 90 days | Encryption, access control |
| Payment processing | Card details, billing address | Consent | Paying users | Payment gateway | Per PCI-DSS | PCI compliance, tokenization |
| Analytics | Usage patterns, IP | Consent | All users | Analytics provider | 180 days | Anonymization |

---

## 6. Employee Training and Awareness

### What Requires Human Action

- Train all employees who handle personal data on DPDPA obligations
- Specific training for engineering teams on secure coding and privacy by design
- DPO-specific training on Board procedures and grievance handling
- Annual refresher training
- Document training completion

---

## 7. Consent Manager Registration

**DPDPA Section 2d, 4.7**

If you plan to use or operate as a Consent Manager (a registered entity that helps Data
Principals manage consent across services):

### What Requires Human Action

- Register with the Data Protection Board (when registration process is established)
- Ensure the platform is accessible, transparent, and interoperable
- Maintain records of all consent transactions

### Status

As of the knowledge cutoff, the Board has not yet been constituted and registration
procedures have not been prescribed. Monitor MeitY announcements.

---

## 8. Significant Data Fiduciary Designation

**DPDPA Section 10**

### Assessment Factors

The Central Government considers:
- Volume and sensitivity of personal data processed
- Risk to Data Principals' rights
- Potential impact on sovereignty and integrity of India
- Risk to electoral democracy
- Security of the State
- Public order

### If Designated

Additional obligations include:
1. Appoint India-based DPO
2. Appoint independent data auditor
3. Conduct periodic DPIAs
4. Undertake periodic audits
5. Other measures as prescribed

### What Coding Agents Can Do

- Implement comprehensive audit logging
- Build DPIA automation tooling
- Create compliance dashboards for DPO oversight
- Integrate with audit frameworks

---

## 9. Cross-Border Data Transfer Restrictions

**DPDPA Section 16**

### Current Status

The Central Government has not yet issued notifications restricting transfer to specific
countries. Until then, transfers are generally permitted.

### Proactive Measures

- Document all cross-border data flows
- Implement configuration-based country restrictions (can be toggled when restrictions are notified)
- Prefer data residency in India where feasible
- Include cross-border transfer clauses in DPAs

### What Coding Agents Can Do

```javascript
// config/dataResidency.js
// Proactive cross-border transfer control

const BLOCKED_COUNTRIES = [
  // Populated when Central Government issues notifications
  // Example: 'XX' for country code
];

function isTransferAllowed(destinationCountry) {
  return !BLOCKED_COUNTRIES.includes(destinationCountry);
}

// Use in data export/sharing logic
function validateDataTransfer(data, destination) {
  if (!isTransferAllowed(destination.country)) {
    throw new Error(
      `Data transfer to ${destination.country} is restricted under DPDPA Section 16.`
    );
  }
}
```

---

## 10. Handling Government/State Data Processing

**DPDPA Section 17**

### Exemptions for State Processing

The government can process personal data without most DPDPA obligations for:
- Sovereignty and integrity of India
- Security of the State
- Friendly relations with foreign States
- Public order
- Preventing cognisable offences

**However:** Security safeguards (Section 7c) and breach notification (Section 7d) still apply
even under these exemptions.

### What This Means for Apps

If your app processes data on behalf of or in partnership with government entities:
- The government partner may be exempt from consent requirements
- You (as Data Processor) are still bound by your obligations
- Security safeguards and breach notification are always required
- Document the legal basis for any exemption relied upon

---

## When to Escalate to Legal Counsel

Always recommend legal consultation for:
1. Determining whether the organization qualifies as a Significant Data Fiduciary
2. Interpreting "legitimate uses" for specific processing activities
3. Assessing cross-border transfer compliance once restrictions are notified
4. Responding to enforcement actions from the Data Protection Board
5. Complex consent architecture (multi-party data sharing, consent inheritance)
6. Interpreting exemptions under Section 17
7. Evaluating whether processing could "detrimentally affect" a child's well-being
8. Any situation where penalties could apply (up to Rs. 250 crore)
