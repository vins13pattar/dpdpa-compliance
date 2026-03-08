# DPDPA Implementation Patterns

Production-ready code patterns for implementing DPDPA compliance across common frameworks.
Each pattern references the relevant DPDPA section and includes database schema, API, and
UI components.

---

## 1. Consent Management System

**DPDPA Sections 3, 4, 5**

### Database Schema (SQL — works with PostgreSQL, MySQL)

```sql
-- Consent purposes: each distinct reason you process data
CREATE TABLE consent_purposes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,        -- e.g., 'analytics', 'marketing_emails'
    title VARCHAR(255) NOT NULL,               -- Human-readable: "Usage Analytics"
    description TEXT NOT NULL,                 -- Plain language: what data, why
    data_collected TEXT NOT NULL,              -- Itemized list of data fields
    is_required BOOLEAN DEFAULT FALSE,         -- TRUE only for essential processing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual consent records (immutable audit log)
CREATE TABLE consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    purpose_id UUID NOT NULL REFERENCES consent_purposes(id),
    action VARCHAR(20) NOT NULL CHECK (action IN ('granted', 'withdrawn')),
    notice_version VARCHAR(50) NOT NULL,       -- Version of notice shown at consent time
    consent_method VARCHAR(50) NOT NULL,       -- 'checkbox_click', 'toggle', 'api'
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
    -- NOTE: This table is append-only. Never UPDATE or DELETE rows.
);

-- Current consent state (materialized for fast lookups)
CREATE TABLE user_consents (
    user_id UUID NOT NULL REFERENCES users(id),
    purpose_id UUID NOT NULL REFERENCES consent_purposes(id),
    is_granted BOOLEAN NOT NULL DEFAULT FALSE,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, purpose_id)
);

CREATE INDEX idx_user_consents_user ON user_consents(user_id);
CREATE INDEX idx_consent_records_user ON consent_records(user_id);
```

### Node.js / Express API

```javascript
// middleware/consentCheck.js
// DPDPA Section 3: Only process data with valid consent or legitimate use

const consentCheck = (purposeSlug) => async (req, res, next) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Authentication required' });

  const consent = await db.query(
    `SELECT is_granted FROM user_consents
     WHERE user_id = $1 AND purpose_id = (
       SELECT id FROM consent_purposes WHERE slug = $2
     )`,
    [userId, purposeSlug]
  );

  if (!consent.rows[0]?.is_granted) {
    return res.status(403).json({
      error: 'consent_required',
      purpose: purposeSlug,
      // DPDPA Section 5: Include notice with consent request
      message: 'Your consent is required for this feature. Please review and accept.',
      notice_url: `/api/consent/notice/${purposeSlug}`
    });
  }

  next();
};

// POST /api/consent/grant
// DPDPA Section 4: Record consent with full audit trail
router.post('/consent/grant', authenticate, async (req, res) => {
  const { purpose_slug, notice_version } = req.body;
  const userId = req.user.id;

  // Validate purpose exists
  const purpose = await db.query(
    'SELECT id FROM consent_purposes WHERE slug = $1', [purpose_slug]
  );
  if (!purpose.rows[0]) return res.status(404).json({ error: 'Unknown purpose' });

  const purposeId = purpose.rows[0].id;

  await db.transaction(async (tx) => {
    // Append to immutable audit log
    await tx.query(
      `INSERT INTO consent_records (user_id, purpose_id, action, notice_version, consent_method, ip_address, user_agent)
       VALUES ($1, $2, 'granted', $3, $4, $5, $6)`,
      [userId, purposeId, notice_version, 'explicit_action', req.ip, req.headers['user-agent']]
    );
    // Update current state
    await tx.query(
      `INSERT INTO user_consents (user_id, purpose_id, is_granted, last_updated)
       VALUES ($1, $2, TRUE, NOW())
       ON CONFLICT (user_id, purpose_id) DO UPDATE SET is_granted = TRUE, last_updated = NOW()`,
      [userId, purposeId]
    );
  });

  res.json({ status: 'consent_granted', purpose: purpose_slug });
});

// POST /api/consent/withdraw
// DPDPA Section 4.3: Withdrawal must be as easy as granting
router.post('/consent/withdraw', authenticate, async (req, res) => {
  const { purpose_slug } = req.body;
  const userId = req.user.id;

  const purpose = await db.query(
    'SELECT id FROM consent_purposes WHERE slug = $1', [purpose_slug]
  );
  if (!purpose.rows[0]) return res.status(404).json({ error: 'Unknown purpose' });

  const purposeId = purpose.rows[0].id;

  await db.transaction(async (tx) => {
    await tx.query(
      `INSERT INTO consent_records (user_id, purpose_id, action, notice_version, consent_method, ip_address, user_agent)
       VALUES ($1, $2, 'withdrawn', 'N/A', 'explicit_action', $3, $4)`,
      [userId, purposeId, req.ip, req.headers['user-agent']]
    );
    await tx.query(
      `UPDATE user_consents SET is_granted = FALSE, last_updated = NOW()
       WHERE user_id = $1 AND purpose_id = $2`,
      [userId, purposeId]
    );
  });

  // DPDPA Section 4.4: Inform about consequences of withdrawal
  res.json({
    status: 'consent_withdrawn',
    purpose: purpose_slug,
    consequences: 'Features dependent on this consent will be disabled.'
  });
});
```

### React Consent Component

