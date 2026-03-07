#!/bin/bash
set -e

# DPDPA Compliance Scanner
# Scans a codebase for common DPDPA compliance issues
# Usage: bash audit-scan.sh /path/to/project
#
# This script performs pattern-based scanning to identify potential
# DPDPA compliance issues. It is a starting point — not a substitute
# for a thorough manual audit.

PROJECT_DIR="${1:-.}"
REPORT_FILE="${2:-dpdpa-audit-report.md}"

echo "Scanning: $PROJECT_DIR" >&2
echo "Report: $REPORT_FILE" >&2

# Counters
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0
INFO=0

# Output helpers
finding() {
  local severity="$1"
  local title="$2"
  local section="$3"
  local details="$4"
  local files="$5"

  echo ""
  echo "### [$severity] $title"
  echo "- **DPDPA Section:** $section"
  echo "- **Details:** $details"
  if [ -n "$files" ]; then
    echo "- **Files:**"
    echo '```'
    echo "$files"
    echo '```'
  fi
  echo ""

  case $severity in
    CRITICAL) CRITICAL=$((CRITICAL + 1)) ;;
    HIGH) HIGH=$((HIGH + 1)) ;;
    MEDIUM) MEDIUM=$((MEDIUM + 1)) ;;
    LOW) LOW=$((LOW + 1)) ;;
    INFO) INFO=$((INFO + 1)) ;;
  esac
}

