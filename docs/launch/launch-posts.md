# Launch Posts

Ready-to-publish drafts. Timing hook: "~10 months until DPDPA enforcement"
(13 May 2027). Adjust the countdown when posting. Add the demo video link
once uploaded to YouTube.

---

## Show HN (news.ycombinator.com)

**Title:**

> Show HN: Open-source DPDPA compliance auditing for codebases (India's GDPR)

**Text:**

India's Digital Personal Data Protection Act becomes enforceable on May 13,
2027, with penalties up to ₹250 crore (~$30M) per breach category. Every
company processing Indian users' data has to comply — and the tooling
landscape is entirely commercial platforms (OneTrust, Seqrite, etc.) aimed at
compliance teams, not developers.

I built the open-source developer alternative. It's two things:

1. A CLI — `npx github:vins13pattar/dpdpa-compliance` — that scans a repo
against 52 checks derived from the Act and the DPDP Rules 2025 (pre-checked
consent boxes, missing withdrawal flows, PII in logs, missing breach
notification, children's data tracking, retention gaps, …) and writes a report
with severity and section citations. `--fail-on high` turns it into a CI gate.

2. An Agent Skill (Claude Code, Cursor, Codex, Copilot, 37+ agents) with the
full Act + Rules text, framework-specific implementation patterns (Node,
Django, Laravel, Go, Rails, Spring Boot, React, React Native), and guidance
for the obligations code can't solve (DPO appointment, DPIAs, processor
agreements).

The scanner is grep-based heuristics, deliberately — it's auditable, it runs
anywhere bash runs, and a test suite of known-vulnerable/known-compliant
fixture apps keeps it honest. It flags candidates for a human (or an agent)
to verify; it is not legal advice.

Repo: https://github.com/vins13pattar/dpdpa-compliance

Would love feedback on the check coverage — especially from anyone who has
been through a DPDPA readiness exercise with counsel.

---

## r/developersIndia (Reddit)

**Title:**

> DPDPA enforcement is ~10 months away (May 13, 2027). I built a free, open-source tool to audit your codebase before the deadline.

**Body:**

The DPDP Rules 2025 were notified in November. The dates that matter for us:

- **~13 Nov 2026** — Consent Manager registration opens (Rule 4)
- **13 May 2027** — the real deadline: consent, notice, breach notification,
  children's data, retention, and Data Principal rights obligations all become
  enforceable
- Penalties: up to **₹250 crore** for security safeguard failures, **₹200
  crore** for children's data violations

Every compliance tool in this space is a commercial platform sold to legal
teams. There was nothing a developer could run on a repo. So I built it:

```
npx github:vins13pattar/dpdpa-compliance
```

That scans your codebase against 52 checks from the Act + Rules and writes a
Markdown report: what's wrong, which section it violates, how to fix it, and
penalty exposure. Runs in CI with `--fail-on high` if you want to block merges.

If you use Claude Code / Cursor / Copilot, there's also an agent skill
(`npx skills add vins13pattar/dpdpa-compliance`) that does deeper audits and
generates compliant consent flows, deletion endpoints, breach notification
plumbing, etc. for your specific stack — patterns included for Node, Django,
Laravel, Go, Rails, Spring Boot, React, React Native.

It's MIT licensed. Not legal advice — it finds the technical gaps, your
counsel makes the calls. Contributions welcome (Flutter/Next.js/FastAPI
patterns and Hindi consent notice templates are open good-first-issues).

GitHub: https://github.com/vins13pattar/dpdpa-compliance

---

## LinkedIn

**Post:**

India's DPDPA becomes enforceable on 13 May 2027. Penalties go up to ₹250
crore. And almost every engineering team I talk to has the same plan:
"legal will handle it."

Legal can't fix your codebase.

Pre-checked consent boxes. Passwords in logs. No account deletion flow. No
72-hour breach notification path. Analytics SDKs tracking minors. These are
engineering problems, and they're exactly what the Data Protection Board
will fine you for.

I built an open-source tool that finds them:

→ One command, no signup: npx github:vins13pattar/dpdpa-compliance
→ 52 automated checks mapped to the Act and the DPDP Rules 2025
→ Report with severity, section citations, and concrete fixes
→ Works as a CI gate, and as an AI agent skill for Claude Code/Cursor/Copilot
→ MIT licensed — the only open-source developer tooling in this space

The commercial platforms are built for compliance teams. This is built for
the people who ship the code.

10 months. Audit before the deadline: https://github.com/vins13pattar/dpdpa-compliance

#DPDPA #DataProtection #India #OpenSource #Privacy #Compliance

---

## dev.to article

**Title:**

> Your codebase has ~10 months to become DPDPA-compliant. Here's how to audit it in 5 minutes.

**Tags:** `privacy`, `india`, `opensource`, `security`

**Outline:**

1. **The deadline nobody's tracking** — Rules notified 13 Nov 2025; Consent
   Manager registration ~Nov 2026; full enforcement 13 May 2027; penalty
   schedule table (₹250cr security / ₹200cr children's data / ₹200cr breach
   notification failures).
2. **What DPDPA actually demands from code** — walk the seven obligation
   areas with code smells for each: consent (no pre-ticked boxes, per-purpose,
   withdrawal as easy as grant), notice, security safeguards, breach
   notification (72h to Board, plain-language to users), children's data (age
   gate + verifiable parental consent + no tracking), Data Principal rights
   (export, correction, erasure with 48h notice, 90-day grievance SLA),
   retention.
3. **Run the audit** — `npx github:vins13pattar/dpdpa-compliance . -o report.md`;
   annotated sample report from the deliberately-vulnerable fixture app;
   explain severity levels and the compliance score.
4. **Fix the findings** — before/after for the three most common: pre-checked
   consent checkbox → per-purpose ConsentBanner; no deletion flow → erasure
   endpoint with 48-hour pre-erasure notice; PII in logs → redacting logger.
5. **Wire it into CI** — GitHub Actions snippet with `--fail-on high`.
6. **What code can't fix** — DPO, DPIA, processor agreements; when to loop in
   counsel. Disclaimer: technical guidance, not legal advice.
7. **Contribute** — framework patterns and translations wanted; link
   good-first-issues.

---

## X/Twitter thread (bonus)

1/ India's DPDPA becomes enforceable May 13, 2027. Max penalty: ₹250 crore.
Every tool in this space is commercial, sold to legal teams, and useless to
the developer who has to actually fix the code. So I open-sourced one.

2/ One command: `npx github:vins13pattar/dpdpa-compliance`
52 checks from the Act + DPDP Rules 2025. Pre-checked consent boxes, PII in
logs, missing deletion flows, children's data tracking. Report cites the exact
section you're violating.

3/ Using Claude Code or Cursor? Install it as an agent skill and it doesn't
just find the gaps — it writes the consent ledger, the erasure endpoint with
the 48-hour notice, the 72-hour breach notification worker. Patterns for
Node, Django, Go, Rails, Spring Boot + more.

4/ MIT licensed, tested against fixture apps in CI, every check cites its
rule. Not legal advice — it's the technical layer your counsel doesn't have.
⭐ https://github.com/vins13pattar/dpdpa-compliance