```jsx
// components/ConsentBanner.jsx
// DPDPA Section 4 & 5: Informed, specific, affirmative consent with notice

import { useState, useEffect } from 'react';

export function ConsentBanner({ onComplete }) {
  const [purposes, setPurposes] = useState([]);
  const [consents, setConsents] = useState({});

  useEffect(() => {
    fetch('/api/consent/purposes').then(r => r.json()).then(setPurposes);
  }, []);

  const handleToggle = (slug) => {
    setConsents(prev => ({ ...prev, [slug]: !prev[slug] }));
  };

  const handleSubmit = async () => {
    for (const [slug, granted] of Object.entries(consents)) {
      if (granted) {
        await fetch('/api/consent/grant', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ purpose_slug: slug, notice_version: 'v1.0' })
        });
      }
    }
    onComplete();
  };

  return (
    <div role="dialog" aria-label="Data Processing Consent">
      <h2>How We Use Your Data</h2>
      <p>
        Under India's Digital Personal Data Protection Act, 2023, we need your
        explicit consent before processing your personal data. Please review
        each purpose below.
      </p>

      {purposes.map(p => (
        <div key={p.slug}>
          <label>
            {/* DPDPA Section 4.1: Unchecked by default — affirmative action required */}
            <input
              type="checkbox"
              checked={consents[p.slug] || false}
              onChange={() => handleToggle(p.slug)}
              disabled={p.is_required}
            />
            <strong>{p.title}</strong>
            {p.is_required && <span> (Required for core service)</span>}
          </label>
          {/* DPDPA Section 4.2a: Itemized description in clear language */}
          <p>{p.description}</p>
          <details>
            <summary>Data collected</summary>
            <p>{p.data_collected}</p>
          </details>
        </div>
      ))}

      {/* DPDPA Section 4.2b: Inform about withdrawal */}
      <p>
        You can withdraw consent at any time from Settings → Privacy.
        Withdrawing consent may limit some features.
      </p>

      {/* Link to grievance mechanism — DPDPA Section 5.1c */}
      <p>
        To file a grievance about data processing, visit our{' '}
        <a href="/grievance">Grievance Portal</a> or contact our Data
        Protection Officer at <a href="mailto:dpo@example.com">dpo@example.com</a>.
      </p>

      <button onClick={handleSubmit}>Save My Preferences</button>
    </div>
  );
}
```

---

## 2. Data Principal Rights Implementation

**DPDPA Sections 11-14**

### Right to Access (Section 11) — Data Export API

```javascript
// GET /api/my-data
// DPDPA Section 11: Provide summary of all personal data and recipients
router.get('/my-data', authenticate, async (req, res) => {
  const userId = req.user.id;

  const [profile, consents, dataSharing, processingLog] = await Promise.all([
    db.query('SELECT * FROM users WHERE id = $1', [userId]),
    db.query(
      `SELECT cp.title, cp.description, uc.is_granted, uc.last_updated
       FROM user_consents uc
       JOIN consent_purposes cp ON cp.id = uc.purpose_id
       WHERE uc.user_id = $1`, [userId]
    ),
    db.query(
      `SELECT recipient_name, recipient_type, data_shared, purpose, shared_at
       FROM data_sharing_log WHERE user_id = $1 ORDER BY shared_at DESC`, [userId]
    ),
    db.query(
      `SELECT activity_type, description, performed_at
       FROM processing_activities WHERE user_id = $1 ORDER BY performed_at DESC LIMIT 100`, [userId]
    )
  ]);

  res.json({
    // Section 11.1(a)(i): Confirmation of processing
    processing_confirmed: true,
    // Section 11.1(a)(ii): Summary of personal data
    personal_data: {
      profile: sanitizeForExport(profile.rows[0]),
      consent_status: consents.rows
    },
    // Section 11.1(a)(iii): Identities of recipients
    data_sharing: dataSharing.rows,
    // Additional: processing activity log
    recent_processing: processingLog.rows,
    exported_at: new Date().toISOString()
  });
});
```

### Right to Erasure (Section 12) — Account Deletion

```javascript
// POST /api/my-data/delete
// DPDPA Section 12.1d: Right to erasure
router.post('/my-data/delete', authenticate, async (req, res) => {
  const userId = req.user.id;
  const { confirmation } = req.body; // Require explicit confirmation

  if (confirmation !== 'DELETE_MY_ACCOUNT') {
    return res.status(400).json({
      error: 'Please confirm by sending confirmation: "DELETE_MY_ACCOUNT"'
    });
  }

  // Check for legal retention obligations
  const retentionHolds = await db.query(
    `SELECT reason, retain_until FROM legal_retention_holds
     WHERE user_id = $1 AND retain_until > NOW()`, [userId]
  );

  if (retentionHolds.rows.length > 0) {
    // DPDPA Section 12: "unless necessary for a lawful purpose"
    return res.json({
      status: 'partial_erasure',
      message: 'Some data must be retained for legal obligations.',
      retained_data: retentionHolds.rows.map(r => ({
        reason: r.reason,
        retain_until: r.retain_until
      })),
      erased: 'All non-retained personal data will be erased within 30 days.'
    });
  }

  // Queue full deletion (async — may take time for backups)
  await db.query(
    `INSERT INTO deletion_requests (user_id, requested_at, status)
     VALUES ($1, NOW(), 'pending')`, [userId]
  );

  // Immediately anonymize active data
  await db.query(
    `UPDATE users SET
       email = 'deleted_' || id || '@deleted.local',
       name = 'Deleted User',
       phone = NULL,
       address = NULL,
       is_deleted = TRUE,
       deleted_at = NOW()
     WHERE id = $1`, [userId]
  );

  // Revoke all sessions
  await db.query('DELETE FROM sessions WHERE user_id = $1', [userId]);

  res.json({
    status: 'erasure_initiated',
    message: 'Your account has been deactivated and data erasure is in progress.',
    completion_estimate: '30 days for full erasure including backups.'
  });
});
```

### Grievance Redressal (Section 13)

```javascript
// POST /api/grievance
// DPDPA Section 13: Readily available grievance mechanism
router.post('/grievance', authenticate, async (req, res) => {
  const { category, description, related_data } = req.body;

  const grievance = await db.query(
    `INSERT INTO grievances (user_id, category, description, related_data, status, created_at)
     VALUES ($1, $2, $3, $4, 'open', NOW())
     RETURNING id, created_at`,
    [req.user.id, category, description, related_data]
  );

  // DPDPA Section 13.2: Respond within prescribed period
  // (Period to be set by rules — default to 30 days as best practice)
  const responseDeadline = new Date();
  responseDeadline.setDate(responseDeadline.getDate() + 30);

  // Notify DPO
  await notifyDPO({
    grievanceId: grievance.rows[0].id,
    userId: req.user.id,
    category,
    deadline: responseDeadline
  });

  res.json({
    grievance_id: grievance.rows[0].id,
    status: 'open',
    response_deadline: responseDeadline.toISOString(),
    // DPDPA Section 13.3: Inform about Board complaint option
    escalation_note: 'If you are not satisfied with our response or do not receive one within the deadline, you may file a complaint with the Data Protection Board of India.'
  });
});
```

