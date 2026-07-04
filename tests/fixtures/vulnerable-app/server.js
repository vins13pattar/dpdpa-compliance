// Test fixture: deliberately NON-compliant API server.
// The scanner must flag what is here (hardcoded secret D7, personal data
// in logs D5, plain-HTTP transmission D2) and what is missing entirely
// (checks A4, B1, G4 — keywords intentionally absent from this file).
const express = require('express');
const db = require('./db');

const app = express();
app.use(express.json());

const API_KEY = "sk_live_9f8a7b6c5d4e3f2a1b0c";

app.post('/signup', (req, res) => {
  const { fullName, userEmail, password } = req.body;
  console.log('signup attempt', userEmail, password);
  db.run(
    "INSERT INTO users (name, mail, pass) VALUES (?, ?, ?)",
    [fullName, userEmail, password]
  );
  fetch(`http://api.metrics-collector.io/track?key=${API_KEY}`, { method: 'POST' });
  res.json({ ok: true });
});

app.listen(3000);
