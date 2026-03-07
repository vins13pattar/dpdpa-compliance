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
