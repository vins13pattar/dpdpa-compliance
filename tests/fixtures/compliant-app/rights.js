'use strict';

// Data Principal rights — DPDPA Sections 11-14, Rule 14.

async function exportUserData(db, userId) {
  const user = await db('users').where({ id: userId }).first();
  const consents = await db('consent_log').where({ user_id: userId });
  return { user, consents };
}

async function updateProfile(db, userId, changes) {
  return db('users').where({ id: userId }).update(changes);
}

// right to erasure (Section 12): queue deletion, send the 48-hour
// pre-erasure notice (Rule 8(2)), then purge.
async function deleteAccount(db, userId) {
  await db('erasure_queue').insert({ user_id: userId, request_status: 'pending' });
}

// anonymize records that must be kept for legal retention so they can
// no longer identify the Data Principal
function anonymize(record) {
  return { ...record, full_name: null, contact: null };
}

// nomination (Section 14): a nominee may exercise rights on the Data
// Principal's death or incapacity
async function setNominee(db, userId, nominee) {
  await db('users').where({ id: userId }).update({ nominee });
}

module.exports = { exportUserData, updateProfile, deleteAccount, anonymize, setNominee };