---

## 3. Breach Notification System

**DPDPA Section 7d**

```javascript
// services/breachNotification.js
// DPDPA Section 7d: Notify Board AND each affected Data Principal

class BreachNotificationService {
  async reportBreach({ description, affectedUserIds, severity, discoveredAt }) {
    // 1. Log the breach
    const breach = await db.query(
      `INSERT INTO data_breaches (description, severity, discovered_at, affected_count, status)
       VALUES ($1, $2, $3, $4, 'detected')
       RETURNING id`,
      [description, severity, discoveredAt, affectedUserIds.length]
    );
    const breachId = breach.rows[0].id;

    // 2. Notify the Data Protection Board of India
    // DPDPA Section 7d: "inform the Board"
    await this.notifyBoard(breachId, {
      description,
      severity,
      discovered_at: discoveredAt,
      affected_count: affectedUserIds.length,
      initial_response: 'Investigation initiated. Containment measures applied.',
      data_fiduciary: {
        name: process.env.COMPANY_NAME,
        dpo_contact: process.env.DPO_EMAIL
      }
    });

    // 3. Notify each affected Data Principal
    // DPDPA Section 7d: "each affected Data Principal"
    for (const userId of affectedUserIds) {
      await this.notifyUser(userId, breachId, {
        description: this.userFriendlyDescription(description),
        what_happened: description,
        data_affected: 'We are investigating the exact scope.',
        what_we_are_doing: 'We have contained the breach and are investigating.',
        what_you_can_do: 'We recommend changing your password and monitoring your account.',
        contact: process.env.DPO_EMAIL
      });
    }

    // 4. Update breach status
    await db.query(
      `UPDATE data_breaches SET status = 'notified', notified_at = NOW()
       WHERE id = $1`, [breachId]
    );

    return breachId;
  }

  async notifyBoard(breachId, details) {
    // NOTE: The prescribed form for Board notification will be specified in
    // DPDPA rules. This is a placeholder — update when rules are published.
    console.error('[DPDPA BREACH] Board notification — update endpoint when rules are published');
    await db.query(
      `INSERT INTO breach_notifications (breach_id, recipient_type, details, sent_at)
       VALUES ($1, 'board', $2, NOW())`,
      [breachId, JSON.stringify(details)]
    );
  }

  async notifyUser(userId, breachId, details) {
    const user = await db.query('SELECT email, name FROM users WHERE id = $1', [userId]);
    if (!user.rows[0]) return;

    await emailService.send({
      to: user.rows[0].email,
      subject: 'Important: Data Security Incident Notification',
      template: 'breach_notification',
      data: { name: user.rows[0].name, ...details }
    });

    await db.query(
      `INSERT INTO breach_notifications (breach_id, recipient_type, user_id, sent_at)
       VALUES ($1, 'data_principal', $2, NOW())`,
      [breachId, userId]
    );
  }

  userFriendlyDescription(technical) {
    // Convert technical breach description to plain language
    return `A security incident was detected that may have affected your personal data. ${technical}`;
  }
}

module.exports = new BreachNotificationService();
```

---

## 4. Children's Data Protection

**DPDPA Section 8**

```javascript
// middleware/childProtection.js
// DPDPA Section 8: Special protections for children (under 18)

const CHILD_AGE_THRESHOLD = 18;

// Age verification gate
const verifyAge = async (req, res, next) => {
  const { date_of_birth } = req.body;
  if (!date_of_birth) {
    return res.status(400).json({ error: 'Date of birth is required for registration' });
  }

  const age = calculateAge(new Date(date_of_birth));
  req.isChild = age < CHILD_AGE_THRESHOLD;

  if (req.isChild) {
    // DPDPA Section 8.1: Require verifiable parental consent
    const { guardian_consent_token } = req.body;
    if (!guardian_consent_token) {
      return res.status(403).json({
        error: 'parental_consent_required',
        message: 'As you are under 18, we need your parent or guardian\'s consent.',
        consent_flow_url: '/guardian-consent'
      });
    }

    const isValid = await verifyGuardianConsent(guardian_consent_token);
    if (!isValid) {
      return res.status(403).json({ error: 'Invalid or expired guardian consent' });
    }
  }

  next();
};

// Block tracking for children
// DPDPA Section 8.2b: No tracking, behavioural monitoring, or targeted ads
const blockChildTracking = (req, res, next) => {
  if (req.user?.is_child) {
    // Disable analytics tracking
    res.setHeader('X-Disable-Analytics', 'true');
    // Disable ad personalization
    res.setHeader('X-Disable-Ad-Targeting', 'true');
    // Set flag for frontend to respect
    req.trackingAllowed = false;
  } else {
    req.trackingAllowed = true;
  }
  next();
};

function calculateAge(dob) {
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const monthDiff = today.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) {
    age--;
  }
  return age;
}
```

---

## 5. Data Retention and Auto-Deletion

**DPDPA Section 7e**

```javascript
// jobs/dataRetention.js
// DPDPA Section 7e: Erase data when no longer needed

const RETENTION_POLICIES = {
  // Define per data type — adjust to your legal requirements
  user_activity_logs: { days: 365, reason: 'Service improvement' },
  support_tickets: { days: 730, reason: 'Legal compliance' },
  analytics_events: { days: 180, reason: 'Usage analytics' },
  inactive_accounts: { days: 1095, reason: 'Account maintenance' }, // 3 years
  consent_records: { days: null, reason: 'Legal audit trail — retain indefinitely' },
};

async function runRetentionCleanup() {
  for (const [dataType, policy] of Object.entries(RETENTION_POLICIES)) {
    if (policy.days === null) continue; // Skip indefinite retention

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - policy.days);

    const result = await db.query(
      `DELETE FROM ${dataType} WHERE created_at < $1 RETURNING id`,
      [cutoffDate]
    );

    console.log(`[Retention] Purged ${result.rowCount} records from ${dataType} (policy: ${policy.days} days)`);

    // Log the purge for audit
    await db.query(
      `INSERT INTO retention_audit_log (data_type, records_purged, cutoff_date, policy_reason, executed_at)
       VALUES ($1, $2, $3, $4, NOW())`,
      [dataType, result.rowCount, cutoffDate, policy.reason]
    );
  }
}

// Schedule: Run daily via cron
// crontab: 0 2 * * * node jobs/dataRetention.js
module.exports = { runRetentionCleanup };
```

