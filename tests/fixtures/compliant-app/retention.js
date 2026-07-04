'use strict';

// Retention and erasure — Section 8(7), Rule 8 + Third Schedule.
// retention_days per data category; a nightly job erases personal data
// once it is no longer needed for its stated purpose.
const retention_days = {
  consent_log: 365, // Rule 6(e): logs kept at least 1 year
  access_logs: 365,
  grievances: 1095,
};

async function purgeExpired(db) {
  for (const [table, days] of Object.entries(retention_days)) {
    await db(table).where('created_at', '<', daysAgo(days)).del();
  }
}

// backup purge: deletion propagates to backups within 30 days
async function purgeBackups(store) {
  await store.expireSnapshots({ olderThanDays: 30 });
}

function daysAgo(days) {
  return new Date(Date.now() - days * 86_400_000);
}

module.exports = { retention_days, purgeExpired, purgeBackups };
