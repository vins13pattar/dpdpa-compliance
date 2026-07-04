#!/usr/bin/env bash
set -euo pipefail

# Test suite for the DPDPA compliance scanner and CLI.
# Runs audit-scan.sh against known-vulnerable and known-compliant fixture
# apps and asserts each check reports the expected outcome.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER="$ROOT/skills/dpdpa-compliance/scripts/audit-scan.sh"
CLI="$ROOT/cli/dpdpa-audit.js"
FIXTURES="$ROOT/tests/fixtures"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

FAILURES=0

assert_finding() { # <report> <severity> <check-id>
  if grep -q "^### \[$2\] $3:" "$1"; then
    echo "  ok: $3 flagged as $2"
  else
    echo "  FAIL: expected $3 to be flagged as $2"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_pass() { # <report> <check-id>
  if grep -q "^### \[PASS\] $2:" "$1"; then
    echo "  ok: $2 passed"
  else
    echo "  FAIL: expected $2 to pass"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_absent() { # <report> <severity>
  if grep -q "^### \[$2\]" "$1"; then
    echo "  FAIL: expected no $2 findings, got:"
    grep "^### \[$2\]" "$1" | sed 's/^/    /'
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok: no $2 findings"
  fi
}

echo "== scanner: vulnerable fixture must be flagged =="
bash "$SCANNER" "$FIXTURES/vulnerable-app" "$OUT/vulnerable.md" 2>/dev/null
assert_finding "$OUT/vulnerable.md" CRITICAL A1  # pre-checked consent checkbox
assert_finding "$OUT/vulnerable.md" HIGH     A2  # no consent mechanism
assert_finding "$OUT/vulnerable.md" HIGH     A4  # no consent withdrawal
assert_finding "$OUT/vulnerable.md" HIGH     B1  # no privacy notice
assert_finding "$OUT/vulnerable.md" HIGH     D2  # non-HTTPS transmission
assert_finding "$OUT/vulnerable.md" HIGH     D5  # personal data in logs
assert_finding "$OUT/vulnerable.md" CRITICAL D7  # hardcoded secret
assert_finding "$OUT/vulnerable.md" MEDIUM   F4  # analytics without child exclusion
assert_finding "$OUT/vulnerable.md" HIGH     G4  # no grievance mechanism

echo ""
echo "== scanner: compliant fixture must pass =="
bash "$SCANNER" "$FIXTURES/compliant-app" "$OUT/compliant.md" --verbose 2>/dev/null
for check in A1 A2 A3 A4 A6 A7 A8 \
             B1 B3 B4 \
             C2 C3 C4 C5 \
             D1 D2 D3 D4 D5 D6 D7 D9 D10 \
             E1 E2 E3 E4 E5 \
             F1 F2 F4 F5 \
             G1 G2 G3 G4 G5 G6 \
             H2 K1; do
  assert_pass "$OUT/compliant.md" "$check"
done
assert_absent "$OUT/compliant.md" CRITICAL
assert_absent "$OUT/compliant.md" HIGH

echo ""
echo "== cli: flags and exit codes =="
if [ "$(node "$CLI" --version)" = "$(node -p "require('$ROOT/package.json').version")" ]; then
  echo "  ok: --version matches package.json"
else
  echo "  FAIL: --version does not match package.json"
  FAILURES=$((FAILURES + 1))
fi

node "$CLI" --help >/dev/null && echo "  ok: --help exits 0"

if node "$CLI" "$FIXTURES/vulnerable-app" -o "$OUT/cli-vuln.md" --fail-on high >/dev/null 2>&1; then
  echo "  FAIL: --fail-on high should exit non-zero on the vulnerable fixture"
  FAILURES=$((FAILURES + 1))
else
  echo "  ok: --fail-on high exits non-zero on the vulnerable fixture"
fi
[ -s "$OUT/cli-vuln.md" ] && echo "  ok: CLI wrote the report" || { echo "  FAIL: CLI report missing"; FAILURES=$((FAILURES + 1)); }

if node "$CLI" "$FIXTURES/compliant-app" -o "$OUT/cli-comp.md" --fail-on critical >/dev/null 2>&1; then
  echo "  ok: --fail-on critical exits 0 on the compliant fixture"
else
  echo "  FAIL: --fail-on critical should exit 0 on the compliant fixture"
  FAILURES=$((FAILURES + 1))
fi

if node "$CLI" "$OUT/does-not-exist" >/dev/null 2>&1; then
  echo "  FAIL: missing directory should exit non-zero"
  FAILURES=$((FAILURES + 1))
else
  echo "  ok: missing directory exits non-zero"
fi

echo ""
echo "== python package =="
if cmp -s "$SCANNER" "$ROOT/python/src/dpdpa_audit/data/audit-scan.sh"; then
  echo "  ok: bundled scanner is byte-identical to the canonical one"
else
  echo "  FAIL: python/src/dpdpa_audit/data/audit-scan.sh is out of sync —"
  echo "        run: cp skills/dpdpa-compliance/scripts/audit-scan.sh python/src/dpdpa_audit/data/audit-scan.sh"
  FAILURES=$((FAILURES + 1))
fi

if command -v python3 >/dev/null 2>&1; then
  PYCLI() { PYTHONPATH="$ROOT/python/src" python3 -m dpdpa_audit "$@"; }

  if [ "$(PYCLI --version)" = "$(node -p "require('$ROOT/package.json').version")" ]; then
    echo "  ok: python --version matches package.json"
  else
    echo "  FAIL: python --version does not match package.json"
    FAILURES=$((FAILURES + 1))
  fi

  if PYCLI "$FIXTURES/vulnerable-app" -o "$OUT/py-vuln.md" --fail-on high >/dev/null 2>&1; then
    echo "  FAIL: python --fail-on high should exit non-zero on the vulnerable fixture"
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok: python --fail-on high exits non-zero on the vulnerable fixture"
  fi

  if PYCLI "$FIXTURES/compliant-app" -o "$OUT/py-comp.md" --fail-on critical >/dev/null 2>&1; then
    echo "  ok: python --fail-on critical exits 0 on the compliant fixture"
  else
    echo "  FAIL: python --fail-on critical should exit 0 on the compliant fixture"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "  skip: python3 not available"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES assertion(s) failed."
  exit 1
fi
echo "All assertions passed."