---

## 6. Python / Django Patterns

### Consent Middleware (Django)

```python
# middleware/dpdpa_consent.py
# DPDPA Section 3: Check consent before processing

from django.http import JsonResponse
from consent.models import UserConsent

class DPDPAConsentMiddleware:
    """
    Middleware that checks if user has granted consent for the
    requested processing purpose. Attach purpose via view decorator.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        return self.get_response(request)

    def process_view(self, request, view_func, view_args, view_kwargs):
        required_purpose = getattr(view_func, 'dpdpa_consent_required', None)
        if not required_purpose:
            return None

        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)

        has_consent = UserConsent.objects.filter(
            user=request.user,
            purpose__slug=required_purpose,
            is_granted=True
        ).exists()

        if not has_consent:
            return JsonResponse({
                'error': 'consent_required',
                'purpose': required_purpose,
                'message': 'Your consent is required for this feature.'
            }, status=403)

        return None


def requires_consent(purpose_slug):
    """Decorator to mark views that require specific consent."""
    def decorator(view_func):
        view_func.dpdpa_consent_required = purpose_slug
        return view_func
    return decorator
```

### Usage in Django Views

```python
from middleware.dpdpa_consent import requires_consent

@requires_consent('analytics')
def analytics_dashboard(request):
    # Only reached if user has granted 'analytics' consent
    return render(request, 'dashboard.html')
```

---

## 7. Laravel Patterns

### Consent Middleware (Laravel)

```php
<?php
// app/Http/Middleware/DPDPAConsent.php
// DPDPA Section 3: Verify consent before processing

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Models\UserConsent;

class DPDPAConsent
{
    public function handle(Request $request, Closure $next, string $purposeSlug)
    {
        $user = $request->user();

        if (!$user) {
            return response()->json(['error' => 'Authentication required'], 401);
        }

        $hasConsent = UserConsent::where('user_id', $user->id)
            ->whereHas('purpose', fn($q) => $q->where('slug', $purposeSlug))
            ->where('is_granted', true)
            ->exists();

        if (!$hasConsent) {
            return response()->json([
                'error' => 'consent_required',
                'purpose' => $purposeSlug,
                'message' => 'Your consent is required for this feature.',
            ], 403);
        }

        return $next($request);
    }
}

// Usage in routes:
// Route::get('/analytics', [AnalyticsController::class, 'index'])
//     ->middleware('dpdpa.consent:analytics');
```

---

## 8. React Native / Expo Patterns

### Consent Screen (Expo)

```jsx
// screens/ConsentScreen.jsx
// DPDPA Sections 4, 5: Mobile consent flow

import { useState, useEffect } from 'react';
import { View, Text, Switch, ScrollView, Pressable, Linking } from 'react-native';

export default function ConsentScreen({ navigation }) {
  const [purposes, setPurposes] = useState([]);
  const [consents, setConsents] = useState({});

  useEffect(() => {
    fetch(`${API_URL}/consent/purposes`)
      .then(r => r.json())
      .then(data => {
        setPurposes(data);
        // DPDPA Section 4.1: All toggles OFF by default
        const defaults = {};
        data.forEach(p => { defaults[p.slug] = p.is_required; });
        setConsents(defaults);
      });
  }, []);

  const handleSave = async () => {
    for (const [slug, granted] of Object.entries(consents)) {
      if (granted) {
        await fetch(`${API_URL}/consent/grant`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ purpose_slug: slug, notice_version: 'v1.0' }),
        });
      }
    }
    navigation.navigate('Home');
  };

  return (
    <ScrollView style={{ padding: 16 }}>
      <Text style={{ fontSize: 22, fontWeight: 'bold' }}>Privacy Preferences</Text>
      <Text style={{ marginVertical: 8, color: '#555' }}>
        Under India's DPDPA 2023, we need your explicit consent. Review each purpose below.
      </Text>

      {purposes.map(p => (
        <View key={p.slug} style={{ marginVertical: 12 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Text style={{ fontWeight: '600', flex: 1 }}>{p.title}</Text>
            <Switch
              value={consents[p.slug] || false}
              onValueChange={v => setConsents(prev => ({ ...prev, [p.slug]: v }))}
              disabled={p.is_required}
            />
          </View>
          <Text style={{ color: '#666', marginTop: 4 }}>{p.description}</Text>
        </View>
      ))}

      <Text style={{ color: '#888', marginTop: 16 }}>
        You can change these preferences anytime in Settings → Privacy.
      </Text>

      <Pressable onPress={() => Linking.openURL(`${APP_URL}/grievance`)}>
        <Text style={{ color: '#007AFF', marginTop: 8 }}>File a grievance</Text>
      </Pressable>

      <Pressable
        onPress={handleSave}
        style={{ backgroundColor: '#007AFF', padding: 16, borderRadius: 8, marginTop: 24 }}
      >
        <Text style={{ color: '#fff', textAlign: 'center', fontWeight: '600' }}>
          Save Preferences
        </Text>
      </Pressable>
    </ScrollView>
  );
}
```

---

## Framework-Agnostic Reminders

Regardless of framework, always ensure:

