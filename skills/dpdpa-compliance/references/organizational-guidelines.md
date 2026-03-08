# DPDPA Organizational Guidelines

Obligations under the Digital Personal Data Protection Act, 2023 that cannot be fully addressed
in application code. These require organizational policies, legal processes, and human oversight.
When these come up during an audit or implementation task, surface them clearly to the user
with actionable next steps.

---

## 1. Data Protection Officer (DPO) Appointment

**DPDPA Section 7f, 10.2a | Rule 9**

### Who Needs a DPO?

- **All Data Fiduciaries** must publish contact information of a DPO or a person who can
  answer questions about data processing (Section 7f)
- **Significant Data Fiduciaries** must formally appoint a DPO who is based in India and
  serves as the point of contact for grievance redressal (Section 10.2a)

### What Coding Agents Can Do

- Add DPO contact information to the application (footer, settings, privacy page)
- Create a grievance submission form routed to the DPO
- Set up email routing to the DPO address
- Ensure DPO/contact person info is prominently published on website AND app (Rule 9 — mandatory)
- Include contact info in every response to Data Principal rights communications (Rule 9)

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

**DPDPA Section 10.2c | Rule 13**

### Who Needs a DPIA?

Significant Data Fiduciaries must undertake periodic DPIAs.

Under Rule 13(1), Significant Data Fiduciaries must complete a DPIA AND audit **once every 12 months** from the date of notification as SDF. The person conducting the DPIA and audit must furnish a report of significant observations to the Board (Rule 13(2)).

Additionally, SDFs must verify that algorithmic software used for processing personal data does not pose a risk to Data Principals' rights (Rule 13(3)).

SDFs may be required to ensure specified personal data is processed with data localization restrictions (Rule 13(4)).

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

**DPDPA Section 7.2 | Rule 6(f)**

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
- Reasonable security safeguards as mandated by Rule 6, including encryption/obfuscation/masking,
  access controls, logging with 1-year minimum retention, backup measures, and technical/organisational measures
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

**DPDPA Section 7d | Rule 7**

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

PHASE 3: NOTIFICATION (Rule 7 — strict timelines)
├── IMMEDIATE: Notify Board with breach description, nature, extent, timing, location, likely impact (Rule 7(2)(a))
├── IMMEDIATE: Notify each affected Data Principal via user account or registered communication with:
│   ├── Description of breach (nature, extent, timing) (Rule 7(1)(a))
│   ├── Consequences likely to arise (Rule 7(1)(b))
│   ├── Mitigation measures taken/planned (Rule 7(1)(c))
│   ├── Safety measures the DP can take (Rule 7(1)(d))
│   └── Business contact info for queries (Rule 7(1)(e))
├── WITHIN 72 HOURS: Submit detailed report to Board containing:
│   ├── Updated and detailed breach description (Rule 7(2)(b)(i))
│   ├── Broad facts of events and circumstances (Rule 7(2)(b)(ii))
│   ├── Measures implemented or proposed (Rule 7(2)(b)(iii))
│   ├── Findings regarding the person who caused breach (Rule 7(2)(b)(iv))
│   ├── Remedial measures to prevent recurrence (Rule 7(2)(b)(v))
│   └── Report of intimations given to affected DPs (Rule 7(2)(b)(vi))
├── Notify DPO
├── Legal counsel review
└── Send all notifications

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

### Registration Requirements (Rule 4 + First Schedule Part A)

The DPDP Rules 2025 prescribe detailed registration conditions:
1. Must be a company incorporated in India
2. Net worth not less than Rs. 2 crore
3. Sound financial condition and management character
4. Directors and key personnel must have reputation for fairness and integrity
5. Platform must be independently certified for data protection standards
6. Board may inquire and register, or reject with reasons
7. Board may suspend/cancel registration for non-adherence

### Obligations (First Schedule Part B — 13 obligations)

