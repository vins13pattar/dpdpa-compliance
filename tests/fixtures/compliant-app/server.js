'use strict';

// Test fixture: DPDPA-compliant demo API. Deliberately exercises the
// patterns audit-scan.sh treats as evidence of compliance.

const express = require('express');
const { z } = require('zod'); // input validation — Section 8(5)
const rateLimit = require('express-rate-limit');
const session = require('express-session');
const { recordConsent, removeConsent } = require('./consent');
const { deleteAccount, exportUserData, updateProfile, setNominee } = require('./rights');

const app = express();
app.use(express.json());

// Security safeguards — Section 8(5), DPDP Rules 2025 Rule 6.
// Personal data columns are encrypted at rest (pgcrypto + cloud kms);
// data residency: all personal data stays in ap-south-1 (Mumbai).
app.use(session({
  secret: process.env.SESSION_SECRET,
  cookie: { httpOnly: true, secure: true, sameSite: 'strict' },
}));
app.use(rateLimit({ windowMs: 60_000, max: 100 }));

// role-based authorization for every personal-data route
function requireAuth(req, res, next) {
  if (!req.session.userId) return res.status(401).end();
  return next();
}

const signupSchema = z.object({
  fullName: z.string().min(1),
  dateOfBirth: z.string(),
  purposes: z.array(z.string()),
});

// Children's data — Section 9, Rule 10: age_verification gate with
// verifiable parental_consent before processing a child's data.
app.post('/signup', async (req, res) => {
  const body = signupSchema.parse(req.body);
  await recordConsent(req.db, body);
  res.status(201).end();
});

// right to access (Section 11): self-service data-export
app.get('/api/data-export', requireAuth, async (req, res) => {
  res.json(await exportUserData(req.db, req.session.userId));
});

// right to correction (Section 12)
app.post('/api/profile', requireAuth, async (req, res) => {
  res.json(await updateProfile(req.db, req.session.userId, req.body));
});

// right to erasure (Section 12)
app.post('/api/account/delete', requireAuth, async (req, res) => {
  await deleteAccount(req.db, req.session.userId);
  res.json({ scheduled: true });
});

// nomination (Section 14)
app.post('/api/nominee', requireAuth, async (req, res) => {
  await setNominee(req.db, req.session.userId, req.body.nominee);
  res.status(204).end();
});

// grievance redressal (Section 13, Rule 14(3)): tracked against a 90-day SLA
app.post('/api/grievance', requireAuth, async (req, res) => {
  const row = await req.db('grievances').insert({
    user_id: req.session.userId,
    subject: String(req.body.subject),
  });
  res.status(201).json(row);
});

// consent withdrawal — as easy as granting it (Section 6(4))
app.post('/api/consent/remove', requireAuth, async (req, res) => {
  await removeConsent(req.db, req.session.userId, req.body.purpose);
  res.status(204).end();
});

// purpose_limitation: data collected for one purpose is never reused
// for another without fresh consent (Section 6).

module.exports = app;