1. **Consent is not pre-selected** — every toggle/checkbox defaults to OFF
2. **Notice is shown before or at collection time** — not after
3. **Withdrawal is as easy as granting** — same number of clicks/taps
4. **All consent events are in an immutable audit log** — append-only table
5. **Data export includes all personal data** — not just profile fields
6. **Deletion is real** — not just a soft-delete flag (though immediate anonymization + scheduled hard delete is acceptable)
7. **Children's age gate exists** — and blocks tracking/ads for under-18s
8. **DPO contact is published** — visible in app footer, settings, or help section
9. **Grievance mechanism is reachable** — within 2-3 taps from any screen

---

## Pattern 7: 72-Hour Board Breach Notification (Rule 7)

**DPDP Rules 2025 — Rule 7(1), 7(2)**

### Database Schema

```sql
-- Breach incident tracking for Board notification
CREATE TABLE breach_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    breach_detected_at TIMESTAMPTZ NOT NULL,
    board_initial_notified_at TIMESTAMPTZ,         -- Rule 7(2)(a): without delay
    board_detailed_report_at TIMESTAMPTZ,           -- Rule 7(2)(b): within 72 hours
    board_deadline TIMESTAMPTZ NOT NULL,            -- breach_detected_at + 72 hours
    nature TEXT NOT NULL,
    extent TEXT,
    timing_of_occurrence TIMESTAMPTZ,
    location_of_occurrence TEXT,
    likely_impact TEXT,
    events_and_circumstances TEXT,                  -- Rule 7(2)(b)(ii)
    mitigation_measures TEXT,                       -- Rule 7(2)(b)(iii)
    findings_regarding_person TEXT,                 -- Rule 7(2)(b)(iv)
    remedial_measures TEXT,                         -- Rule 7(2)(b)(v)
    dp_notification_report TEXT,                    -- Rule 7(2)(b)(vi)
    status VARCHAR(30) CHECK (status IN ('detected', 'initial_notified', 'detailed_submitted', 'closed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual DP notifications per Rule 7(1)
CREATE TABLE breach_dp_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    breach_id UUID NOT NULL REFERENCES breach_reports(id),
    user_id UUID NOT NULL REFERENCES users(id),
    notification_channel VARCHAR(50) NOT NULL,      -- 'user_account', 'email', 'sms'
    breach_description TEXT NOT NULL,               -- Rule 7(1)(a)
    consequences TEXT NOT NULL,                     -- Rule 7(1)(b)
    mitigation_measures TEXT,                       -- Rule 7(1)(c)
    safety_measures TEXT,                           -- Rule 7(1)(d)
    contact_info TEXT NOT NULL,                     -- Rule 7(1)(e)
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Node.js/Express — Breach Notification Service

```javascript
// services/breachNotification.js
// DPDP Rules 2025 — Rule 7: Breach notification to Board and Data Principals

const BOARD_DEADLINE_HOURS = 72;

class BreachNotificationService {
  constructor(db, notificationService, boardApiClient) {
    this.db = db;
    this.notifier = notificationService;
    this.boardApi = boardApiClient;
  }

  async reportBreach({ nature, extent, timing, location, likelyImpact, affectedUserIds }) {
    const detectedAt = new Date();
    const deadline = new Date(detectedAt.getTime() + BOARD_DEADLINE_HOURS * 60 * 60 * 1000);

    // Create breach record
    const breach = await this.db.query(
      `INSERT INTO breach_reports (breach_detected_at, board_deadline, nature, extent,
       timing_of_occurrence, location_of_occurrence, likely_impact, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'detected') RETURNING *`,
      [detectedAt, deadline, nature, extent, timing, location, likelyImpact]
    );

    // Rule 7(2)(a): Notify Board without delay — initial description
    await this.notifyBoardInitial(breach.rows[0]);

    // Rule 7(1): Notify affected Data Principals without delay
    await this.notifyDataPrincipals(breach.rows[0], affectedUserIds);

    // Schedule 72-hour detailed report deadline reminder
    await this.scheduleDetailedReport(breach.rows[0].id, deadline);

    return breach.rows[0];
  }

  async notifyBoardInitial(breach) {
    // Rule 7(2)(a): without delay — description, nature, extent, timing, location, likely impact
    await this.boardApi.submitInitialNotification({
      breachId: breach.id,
      description: breach.nature,
      extent: breach.extent,
      timing: breach.timing_of_occurrence,
      location: breach.location_of_occurrence,
      likelyImpact: breach.likely_impact,
    });

    await this.db.query(
      `UPDATE breach_reports SET board_initial_notified_at = NOW(), status = 'initial_notified'
       WHERE id = $1`, [breach.id]
    );
  }

  async notifyDataPrincipals(breach, userIds) {
    // Rule 7(1): notify each affected DP via user account or registered communication
    for (const userId of userIds) {
      const notification = {
        breach_description: `${breach.nature}. Extent: ${breach.extent}. Occurred: ${breach.timing_of_occurrence}`,
        consequences: breach.likely_impact,
        mitigation_measures: 'Our security team is actively investigating and implementing safeguards.',
        safety_measures: 'We recommend changing your password and monitoring your account for unusual activity.',
        contact_info: process.env.DPO_CONTACT_INFO,
      };

      await this.db.query(
        `INSERT INTO breach_dp_notifications
         (breach_id, user_id, notification_channel, breach_description, consequences,
          mitigation_measures, safety_measures, contact_info, sent_at)
         VALUES ($1, $2, 'user_account', $3, $4, $5, $6, $7, NOW())`,
        [breach.id, userId, notification.breach_description, notification.consequences,
         notification.mitigation_measures, notification.safety_measures, notification.contact_info]
      );

      await this.notifier.sendToUser(userId, {
        type: 'breach_notification',
        ...notification,
      });
    }
  }