1. Enable Data Principals to give consent directly or through another DF on the platform
2. Ensure personal data content is not readable by the Consent Manager
3. Maintain records of: consents given/denied/withdrawn, notices, data sharing
4. Give Data Principals access to records; provide in machine-readable form on request
5. Maintain records for at least 7 years (or longer if agreed/required by law)
6. Develop and maintain website/app as primary access means
7. No sub-contracting or assignment of obligations
8. Take reasonable security safeguards
9. Act in fiduciary capacity to Data Principals
10. Avoid conflict of interest with Data Fiduciaries
11. Publish promoter, director, key personnel info and >2% shareholders
12. Maintain effective audit mechanisms and report to Board
13. No transfer of control without Board approval

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

Additional obligations (Rule 13):
1. Annual DPIA + audit (every 12 months from SDF notification date)
2. Report significant observations to the Board (Rule 13(2))
3. Algorithmic risk assessment — verify technical measures including algorithmic software do not pose risk to DP rights (Rule 13(3))
4. Potential data localization — process specified personal data with restriction that data and traffic data not transferred outside India (Rule 13(4), on Central Government committee recommendation)
5. Appoint India-based DPO (Section 10 + Rule 9)

### What Coding Agents Can Do

- Implement comprehensive audit logging
- Build DPIA automation tooling
- Create compliance dashboards for DPO oversight
- Integrate with audit frameworks

---

## 9. Cross-Border Data Transfer Restrictions

**DPDPA Section 16**

### Framework (Rule 15)

Under Rule 15, personal data may be transferred outside India subject to requirements the Central Government may specify regarding making data available to foreign States, or persons/entities under their control. This is a more permissive framework than initially expected — transfers are allowed unless specifically restricted.

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

## 11. Data Retention Requirements

**DPDPA Section 7(e) | Rule 8 + Third Schedule**

### Mandatory Retention Periods (Third Schedule)

| Platform Type | Threshold | Retention Period |
|---------------|-----------|-----------------|
| E-commerce entity | ≥2 crore registered users in India | 3 years from last DP contact or Rules commencement, whichever is latest |
| Online gaming intermediary | ≥50 lakh registered users in India | 3 years from last DP contact or Rules commencement, whichever is latest |
| Social media intermediary | ≥2 crore registered users in India | 3 years from last DP contact or Rules commencement, whichever is latest |

**Exceptions:** Account access and virtual tokens (wallets, stored value) are exempt from the 3-year erasure requirement.

### Minimum Log Retention (Rule 6(e) + Rule 8(3))

All Data Fiduciaries must retain personal data, associated traffic data, and processing logs for a **minimum of 1 year** from the date of processing, for purposes specified in the Seventh Schedule.

### 48-Hour Pre-Erasure Notice (Rule 8(2))

At least **48 hours before** erasing personal data under retention rules, the Data Fiduciary must inform the Data Principal that their data will be erased upon completion of the period, unless they:
- Log into their user account, OR
- Otherwise initiate contact for the specified purpose, OR
- Exercise their rights under the Act

### What Coding Agents Can Do

- Implement retention period tracking with automatic erasure scheduling
- Build pre-erasure notification pipeline (48-hour advance warning)
- Configure log retention policies (minimum 1 year)
- Create dashboards showing data approaching retention limits

---

## 12. Grievance Redressal SLA

**DPDPA Section 13 | Rule 14(3)**

### The 90-Day Requirement

Every Data Fiduciary and Consent Manager must publish on its website/app a grievance redressal system that responds to Data Principal grievances within a **maximum of 90 days**. They must implement appropriate technical and organisational measures to ensure effectiveness within this period.

### Rights Exercise Mechanism (Rule 14(1-2))

Data Fiduciaries must prominently publish:
- The means for exercising Data Principal rights (Rule 14(1)(a))
- Required identifiers (username, customer ID, etc.) for verification (Rule 14(1)(b))

### Nomination Mechanism (Rule 14(4))

Data Principals may nominate one or more individuals to exercise their rights, in accordance with the DF's terms of service and applicable law.

### What Coding Agents Can Do

- Implement 90-day SLA tracking on all grievance submissions
- Build automated reminders/escalations as deadlines approach
- Create rights exercise portal with clear means and identifier requirements
- Implement nomination management system

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