{
echo "# DPDPA Compliance Scan Report"
echo ""
echo "**Scanned:** $(date -Iseconds)"
echo "**Directory:** $PROJECT_DIR"
echo ""
echo "---"
echo ""
echo "## Findings"

# --- Check 1: Pre-checked consent checkboxes ---
PRECHECKED=$(grep -rn 'checked={true}\|checked="checked"\|checked=true\|defaultChecked={true}\|:checked="true"' \
  "$PROJECT_DIR" --include="*.jsx" --include="*.tsx" --include="*.vue" --include="*.html" \
  2>/dev/null | grep -i 'consent\|agree\|accept\|privacy\|terms' || true)

if [ -n "$PRECHECKED" ]; then
  finding "CRITICAL" "Pre-checked consent checkbox detected" \
    "Section 4.1 — Consent must be clear affirmative action" \
    "Found checkboxes that appear to be pre-checked for consent. DPDPA requires consent to be given through a clear affirmative action — pre-checked boxes violate this." \
    "$PRECHECKED"
fi

# --- Check 2: Missing account deletion flow ---
DELETE_FLOW=$(grep -rn 'delete.*account\|account.*delet\|erase.*data\|data.*eras\|remove.*account' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  --include="*.py" --include="*.php" --include="*.rb" 2>/dev/null | head -20 || true)

if [ -z "$DELETE_FLOW" ]; then
  finding "HIGH" "No account deletion mechanism found" \
    "Section 12.1d — Right to erasure" \
    "No code patterns for account/data deletion were found. Data Principals have the right to erasure of their personal data." \
    ""
fi

# --- Check 3: Missing grievance mechanism ---
GRIEVANCE=$(grep -rn 'grievance\|complaint\|dpo\|data.protection.officer\|grievance_redressal' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  --include="*.py" --include="*.php" --include="*.rb" --include="*.html" 2>/dev/null | head -20 || true)

if [ -z "$GRIEVANCE" ]; then
  finding "HIGH" "No grievance redressal mechanism found" \
    "Section 13 — Right of grievance redressal" \
    "No grievance or complaint handling code was found. Data Principals must have readily available means of grievance redressal." \
    ""
fi

# --- Check 4: HTTP endpoints (no TLS) ---
HTTP_URLS=$(grep -rn "http://" "$PROJECT_DIR" \
  --include="*.js" --include="*.ts" --include="*.env" --include="*.yaml" --include="*.yml" \
  --include="*.py" --include="*.php" --include="*.rb" --include="*.json" \
  2>/dev/null | grep -v 'localhost\|127.0.0.1\|http://schemas\|http://www.w3.org\|http://json-schema' | head -20 || true)

if [ -n "$HTTP_URLS" ]; then
  finding "HIGH" "Non-HTTPS URLs detected" \
    "Section 7c — Reasonable security safeguards" \
    "Found HTTP (non-encrypted) URLs in the codebase. All data transmission should use HTTPS/TLS to protect personal data in transit." \
    "$HTTP_URLS"
fi

# --- Check 5: Analytics/tracking without consent check ---
TRACKING=$(grep -rn 'gtag\|analytics\|mixpanel\|amplitude\|segment\|hotjar\|clarity\|facebook.*pixel\|fbq(' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  --include="*.html" 2>/dev/null | head -20 || true)

CONSENT_CHECK=$(grep -rn 'consent\|hasConsent\|consentGranted\|cookieConsent\|analyticsConsent' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  2>/dev/null | head -5 || true)

if [ -n "$TRACKING" ] && [ -z "$CONSENT_CHECK" ]; then
  finding "CRITICAL" "Analytics/tracking initialized without consent check" \
    "Section 3, 4 — Lawful processing requires consent" \
    "Tracking/analytics SDKs are loaded but no consent verification was found. Analytics that process personal data require consent under DPDPA." \
    "$TRACKING"
fi

# --- Check 6: No age verification ---
AGE_CHECK=$(grep -rn 'age.*verif\|date.*birth\|dob\|isChild\|is_child\|age_gate\|ageGate\|minAge\|under.*18\|parental.*consent\|guardian.*consent' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  --include="*.py" --include="*.php" --include="*.rb" 2>/dev/null | head -10 || true)

if [ -z "$AGE_CHECK" ]; then
  finding "MEDIUM" "No age verification mechanism found" \
    "Section 8 — Children's data protection" \
    "No age verification code was detected. If your app may be used by children (under 18), you need age verification and verifiable parental consent." \
    ""
fi

# --- Check 7: Data retention / auto-deletion ---
RETENTION=$(grep -rn 'retention\|ttl\|expir\|auto.*delet\|purge\|cleanup.*cron\|data.*lifecycle' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.py" --include="*.php" \
  --include="*.rb" --include="*.yaml" --include="*.yml" --include="*.json" 2>/dev/null | head -10 || true)

if [ -z "$RETENTION" ]; then
  finding "MEDIUM" "No data retention policy implementation found" \
    "Section 7e — Erase data when no longer needed" \
    "No data retention or auto-deletion mechanisms were found. DPDPA requires erasure of personal data when it is no longer needed for the processing purpose." \
    ""
fi

# --- Check 8: Plaintext sensitive data in logs ---
LOG_LEAK=$(grep -rn 'console.log.*password\|console.log.*email\|console.log.*phone\|console.log.*token\|logger.*password\|print.*password\|log\.info.*email' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.py" --include="*.php" \
  --include="*.rb" 2>/dev/null | head -10 || true)

if [ -n "$LOG_LEAK" ]; then
  finding "HIGH" "Potential personal data in logs" \
    "Section 7c — Security safeguards" \
    "Found logging statements that may output personal data (passwords, emails, tokens). Logs containing personal data in plaintext are a security risk." \
    "$LOG_LEAK"
fi

# --- Check 9: Data export / portability ---
DATA_EXPORT=$(grep -rn 'export.*data\|download.*data\|my.*data\|data.*portab\|dsar\|subject.*access' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
  --include="*.py" --include="*.php" --include="*.rb" 2>/dev/null | head -10 || true)

if [ -z "$DATA_EXPORT" ]; then
  finding "MEDIUM" "No data export/access mechanism found" \
    "Section 11 — Right of Data Principal to access" \
    "No data export or access request functionality was found. Data Principals have the right to obtain a summary of their personal data." \
    ""
fi

# --- Check 10: Breach notification ---
BREACH=$(grep -rn 'breach\|incident.*report\|security.*alert\|notify.*breach\|breach.*notif' \
  "$PROJECT_DIR" --include="*.js" --include="*.ts" --include="*.py" --include="*.php" \
  --include="*.rb" --include="*.yaml" --include="*.yml" 2>/dev/null | head -10 || true)

if [ -z "$BREACH" ]; then
  finding "HIGH" "No breach notification mechanism found" \
    "Section 7d — Breach notification" \
    "No breach detection or notification code was found. DPDPA requires notifying the Board and affected Data Principals of personal data breaches." \
    ""
fi

# --- Summary ---
TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW + INFO))

echo "---"
echo ""
echo "## Summary"
echo ""
echo "| Severity | Count |"
echo "|----------|-------|"
echo "| Critical | $CRITICAL |"
echo "| High | $HIGH |"
echo "| Medium | $MEDIUM |"
echo "| Low | $LOW |"
echo "| Info | $INFO |"
echo "| **Total** | **$TOTAL** |"
echo ""

if [ $TOTAL -eq 0 ]; then
  echo "No issues detected by automated scan. This does not guarantee compliance —"
  echo "a thorough manual review using the full audit checklist is recommended."
else
  echo "**Automated scan complete.** This covers common patterns only."
  echo "Run a full manual audit using \`references/audit-checklist.md\` for comprehensive coverage."
fi

echo ""
echo "---"
echo "*Generated by DPDPA Compliance Scanner | $(date -Iseconds)*"

} > "$REPORT_FILE"

echo "" >&2
echo "Scan complete. Report saved to: $REPORT_FILE" >&2
echo "Critical: $CRITICAL | High: $HIGH | Medium: $MEDIUM | Low: $LOW | Info: $INFO" >&2