  async submitDetailedReport(breachId, details) {
    // Rule 7(2)(b): within 72 hours — detailed report with 6 sub-items
    const breach = await this.db.query('SELECT * FROM breach_reports WHERE id = $1', [breachId]);
    if (new Date() > new Date(breach.rows[0].board_deadline)) {
      console.error(`WARNING: 72-hour deadline exceeded for breach ${breachId}`);
    }

    await this.boardApi.submitDetailedReport({
      breachId,
      updatedDescription: details.updatedDescription,       // (i)
      eventsAndCircumstances: details.eventsAndCircumstances, // (ii)
      mitigationMeasures: details.mitigationMeasures,       // (iii)
      findingsRegardingPerson: details.findingsRegardingPerson, // (iv)
      remedialMeasures: details.remedialMeasures,           // (v)
      dpNotificationReport: details.dpNotificationReport,   // (vi)
    });

    await this.db.query(
      `UPDATE breach_reports SET board_detailed_report_at = NOW(), status = 'detailed_submitted',
       events_and_circumstances = $2, mitigation_measures = $3, findings_regarding_person = $4,
       remedial_measures = $5, dp_notification_report = $6 WHERE id = $1`,
      [breachId, details.eventsAndCircumstances, details.mitigationMeasures,
       details.findingsRegardingPerson, details.remedialMeasures, details.dpNotificationReport]
    );
  }
}

