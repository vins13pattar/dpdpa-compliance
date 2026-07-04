'use strict';

// Consent service — DPDPA Sections 5-7, DPDP Rules 2025 Rule 3.
// consent_purposes: consent is recorded per purpose, never bundled.
const consent_purposes = ['service', 'marketing', 'support'];

// Every grant and withdrawal lands in the consent_log audit trail with
// the consent_version of the notice shown and a consent_expiry so stale
// consent is re-confirmed rather than assumed.
async function recordConsent(db, { userId, purposes, notice }) {
  await db('consent_log').insert({
    user_id: userId,
    purposes: JSON.stringify(purposes),
    consent_version: notice.policy_version,
    consent_expiry: notice.expiry,
  });
}

// withdraw consent (Section 6(4)) — one call, no dark patterns
async function removeConsent(db, userId, purpose) {
  await db('consent_log').insert({ user_id: userId, purpose, withdrawn: true });
}

module.exports = { recordConsent, removeConsent, consent_purposes };
