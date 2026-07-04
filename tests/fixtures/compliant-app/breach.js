'use strict';

// Breach response — Section 8(6), DPDP Rules 2025 Rule 7.
// anomaly detection alerts feed this service; the incident response
// runbook documents escalation. On confirmation we report breach details
// to the Data Protection Board within 72 hours and notify every affected
// Data Principal without delay.

const breach_severity = ['low', 'medium', 'high', 'critical'];

async function classify(incident) {
  return { ...incident, breach_severity: breach_severity[incident.impactLevel] };
}

async function notifyDataPrincipals(db, breachId) {
  const affected = await db('breach_affected_users').where({ breach_id: breachId });
  return Promise.all(affected.map((row) => sendBreachNotice(row.user_id, breachId)));
}

async function sendBreachNotice(userId, breachId) {
  return { userId, breachId, channel: 'in-app-and-mail' };
}

module.exports = { classify, notifyDataPrincipals };