module.exports = { BreachNotificationService };
```

---

## Pattern 8: 48-Hour Pre-Erasure Notification (Rule 8)

**DPDP Rules 2025 — Rule 8(1), 8(2), 8(3) + Third Schedule**

### Database Schema

```sql
-- Data retention tracking for Third Schedule compliance
CREATE TABLE data_retention_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    platform_type VARCHAR(50) NOT NULL CHECK (platform_type IN ('e_commerce', 'online_gaming', 'social_media', 'other')),
    last_contact_at TIMESTAMPTZ NOT NULL,           -- last DP approach/rights exercise
    retention_period_years INTEGER NOT NULL DEFAULT 3,
    erasure_due_at TIMESTAMPTZ NOT NULL,            -- last_contact_at + retention_period
    pre_erasure_notified_at TIMESTAMPTZ,            -- Rule 8(2): 48h before erasure
    erasure_completed_at TIMESTAMPTZ,
    status VARCHAR(30) CHECK (status IN ('active', 'approaching_erasure', 'notified', 'erasure_deferred', 'erased')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Node.js — Retention and Pre-Erasure Service

```javascript
// services/dataRetention.js
// DPDP Rules 2025 — Rule 8: Retention periods and pre-erasure notification

const RETENTION_YEARS = {
  e_commerce: 3,     // Third Schedule: ≥2Cr users
  online_gaming: 3,  // Third Schedule: ≥50L users
  social_media: 3,   // Third Schedule: ≥2Cr users
  other: 1,          // Rule 8(3): minimum 1-year log retention
};

const PRE_ERASURE_NOTICE_HOURS = 48; // Rule 8(2)

class DataRetentionService {
  constructor(db, notifier) {
    this.db = db;
    this.notifier = notifier;
  }

  // Run daily via cron job
  async processRetentionSchedule() {
    const now = new Date();
    const noticeThreshold = new Date(now.getTime() + PRE_ERASURE_NOTICE_HOURS * 60 * 60 * 1000);

    // Find records approaching erasure (within 48 hours) that haven't been notified
    const approaching = await this.db.query(
      `SELECT * FROM data_retention_tracking
       WHERE status = 'active' AND erasure_due_at <= $1 AND pre_erasure_notified_at IS NULL`,
      [noticeThreshold]
    );

    // Rule 8(2): Send 48-hour pre-erasure notice
    for (const record of approaching.rows) {
      await this.notifier.sendToUser(record.user_id, {
        type: 'pre_erasure_notice',
        message: 'Your personal data will be erased in 48 hours unless you log in or contact us.',
        erasure_date: record.erasure_due_at,
        actions: [
          'Log into your account to retain your data',
          'Contact us for any data-related requests',
          'Exercise your rights under DPDPA',
        ],
      });

      await this.db.query(
        `UPDATE data_retention_tracking SET pre_erasure_notified_at = NOW(), status = 'notified'
         WHERE id = $1`, [record.id]
      );
    }

    // Process actual erasures for records past their due date where notice was sent
    const dueForErasure = await this.db.query(
      `SELECT * FROM data_retention_tracking
       WHERE status = 'notified' AND erasure_due_at <= $1`, [now]
    );

    for (const record of dueForErasure.rows) {
      await this.eraseUserData(record.user_id);
      await this.db.query(
        `UPDATE data_retention_tracking SET erasure_completed_at = NOW(), status = 'erased'
         WHERE id = $1`, [record.id]
      );
    }
  }

  // When user logs in or contacts, reset the retention clock
  async recordUserContact(userId) {
    const now = new Date();
    await this.db.query(
      `UPDATE data_retention_tracking
       SET last_contact_at = $1,
           erasure_due_at = $1 + (retention_period_years || ' years')::interval,
           status = 'active', pre_erasure_notified_at = NULL
       WHERE user_id = $2 AND status IN ('active', 'approaching_erasure', 'notified')`,
      [now, userId]
    );
  }
}

module.exports = { DataRetentionService };
```

---

## Pattern 9: Verifiable Parental Consent (Rule 10)

**DPDP Rules 2025 — Rule 10 + Illustrations**

### Node.js/Express — Parental Consent Verification

```javascript
// middleware/parentalConsent.js
// DPDP Rules 2025 — Rule 10: Verifiable consent for child's data

const CONSENT_CASES = {
  CASE_1: 'registered_parent',     // Parent is registered user, has identity on file
  CASE_2: 'unregistered_parent',   // Parent not registered, verify via govt/Digital Locker
  CASE_3: 'parent_opening_registered',  // Parent opening account for child, already registered
  CASE_4: 'parent_opening_unregistered', // Parent opening account for child, not registered
};

class ParentalConsentService {
  constructor(db, identityVerifier, digitalLockerClient) {
    this.db = db;
    this.verifier = identityVerifier;
    this.digitalLocker = digitalLockerClient;
  }

  async verifyParentalConsent(childData, parentData) {
    // Rule 10(1): Verify parent is an identifiable adult (≥18 years)
    const consentCase = this.determineCase(parentData);

    switch (consentCase) {
      case CONSENT_CASES.CASE_1:
        // Parent is registered user — check reliable identity and age on file
        return await this.verifyRegisteredParent(parentData.userId);

      case CONSENT_CASES.CASE_2:
        // Parent not registered — verify via authorised entity or Digital Locker
        return await this.verifyUnregisteredParent(parentData);

      case CONSENT_CASES.CASE_3:
        // Parent opening for child, already registered
        return await this.verifyRegisteredParent(parentData.userId);

      case CONSENT_CASES.CASE_4:
        // Parent opening for child, not registered — verify via govt/Digital Locker
        return await this.verifyUnregisteredParent(parentData);
    }
  }

  async verifyRegisteredParent(parentUserId) {
    // Rule 10(1)(a): reliable details of identity and age available with DF
    const parent = await this.db.query(
      'SELECT id, date_of_birth, identity_verified FROM users WHERE id = $1',
      [parentUserId]
    );

    if (!parent.rows[0]) throw new Error('Parent user not found');

    const age = this.calculateAge(parent.rows[0].date_of_birth);
    if (age < 18) throw new Error('Parent must be an adult (18+)');
    if (!parent.rows[0].identity_verified) throw new Error('Parent identity not verified');

    return { verified: true, method: 'registered_user_identity', parentUserId };
  }

  async verifyUnregisteredParent(parentData) {
    // Rule 10(1)(b): identity via authorised entity or virtual token (Digital Locker)
    if (parentData.digitalLockerId) {
      // Verify via Digital Locker service provider
      const result = await this.digitalLocker.verifyIdentity(parentData.digitalLockerId);
      if (!result.isAdult) throw new Error('Parent must be an adult (18+)');
      return { verified: true, method: 'digital_locker', verificationId: result.id };
    }

    // Verify via government-authorised entity
    const result = await this.verifier.verifyViaAuthorisedEntity({
      name: parentData.name,
      identityDocument: parentData.identityDocument,
    });

    if (!result.isAdult) throw new Error('Parent must be an adult (18+)');
    return { verified: true, method: 'authorised_entity', verificationId: result.id };
  }

  calculateAge(dateOfBirth) {
    const today = new Date();
    const birth = new Date(dateOfBirth);
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) age--;
    return age;
  }
}

module.exports = { ParentalConsentService, CONSENT_CASES };
```

### React — Age Gate with Parental Consent Flow

```jsx
// components/AgeGateWithConsent.jsx
// DPDP Rules 2025 — Rule 10: Verifiable parental consent UI

import { useState } from 'react';

function AgeGateWithConsent({ onVerified, onParentalConsentRequired }) {
  const [step, setStep] = useState('age_check'); // age_check | parent_identify | verify

  const handleAgeSubmit = (dateOfBirth) => {
    const age = calculateAge(dateOfBirth);
    if (age >= 18) {
      onVerified({ isChild: false });
    } else {
      // Child detected — require parental consent per Rule 10
      setStep('parent_identify');
    }
  };

  return (
    <div className="age-gate">
      {step === 'age_check' && (
        <AgeCheckForm onSubmit={handleAgeSubmit} />
      )}
      {step === 'parent_identify' && (
        <ParentIdentificationForm
          onRegisteredParent={(parentUserId) => {
            // Case 1 or 3: Parent is registered user
            onParentalConsentRequired({ case: 'registered', parentUserId });
          }}
          onUnregisteredParent={() => {
            // Case 2 or 4: Parent needs verification via Digital Locker or govt entity
            setStep('verify');
          }}
        />
      )}
      {step === 'verify' && (
        <DigitalLockerVerification
          onVerified={(verificationResult) => {
            onParentalConsentRequired({ case: 'unregistered', verification: verificationResult });
          }}
        />
      )}
    </div>
  );
}

export default AgeGateWithConsent;
```

---

## Pattern 10: 90-Day Grievance SLA Tracking (Rule 14)

**DPDP Rules 2025 — Rule 14(1), 14(3)**

### Database Schema

```sql
-- Grievance tracking with 90-day SLA per Rule 14(3)
CREATE TABLE grievances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    identifier VARCHAR(255) NOT NULL,               -- Rule 14(1)(b): username, customer ID, etc.
    type VARCHAR(50) NOT NULL CHECK (type IN ('access', 'correction', 'erasure', 'grievance', 'nomination', 'other')),
    description TEXT NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deadline_at TIMESTAMPTZ NOT NULL,               -- received_at + 90 days (Rule 14(3))
    responded_at TIMESTAMPTZ,
    response TEXT,
    status VARCHAR(30) CHECK (status IN ('received', 'in_progress', 'responded', 'overdue', 'closed')),
    days_remaining INTEGER GENERATED ALWAYS AS (
        GREATEST(0, EXTRACT(DAY FROM deadline_at - CURRENT_TIMESTAMP)::INTEGER)
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-set deadline to 90 days from receipt
CREATE OR REPLACE FUNCTION set_grievance_deadline()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deadline_at := NEW.received_at + INTERVAL '90 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grievance_deadline
    BEFORE INSERT ON grievances
    FOR EACH ROW EXECUTE FUNCTION set_grievance_deadline();
```

### Node.js/Express — Grievance API with SLA Enforcement

```javascript
// routes/grievances.js
// DPDP Rules 2025 — Rule 14(3): 90-day grievance response SLA

const express = require('express');
const router = express.Router();

const GRIEVANCE_SLA_DAYS = 90;

// Rule 14(1): Published means for exercising rights
router.get('/rights/means', (req, res) => {
  res.json({
    grievance_submission: '/api/grievances',
    data_access_request: '/api/rights/access',
    data_correction_request: '/api/rights/correction',
    data_erasure_request: '/api/rights/erasure',
    nomination: '/api/rights/nomination',
    required_identifiers: ['username', 'email', 'customer_id'], // Rule 14(1)(b)
    response_sla_days: GRIEVANCE_SLA_DAYS,
    dpo_contact: process.env.DPO_CONTACT_INFO,
  });
});

// Submit a grievance
router.post('/grievances', authMiddleware, async (req, res) => {
  const { type, description, identifier } = req.body;
  const userId = req.user.id;

  const result = await db.query(
    `INSERT INTO grievances (user_id, identifier, type, description, status)
     VALUES ($1, $2, $3, $4, 'received') RETURNING *`,
    [userId, identifier || req.user.username, type, description]
  );

  const grievance = result.rows[0];

  // Acknowledge receipt with deadline info
  res.status(201).json({
    grievance_id: grievance.id,
    status: 'received',
    received_at: grievance.received_at,
    deadline: grievance.deadline_at,
    message: `Your ${type} request has been received. We will respond within 90 days as required under DPDPA Rule 14(3).`,
  });
});

// Check overdue grievances (run via cron daily)
router.post('/grievances/check-sla', adminAuthMiddleware, async (req, res) => {
  const overdue = await db.query(
    `UPDATE grievances SET status = 'overdue'
     WHERE status IN ('received', 'in_progress') AND deadline_at < NOW()
     RETURNING *`
  );

  if (overdue.rows.length > 0) {
    // Alert DPO about overdue grievances — compliance risk
    await notifyDPO({
      type: 'overdue_grievances',
      count: overdue.rows.length,
      message: `${overdue.rows.length} grievance(s) have exceeded the 90-day SLA under Rule 14(3).`,
    });
  }

  res.json({ overdue_count: overdue.rows.length });
});

module.exports = router;
```

---

## Pattern 11: DPO Contact Publication (Rule 9)

**DPDP Rules 2025 — Rule 9**

### React — DPO Contact Component

```jsx
// components/DPOContact.jsx
// DPDP Rules 2025 — Rule 9: Prominently publish DPO/contact person info

function DPOContact() {
  const dpoInfo = {
    name: process.env.REACT_APP_DPO_NAME || 'Data Protection Officer',
    email: process.env.REACT_APP_DPO_EMAIL,
    phone: process.env.REACT_APP_DPO_PHONE,
    address: process.env.REACT_APP_DPO_ADDRESS,
  };

  return (
    // Rule 9: "prominently publish on its website or app"
    <section id="dpo-contact" aria-label="Data Protection Contact">
      <h3>Data Protection Officer</h3>
      <p>
        For questions about how we process your personal data, or to exercise
        your rights under the Digital Personal Data Protection Act, 2023:
      </p>
      <address>
        <p><strong>{dpoInfo.name}</strong></p>
        {dpoInfo.email && <p>Email: <a href={`mailto:${dpoInfo.email}`}>{dpoInfo.email}</a></p>}
        {dpoInfo.phone && <p>Phone: {dpoInfo.phone}</p>}
        {dpoInfo.address && <p>Address: {dpoInfo.address}</p>}
      </address>
      <p>
        <a href="/rights">Exercise your data rights</a> |{' '}
        <a href="/grievance">File a grievance</a> |{' '}
        <a href="https://dpboard.gov.in" target="_blank" rel="noopener noreferrer">
          Complain to Data Protection Board
        </a>
      </p>
    </section>
  );
}

export default DPOContact;
```

### Node.js — Include DPO Info in Rights Responses

```javascript
// middleware/dpoContact.js
// DPDP Rules 2025 — Rule 9: Include contact info in every rights response

const DPO_INFO = {
  name: process.env.DPO_NAME,
  email: process.env.DPO_EMAIL,
  phone: process.env.DPO_PHONE,
};

// Rule 9: "mention in every response to a communication for the exercise of
// the rights of a Data Principal under the Act"
function attachDPOContact(req, res, next) {
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    if (req.path.startsWith('/api/rights') || req.path.startsWith('/api/grievances')) {
      body.data_protection_contact = DPO_INFO;
    }
    return originalJson(body);
  };
  next();
}

module.exports = { attachDPOContact };
```

---

## Pattern 12: 1-Year Log Retention (Rule 6(e) + Rule 8(3))

**DPDP Rules 2025 — Rule 6(e), Rule 8(3)**

### Node.js — Access Logging with 1-Year Retention

```javascript
// middleware/dataAccessLogger.js
// DPDP Rules 2025 — Rule 6(e): Retain logs for minimum 1 year

const LOG_RETENTION_DAYS = 365; // Rule 6(e): minimum 1 year

// Log every access to personal data
async function logDataAccess(req, res, next) {
  const startTime = Date.now();

  res.on('finish', async () => {
    // Only log endpoints that serve personal data
    if (!isPersonalDataEndpoint(req.path)) return;

    await db.query(
      `INSERT INTO data_access_logs
       (user_id, accessor_id, accessor_role, endpoint, method, ip_address,
        user_agent, response_status, response_time_ms, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW() + INTERVAL '${LOG_RETENTION_DAYS} days')`,
      [
        extractDataSubjectId(req),
        req.user?.id || 'anonymous',
        req.user?.role || 'public',
        req.path,
        req.method,
        req.ip,
        req.get('User-Agent'),
        res.statusCode,
        Date.now() - startTime,
      ]
    );
  });

  next();
}

// Cleanup job — run daily, only delete logs older than 1 year
async function purgeExpiredLogs() {
  const result = await db.query(
    `DELETE FROM data_access_logs WHERE expires_at < NOW()`
  );
  console.log(`Purged ${result.rowCount} expired access logs (Rule 6(e) compliance)`);
}

module.exports = { logDataAccess, purgeExpiredLogs };
```

### Database Schema — Access Logs with Retention

```sql
-- Data access logs with 1-year minimum retention per Rule 6(e)
CREATE TABLE data_access_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID,                                    -- data subject whose data was accessed
    accessor_id VARCHAR(255) NOT NULL,               -- who accessed the data
    accessor_role VARCHAR(50),
    endpoint VARCHAR(500) NOT NULL,
    method VARCHAR(10) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    response_status INTEGER,
    response_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL                  -- Rule 6(e): minimum NOW() + 1 year
);

-- Index for efficient cleanup and querying
CREATE INDEX idx_access_logs_expires ON data_access_logs (expires_at);
CREATE INDEX idx_access_logs_user ON data_access_logs (user_id, created_at);

-- Traffic data logs per Rule 8(3)
CREATE TABLE traffic_data_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID,
    source_ip INET,
    destination_service VARCHAR(255),
    data_volume_bytes BIGINT,
    protocol VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL                  -- Rule 8(3): minimum 1 year
);
```
