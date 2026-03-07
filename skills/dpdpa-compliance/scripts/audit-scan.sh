#!/bin/bash
set -euo pipefail

# DPDPA Compliance Scanner v2.0
# Scans codebase against 52-point DPDPA checklist
# (Digital Personal Data Protection Act, 2023 — India)
#
# Usage: bash audit-scan.sh [project-dir] [report-file] [--verbose]

PROJECT_DIR="${1:-.}"
REPORT_FILE="${2:-dpdpa-audit-report.md}"
VERBOSE=false
for arg in "$@"; do
  [ "$arg" = "--verbose" ] && VERBOSE=true
done

# Validate project directory
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Directory '$PROJECT_DIR' does not exist." >&2
  exit 1
fi

echo "DPDPA Compliance Scanner v2.0" >&2
echo "Scanning: $PROJECT_DIR" >&2
echo "Report:   $REPORT_FILE" >&2
echo "Verbose:  $VERBOSE" >&2
echo "" >&2

# Counters
CRITICAL=0; HIGH=0; MEDIUM=0; LOW=0; INFO=0; PASS=0; TOTAL=0

# --- Exclusion and file type setup ---
EXCLUDES="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=__pycache__ --exclude-dir=venv --exclude-dir=.venv --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage --exclude-dir=target --exclude-dir=bin --exclude-dir=obj --exclude-dir=.bundle --exclude-dir=deps"

CODE_INCLUDE="--include=*.js --include=*.ts --include=*.py --include=*.php --include=*.rb --include=*.java --include=*.go --include=*.rs --include=*.cs"
UI_INCLUDE="--include=*.jsx --include=*.tsx --include=*.vue --include=*.svelte --include=*.html --include=*.ejs --include=*.hbs"
CONFIG_INCLUDE="--include=*.json --include=*.yaml --include=*.yml --include=*.env --include=*.toml --include=*.ini --include=*.conf --include=*.cfg"
ALL_CODE="$CODE_INCLUDE $UI_INCLUDE"
ALL_FILES="$CODE_INCLUDE $UI_INCLUDE $CONFIG_INCLUDE"
SCHEMA_INCLUDE="--include=*.sql --include=*.prisma --include=*.py --include=*.rb --include=*.js --include=*.ts --include=*.java --include=*.go --include=*.cs"
CI_INCLUDE="--include=*.yml --include=*.yaml"

# --- Search helpers ---
search_code() {
  grep -rn "$1" "$PROJECT_DIR" $ALL_CODE $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_config() {
  grep -rn "$1" "$PROJECT_DIR" $CONFIG_INCLUDE $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_ui() {
  grep -rn "$1" "$PROJECT_DIR" $UI_INCLUDE $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_all() {
  grep -rn "$1" "$PROJECT_DIR" $ALL_FILES $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_schema() {
  grep -rn "$1" "$PROJECT_DIR" $SCHEMA_INCLUDE $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_code_ext() {
  grep -rn -E "$1" "$PROJECT_DIR" $ALL_CODE $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

search_all_ext() {
  grep -rn -E "$1" "$PROJECT_DIR" $ALL_FILES $EXCLUDES 2>/dev/null | head -"${2:-20}" || true
}

# --- Output helpers ---
finding() {
  local severity="$1" id="$2" title="$3" section="$4" details="$5" remediation="$6" files="$7"
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "### [$severity] $id: $title"
  echo "- **DPDPA Section:** $section"
  echo "- **Details:** $details"
  echo "- **Remediation:** $remediation"
  if [ -n "$files" ]; then
    echo "- **Files:**"
    echo '```'
    echo "$files"
    echo '```'
  fi

  case $severity in
    CRITICAL) CRITICAL=$((CRITICAL + 1)) ;;
    HIGH)     HIGH=$((HIGH + 1)) ;;
    MEDIUM)   MEDIUM=$((MEDIUM + 1)) ;;
    LOW)      LOW=$((LOW + 1)) ;;
    INFO)     INFO=$((INFO + 1)) ;;
  esac
}

pass() {
  local id="$1" title="$2" section="$3"
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  if $VERBOSE; then
    echo ""
    echo "### [PASS] $id: $title"
    echo "- **DPDPA Section:** $section"
  fi
}

# ============================================================
# BEGIN REPORT
# ============================================================
{

echo "# DPDPA Compliance Scan Report"
echo ""
echo "**Scanner Version:** 2.0"
echo "**Scanned:** $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
echo "**Directory:** $PROJECT_DIR"
echo "**Checks:** 52 (A1-A8, B1-B4, C1-C5, D1-D10, E1-E5, F1-F5, G1-G6, H1-H3, I1-I2, J1, K1-K3)"
echo ""
echo "---"
echo ""
echo "## Findings"

# ============================================================
# SECTION A: Consent Collection (Sections 3, 4)
# ============================================================
echo ""
echo "## Section A: Consent Collection"
echo "*(DPDPA Sections 3, 4)*"

# --- A1: Pre-checked consent checkboxes ---
echo "  [A1] Checking for pre-checked consent checkboxes..." >&2
PRECHECKED=$(grep -rn 'checked={true}\|checked="checked"\|defaultChecked={true}\|defaultChecked="true"\|:checked="true"' \
  "$PROJECT_DIR" $UI_INCLUDE $EXCLUDES 2>/dev/null \
  | grep -i 'consent\|agree\|accept\|privacy\|terms' || true)

if [ -n "$PRECHECKED" ]; then
  finding "CRITICAL" "A1" "Pre-checked consent checkbox detected" \
    "Section 4.1 — Consent must be clear affirmative action" \
    "Found checkboxes that appear to be pre-checked for consent. DPDPA requires consent to be given through a clear affirmative action — pre-checked boxes violate this." \
    "Ensure all consent checkboxes default to unchecked (checked={false}). See implementation-patterns.md S1." \
    "$PRECHECKED"
else
  pass "A1" "No pre-checked consent checkboxes detected" "Section 4.1"
fi

# --- A2: Missing consent collection mechanism ---
echo "  [A2] Checking for consent collection mechanism..." >&2
CONSENT_MECH=$(search_code 'consent_form\|consent_modal\|consent_banner\|consent_dialog\|getConsent\|requestConsent\|showConsent\|ConsentForm\|ConsentBanner\|ConsentModal')

if [ -z "$CONSENT_MECH" ]; then
  finding "HIGH" "A2" "Missing consent collection mechanism" \
    "Section 3, 4 — Lawful processing requires consent" \
    "No consent collection UI patterns (consent_form, ConsentBanner, etc.) were found. DPDPA requires informed, specific consent before processing personal data." \
    "Implement a consent collection UI. See implementation-patterns.md S1 for React consent banner pattern." \
    ""
  HAS_CONSENT=false
else
  pass "A2" "Consent collection mechanism found" "Section 3, 4"
  HAS_CONSENT=true
fi

# --- A3: Bundled consent (no granularity) ---
echo "  [A3] Checking for granular consent..." >&2
GRANULAR=$(search_code 'consent_purposes\|consent_categories\|granular_consent\|separate_consent\|purpose_id\|consent_type')

if $HAS_CONSENT && [ -z "$GRANULAR" ]; then
  finding "MEDIUM" "A3" "Bundled consent — no granularity detected" \
    "Section 4 — Consent per purpose" \
    "Consent mechanism exists but no granular/per-purpose consent patterns were found. DPDPA requires consent to be specific to each purpose of processing." \
    "Separate consent by purpose (analytics, marketing, etc.). See implementation-patterns.md S1." \
    ""
elif ! $HAS_CONSENT; then
  finding "MEDIUM" "A3" "Cannot assess consent granularity — no consent mechanism" \
    "Section 4 — Consent per purpose" \
    "No consent mechanism was found (see A2), so granularity cannot be assessed." \
    "Implement consent collection first, then separate by purpose." \
    ""
else
  pass "A3" "Granular consent patterns found" "Section 4"
fi

# --- A4: Missing consent withdrawal ---
echo "  [A4] Checking for consent withdrawal mechanism..." >&2
WITHDRAW=$(search_code_ext 'withdraw.*consent|revoke.*consent|consent.*withdraw|consent.*revoke|unsubscribe|opt.out|optOut|removeConsent')

if [ -z "$WITHDRAW" ]; then
  finding "HIGH" "A4" "Missing consent withdrawal mechanism" \
    "Section 4.2 — Right to withdraw consent" \
    "No consent withdrawal patterns were found. DPDPA requires that withdrawal of consent be as easy as giving consent." \
    "Add consent withdrawal mechanism. Withdrawal must be as easy as granting consent." \
    ""
else
  pass "A4" "Consent withdrawal mechanism found" "Section 4.2"
fi

# --- A5: Pre-existing data handling ---
echo "  [A5] Advisory: pre-existing data handling..." >&2
finding "INFO" "A5" "Pre-existing data handling advisory" \
  "Section 5 — Notice for previously collected data" \
  "If personal data was collected before DPDPA commencement, a notice must be served to existing users as soon as reasonably practicable." \
  "If data predates DPDPA, serve notice to existing users as soon as reasonably practicable (Section 5)." \
  ""

# --- A6: Missing consent audit trail ---
echo "  [A6] Checking for consent audit trail..." >&2
AUDIT_TRAIL=$(search_code 'consent_log\|consent_record\|consent_audit\|consent_history\|audit_trail.*consent\|consent_timestamp\|logConsent\|recordConsent')

if [ -z "$AUDIT_TRAIL" ]; then
  finding "HIGH" "A6" "Missing consent audit trail" \
    "Section 4 — Demonstrable consent" \
    "No consent logging or audit trail patterns were found. Organizations must be able to demonstrate that valid consent was obtained." \
    "Record every consent event with: who, when, what, version of notice, and how. See implementation-patterns.md S1." \
    ""
else
  pass "A6" "Consent audit trail found" "Section 4"
fi

# --- A7: No consent version tracking ---
echo "  [A7] Checking for consent version tracking..." >&2
CONSENT_VER=$(search_code 'consent_version\|notice_version\|policy_version\|consent.*version\|version.*consent')

if [ -z "$CONSENT_VER" ]; then
  finding "MEDIUM" "A7" "No consent version tracking" \
    "Section 4, 5 — Informed consent requires versioned notices" \
    "No consent or notice version tracking was found. It is important to record which version of the privacy notice was shown when consent was obtained." \
    "Track which version of the privacy notice was shown when consent was obtained." \
    ""
else
  pass "A7" "Consent version tracking found" "Section 4, 5"
fi

# --- A8: No consent expiry/renewal ---
echo "  [A8] Checking for consent expiry/renewal..." >&2
CONSENT_EXP=$(search_code 'consent_expir\|consent_renew\|consent_ttl\|reconfirm.*consent\|consent.*refresh\|consent_valid')

if [ -z "$CONSENT_EXP" ]; then
  finding "LOW" "A8" "No consent expiry or renewal mechanism" \
    "Section 4 — Ongoing validity of consent" \
    "No consent expiration or renewal patterns were found. Consent should not be assumed to last indefinitely." \
    "Consider periodic consent renewal. Consent should not be assumed to last indefinitely." \
    ""
else
  pass "A8" "Consent expiry/renewal found" "Section 4"
fi

# ============================================================
# SECTION B: Notice and Disclosure (Section 5)
# ============================================================
echo ""
echo "## Section B: Notice and Disclosure"
echo "*(DPDPA Section 5)*"

# --- B1: No privacy notice/policy ---
echo "  [B1] Checking for privacy notice/policy..." >&2
PRIVACY_NOTICE=$(search_all 'privacy.notice\|privacy.policy\|privacy_notice\|privacy_policy\|PrivacyNotice\|PrivacyPolicy\|data_notice')

if [ -z "$PRIVACY_NOTICE" ]; then
  finding "HIGH" "B1" "No privacy notice or policy found" \
    "Section 5 — Notice before data collection" \
    "No privacy notice or policy references were found. DPDPA requires a notice to be given before or at the time of requesting personal data." \
    "Display a privacy notice before or at time of data collection. See audit-checklist.md SB1." \
    ""
else
  pass "B1" "Privacy notice/policy references found" "Section 5"
fi

# --- B2: Plain language requirement ---
echo "  [B2] Advisory: plain language requirement..." >&2
finding "INFO" "B2" "Plain language requirement advisory" \
  "Section 5 — Clear, plain language" \
  "Cannot be verified by automated scan. Privacy notices must use clear, plain language — not legal jargon — so that Data Principals can understand them." \
  "Manually verify that privacy notices use clear, plain language — not legal jargon." \
  ""

# --- B3: No language/i18n support ---
echo "  [B3] Checking for language/i18n support..." >&2
I18N=$(search_all 'i18n\|locale\|translation\|intl\|localize\|gettext\|nls\|react-intl\|next-intl\|vue-i18n')

if [ -z "$I18N" ]; then
  finding "LOW" "B3" "No language/i18n support detected" \
    "Section 5 — Language requirements" \
    "No internationalization patterns were found. For government services, notices must be in English and an Eighth Schedule language. Recommended for all apps." \
    "For government services, notices must be in English + an Eighth Schedule language. Recommended for all apps." \
    ""
else
  pass "B3" "Language/i18n support found" "Section 5"
fi

# --- B4: No notice versioning ---
echo "  [B4] Checking for notice versioning..." >&2
NOTICE_VER=$(search_all 'policy_version\|notice_version\|privacy.*version\|terms_version\|version.*policy\|policy_updated\|notice_updated')

if [ -z "$NOTICE_VER" ]; then
  finding "MEDIUM" "B4" "No notice versioning" \
    "Section 5 — Versioned notices" \
    "No policy or notice versioning patterns were found. Users must be re-notified when privacy notices change materially." \
    "Version your privacy notices. Re-notify users when notices change." \
    ""
else
  pass "B4" "Notice versioning found" "Section 5"
fi

# ============================================================
# SECTION C: Data Minimization and Retention (Section 7)
# ============================================================
echo ""
echo "## Section C: Data Minimization and Retention"
echo "*(DPDPA Section 7)*"

# --- C1: Collection minimization ---
echo "  [C1] Advisory: collection minimization..." >&2
finding "INFO" "C1" "Collection minimization advisory" \
  "Section 7 — Purpose limitation and minimization" \
  "Cannot be fully verified by automated scan. Review database schemas and forms to ensure only data necessary for stated purposes is collected." \
  "Review database schemas and forms. Collect only data necessary for stated purposes." \
  ""

# --- C2: No data retention policy ---
echo "  [C2] Checking for data retention policy..." >&2
RETENTION=$(search_all 'retention\|ttl\|expir\|auto.*delet\|purge\|cleanup.*cron\|data.*lifecycle\|retention_period\|retention_days')

if [ -z "$RETENTION" ]; then
  finding "MEDIUM" "C2" "No data retention policy implementation found" \
    "Section 7e — Erase data when no longer needed" \
    "No data retention or auto-deletion mechanisms were found. DPDPA requires erasure of personal data when it is no longer needed." \
    "Define retention periods for all personal data categories. Implement auto-deletion. See implementation-patterns.md S5." \
    ""
else
  pass "C2" "Data retention patterns found" "Section 7e"
fi

# --- C3: No deletion mechanism ---
echo "  [C3] Checking for deletion mechanism..." >&2
DELETE_MECH=$(search_code_ext 'delete.*account|account.*delet|erase.*data|data.*eras|remove.*account|purge.*user|destroyAccount|deleteUser|deleteAccount')

if [ -z "$DELETE_MECH" ]; then
  finding "HIGH" "C3" "No data deletion mechanism found" \
    "Section 7e, 12.1d — Erasure of personal data" \
    "No code patterns for account/data deletion were found. Data Principals have the right to erasure of their personal data." \
    "Implement account/data deletion API. See implementation-patterns.md S2 for erasure endpoint." \
    ""
else
  pass "C3" "Data deletion mechanism found" "Section 7e, 12.1d"
fi

# --- C4: Backup deletion ---
echo "  [C4] Checking for backup deletion..." >&2
BACKUP_DEL=$(search_all 'backup.*delet\|backup.*purg\|backup.*clean\|remove.*backup\|backup.*retention')

if [ -z "$BACKUP_DEL" ]; then
  finding "LOW" "C4" "No backup deletion mechanism found" \
    "Section 7e — Complete erasure" \
    "No backup deletion or purge patterns were found. Deletion should propagate to backups within a reasonable timeframe." \
    "Ensure deletion propagates to backups within a reasonable timeframe." \
    ""
else
  pass "C4" "Backup deletion mechanism found" "Section 7e"
fi

# --- C5: No anonymization validation ---
echo "  [C5] Checking for anonymization patterns..." >&2
ANONYMIZE=$(search_code 'anonymize\|pseudonymize\|mask.*pii\|hash.*pii\|de_identify\|deidentify\|redact')

if [ -z "$ANONYMIZE" ]; then
  finding "INFO" "C5" "No anonymization or pseudonymization patterns found" \
    "Section 7 — Data protection techniques" \
    "No anonymization patterns were detected. If using anonymization as an alternative to deletion, verify it is truly irreversible." \
    "If using anonymization instead of deletion, verify it is truly irreversible and cannot be re-identified." \
    ""
else
  pass "C5" "Anonymization/pseudonymization patterns found" "Section 7"
fi

# ============================================================
# SECTION D: Security Safeguards (Section 7c)
# ============================================================
echo ""
echo "## Section D: Security Safeguards"
echo "*(DPDPA Section 7c)*"

# --- D1: No encryption at rest ---
echo "  [D1] Checking for encryption at rest..." >&2
ENCRYPT=$(search_all 'encrypt\|aes\|cipher\|kms\|vault\|at.rest\|encryption_key\|ENCRYPTION_KEY\|encrypted_field\|pgcrypto')

if [ -z "$ENCRYPT" ]; then
  finding "MEDIUM" "D1" "No encryption at rest configuration found" \
    "Section 7c — Reasonable security safeguards" \
    "No encryption-at-rest patterns were found. Personal data should be encrypted when stored." \
    "Encrypt personal data at rest. Use database-level or application-level encryption." \
    ""
else
  pass "D1" "Encryption at rest patterns found" "Section 7c"
fi

# --- D2: Non-HTTPS URLs ---
echo "  [D2] Checking for non-HTTPS URLs..." >&2
HTTP_URLS=$(grep -rn "http://" "$PROJECT_DIR" $ALL_FILES $EXCLUDES 2>/dev/null \
  | grep -v 'localhost\|127\.0\.0\.1\|0\.0\.0\.0\|http://schemas\|http://www\.w3\.org\|http://json-schema\|http://xml\|http://xmlns\|http://example' \
  | head -20 || true)

if [ -n "$HTTP_URLS" ]; then
  finding "HIGH" "D2" "Non-HTTPS URLs detected" \
    "Section 7c — Reasonable security safeguards (data in transit)" \
    "Found HTTP (non-encrypted) URLs in the codebase. All data transmission should use HTTPS/TLS to protect personal data in transit." \
    "Use HTTPS for all data transmission. Replace http:// with https:// for production endpoints." \
    "$HTTP_URLS"
else
  pass "D2" "No non-HTTPS URLs detected" "Section 7c"
fi

# --- D3: No access controls ---
echo "  [D3] Checking for access controls..." >&2
ACCESS_CTRL=$(search_code_ext 'auth.*middleware|authorization|rbac|role.*check|isAuthenticated|requireAuth|@login_required|@authenticated|protect.*route|guard|@auth|Authorize|\[Authorize\]')

if [ -z "$ACCESS_CTRL" ]; then
  finding "HIGH" "D3" "No access controls detected" \
    "Section 7c — Reasonable security safeguards" \
    "No authentication or role-based access control patterns were found. Personal data endpoints must be protected." \
    "Implement authentication and role-based access controls for all personal data endpoints." \
    ""
else
  pass "D3" "Access control patterns found" "Section 7c"
fi

# --- D4: No input validation ---
echo "  [D4] Checking for input validation..." >&2
INPUT_VAL=$(search_code 'validate\|sanitize\|escape\|validator\|joi\|yup\|zod\|class-validator\|marshmallow\|pydantic\|wtforms')

if [ -z "$INPUT_VAL" ]; then
  finding "MEDIUM" "D4" "No input validation found" \
    "Section 7c — Security safeguards" \
    "No input validation or sanitization libraries/patterns were found. Unvalidated input can lead to injection attacks on personal data stores." \
    "Validate and sanitize all inputs to prevent injection attacks on personal data stores." \
    ""
else
  pass "D4" "Input validation patterns found" "Section 7c"
fi

# --- D5: Personal data in logs ---
echo "  [D5] Checking for personal data in logs..." >&2
LOG_LEAK=$(search_code_ext 'console\.log.*(password|email|phone|token|secret)|logger\..*(password|email|ssn|aadhaar|pan)|log\.(info|debug).*(password|email)|print.*(password)|puts.*(password)|logging\..*(password|email|phone)')

if [ -n "$LOG_LEAK" ]; then
  finding "HIGH" "D5" "Potential personal data in logs" \
    "Section 7c — Security safeguards" \
    "Found logging statements that may output personal data (passwords, emails, tokens, etc.). Logs containing personal data in plaintext are a security risk." \
    "Never log personal data in plaintext. Use structured logging with PII redaction." \
    "$LOG_LEAK"
else
  pass "D5" "No obvious personal data in logs" "Section 7c"
fi

# --- D6: No security scanning in CI/CD ---
echo "  [D6] Checking for security scanning in CI/CD..." >&2
SEC_SCAN=$(search_all 'snyk\|dependabot\|sonarqube\|sonar\|trivy\|codeql\|semgrep\|bandit\|brakeman\|safety\|npm.audit\|yarn.audit\|bundler-audit\|gosec\|cargo-audit')
CI_SCAN=""
if [ -d "$PROJECT_DIR/.github/workflows" ]; then
  CI_SCAN=$(grep -rn 'snyk\|dependabot\|sonar\|trivy\|codeql\|semgrep\|bandit\|brakeman\|safety\|npm.audit\|yarn.audit\|gosec\|cargo-audit' \
    "$PROJECT_DIR/.github/workflows/" $CI_INCLUDE 2>/dev/null | head -10 || true)
fi
GITLAB_SCAN=$(grep -rn 'snyk\|sonar\|trivy\|codeql\|semgrep\|bandit\|brakeman\|safety' \
  "$PROJECT_DIR/.gitlab-ci.yml" 2>/dev/null | head -5 || true)
JENKINS_SCAN=$(grep -rn 'snyk\|sonar\|trivy\|codeql\|semgrep\|bandit' \
  "$PROJECT_DIR/Jenkinsfile" 2>/dev/null | head -5 || true)

if [ -z "$SEC_SCAN" ] && [ -z "$CI_SCAN" ] && [ -z "$GITLAB_SCAN" ] && [ -z "$JENKINS_SCAN" ]; then
  finding "LOW" "D6" "No security scanning in CI/CD" \
    "Section 7c — Security safeguards" \
    "No dependency scanning or SAST tools were found in the codebase or CI/CD configuration." \
    "Add dependency scanning and SAST to your CI/CD pipeline." \
    ""
else
  pass "D6" "Security scanning configuration found" "Section 7c"
fi

# --- D7: Hardcoded secrets in source ---
echo "  [D7] Checking for hardcoded secrets..." >&2
HARDCODED=$(grep -rn -E '(password|api_key|apiKey|secret|SECRET_KEY|API_KEY|PRIVATE_KEY)\s*=\s*["\x27][a-zA-Z0-9]' \
  "$PROJECT_DIR" $CODE_INCLUDE $EXCLUDES \
  --exclude="*.example" --exclude="*.sample" --exclude="*.template" \
  --exclude-dir=test --exclude-dir=tests --exclude-dir=__tests__ --exclude-dir=spec \
  --exclude-dir=docs --exclude-dir=doc \
  2>/dev/null | grep -v 'README\|\.md:\|test_\|_test\.\|\.spec\.\|\.test\.\|example\|sample\|placeholder\|changeme\|CHANGE_ME\|your_.*_here\|xxx\|TODO' \
  | head -20 || true)

if [ -n "$HARDCODED" ]; then
  finding "CRITICAL" "D7" "Potential hardcoded secrets in source code" \
    "Section 7c — Security safeguards" \
    "Found patterns suggesting hardcoded credentials in source code. Exposed secrets can lead to unauthorized access to personal data." \
    "Move all secrets to environment variables or a secrets manager. Never commit credentials." \
    "$HARDCODED"
else
  pass "D7" "No obvious hardcoded secrets detected" "Section 7c"
fi

# --- D8: Personal data in error responses ---
echo "  [D8] Checking for data in error responses..." >&2
ERR_LEAK=$(search_code_ext 'catch.*res\.json.*err|catch.*response.*error|res\.status\(500\)\.json.*err|res\.send.*error\.stack|traceback.*response|stacktrace.*response|err\.message.*res')

if [ -n "$ERR_LEAK" ]; then
  finding "MEDIUM" "D8" "Potential personal data exposure in error responses" \
    "Section 7c — Security safeguards" \
    "Found patterns where error handlers may expose internal data. Stack traces and detailed error messages can leak personal data." \
    "Sanitize error responses. Never expose stack traces or internal data to end users in production." \
    "$ERR_LEAK"
else
  pass "D8" "No obvious data leakage in error responses" "Section 7c"
fi

# --- D9: No secure session config ---
echo "  [D9] Checking for secure session configuration..." >&2
SESSION_USE=$(search_code 'session\|cookie\|express-session\|flask-session\|cookie_jar')
SECURE_SESSION=$(search_code 'httpOnly\|HttpOnly\|secure.*cookie\|SameSite\|session.*secure\|cookie.*secure\|session_config\|SESSION_COOKIE_SECURE\|SESSION_COOKIE_HTTPONLY')

if [ -n "$SESSION_USE" ] && [ -z "$SECURE_SESSION" ]; then
  finding "MEDIUM" "D9" "No secure session configuration" \
    "Section 7c — Security safeguards" \
    "Session/cookie handling was found but no secure session flags (HttpOnly, Secure, SameSite) were detected." \
    "Configure sessions with HttpOnly, Secure, and SameSite flags." \
    ""
elif [ -z "$SESSION_USE" ]; then
  pass "D9" "No session handling detected (N/A)" "Section 7c"
else
  pass "D9" "Secure session configuration found" "Section 7c"
fi

# --- D10: No rate limiting ---
echo "  [D10] Checking for rate limiting..." >&2
RATE_LIMIT=$(search_code_ext 'rate.limit|rateLimit|throttle|rate_limit|RateLimiter|express-rate-limit|django-ratelimit|rack-throttle|rate_limiter')

if [ -z "$RATE_LIMIT" ]; then
  finding "MEDIUM" "D10" "No rate limiting detected" \
    "Section 7c — Security safeguards" \
    "No rate limiting patterns were found. Without rate limiting, personal data endpoints are vulnerable to bulk extraction." \
    "Add rate limiting to personal data endpoints to prevent bulk extraction." \
    ""
else
  pass "D10" "Rate limiting patterns found" "Section 7c"
fi

# ============================================================
# SECTION E: Breach Notification (Section 7d)
# ============================================================
echo ""
echo "## Section E: Breach Notification"
echo "*(DPDPA Section 7d)*"

# --- E1: No breach detection ---
echo "  [E1] Checking for breach detection..." >&2
BREACH_DET=$(search_all_ext 'breach.*detect|intrusion.*detect|anomaly|security.*monitor|security.*alert|ids|waf|fail2ban|ossec')

if [ -z "$BREACH_DET" ]; then
  finding "HIGH" "E1" "No breach detection mechanism found" \
    "Section 7d — Breach notification" \
    "No breach or intrusion detection patterns were found. Organizations must detect and respond to personal data breaches." \
    "Implement breach/intrusion detection. Monitor for unauthorized access to personal data." \
    ""
else
  pass "E1" "Breach detection patterns found" "Section 7d"
fi

# --- E2: No Board notification mechanism ---
echo "  [E2] Checking for Board notification mechanism..." >&2
BOARD_NOTIF=$(search_code_ext 'notify.*board|board.*notif|breach.*report|report.*breach|incident.*report|data_protection_board|dpb_notif')

if [ -z "$BOARD_NOTIF" ]; then
  finding "HIGH" "E2" "No Data Protection Board notification mechanism" \
    "Section 7d — Notify the Board" \
    "No mechanism to notify the Data Protection Board of India about breaches was found. DPDPA mandates notification to the Board." \
    "Implement mechanism to notify Data Protection Board of India of breaches. See implementation-patterns.md S3." \
    ""
else
  pass "E2" "Board notification mechanism found" "Section 7d"
fi

# --- E3: No Data Principal notification ---
echo "  [E3] Checking for Data Principal breach notification..." >&2
USER_NOTIF=$(search_code_ext 'notify.*user.*breach|breach.*email|breach.*notif.*user|user.*breach.*alert|notify.*affected|notifyDataPrincipals')

if [ -z "$USER_NOTIF" ]; then
  finding "HIGH" "E3" "No Data Principal breach notification mechanism" \
    "Section 7d — Notify affected Data Principals" \
    "No mechanism to notify affected users of data breaches was found. DPDPA mandates notification to each affected Data Principal." \
    "Implement mechanism to notify affected users of data breaches. See implementation-patterns.md S3." \
    ""
else
  pass "E3" "Data Principal breach notification found" "Section 7d"
fi

# --- E4: No incident response plan ---
echo "  [E4] Checking for incident response plan..." >&2
INCIDENT_PLAN=$(search_all_ext 'incident.*response|runbook|playbook|on.call|escalation|incident.*plan')

if [ -z "$INCIDENT_PLAN" ]; then
  finding "MEDIUM" "E4" "No incident response plan found" \
    "Section 7d — Breach response" \
    "No incident response plan, runbook, or escalation references were found." \
    "Document an incident response plan. See organizational-guidelines.md S4." \
    ""
else
  pass "E4" "Incident response plan references found" "Section 7d"
fi

# --- E5: No breach severity classification ---
echo "  [E5] Checking for breach severity classification..." >&2
BREACH_SEV=$(search_code_ext 'breach.*severity|breach.*level|incident.*class|incident.*severity|risk.*rating|breach.*category|breach.*tier')

if [ -z "$BREACH_SEV" ]; then
  finding "LOW" "E5" "No breach severity classification" \
    "Section 7d — Breach assessment" \
    "No breach severity classification patterns were found. Severity classification helps determine notification urgency." \
    "Implement breach severity classification to determine notification urgency." \
    ""
else
  pass "E5" "Breach severity classification found" "Section 7d"
fi

# ============================================================
# SECTION F: Children's Data Protection (Section 8)
# ============================================================
echo ""
echo "## Section F: Children's Data Protection"
echo "*(DPDPA Section 8)*"

# --- F1: No age verification ---
echo "  [F1] Checking for age verification..." >&2
AGE_VERIF=$(search_code_ext 'age.*verif|date.*birth|dob|isChild|is_child|age_gate|ageGate|minAge|min_age|under.*18|verify.*age|check.*age|birth.*date')

if [ -z "$AGE_VERIF" ]; then
  finding "MEDIUM" "F1" "No age verification mechanism found" \
    "Section 8 — Children's data protection" \
    "No age verification patterns were detected. If your app may be used by children (under 18), you need age verification." \
    "Implement age verification before processing children's data (under 18). See implementation-patterns.md S4." \
    ""
else
  pass "F1" "Age verification mechanism found" "Section 8"
fi

# --- F2: No parental consent ---
echo "  [F2] Checking for parental consent..." >&2
PARENTAL=$(search_code_ext 'parental.*consent|guardian.*consent|parent.*verif|guardian.*verif|parent.*approval|family.*account')

if [ -z "$PARENTAL" ]; then
  finding "MEDIUM" "F2" "No parental consent mechanism found" \
    "Section 8 — Verifiable parental consent" \
    "No parental or guardian consent patterns were found. If your app processes children's data, verifiable parental consent is required." \
    "Obtain verifiable parental/guardian consent for children's data. See implementation-patterns.md S4." \
    ""
else
  pass "F2" "Parental consent mechanism found" "Section 8"
fi

# --- F3: No detrimental processing check ---
echo "  [F3] Advisory: detrimental processing..." >&2
finding "INFO" "F3" "Detrimental processing check advisory" \
  "Section 8 — No detrimental effect on child" \
  "Cannot be verified by automated scan. Manually review that no processing could detrimentally affect a child's well-being." \
  "Manually review: ensure no processing that could detrimentally affect a child's well-being." \
  ""

# --- F4: Tracking/targeting children ---
echo "  [F4] Checking for child tracking exclusion..." >&2
ANALYTICS=$(search_code_ext 'gtag|analytics|mixpanel|amplitude|segment|hotjar|clarity|fbq|pixel')
CHILD_EXCL=$(search_code_ext 'child.*analytics|disable.*track.*child|no.*track.*minor|child.*opt.out|block.*analytics.*child')

if [ -n "$ANALYTICS" ] && [ -z "$CHILD_EXCL" ]; then
  finding "MEDIUM" "F4" "Tracking/analytics without child exclusion" \
    "Section 8 — No tracking or targeting children" \
    "Analytics/tracking is present but no child exclusion mechanisms were found. Tracking and targeted advertising must be disabled for child accounts." \
    "Disable tracking and targeted advertising for child accounts." \
    ""
elif [ -z "$ANALYTICS" ]; then
  pass "F4" "No analytics/tracking detected (N/A)" "Section 8"
else
  pass "F4" "Child tracking exclusion found" "Section 8"
fi

# --- F5: No child account identification ---
echo "  [F5] Checking for child account identification..." >&2
CHILD_FLAG=$(search_schema 'is_child\|is_minor\|child_flag\|account_type.*child\|age_group\|user_type.*minor\|minor_flag')

if [ -z "$CHILD_FLAG" ]; then
  finding "LOW" "F5" "No child account identification in schema" \
    "Section 8 — Identify child accounts" \
    "No child/minor flag patterns were found in schema or model files. Child accounts should be flagged to enforce differential processing rules." \
    "Flag child accounts in your database to enforce differential processing rules." \
    ""
else
  pass "F5" "Child account identification found" "Section 8"
fi

# ============================================================
# SECTION G: Data Principal Rights (Sections 11-14)
# ============================================================
echo ""
echo "## Section G: Data Principal Rights"
echo "*(DPDPA Sections 11-14)*"

# --- G1: No data access/export ---
echo "  [G1] Checking for data access/export..." >&2
DATA_EXP=$(search_code_ext 'export.*data|download.*data|my.*data|data.*portab|dsar|subject.*access|data.*export|getData|get_data|data_access')

if [ -z "$DATA_EXP" ]; then
  finding "MEDIUM" "G1" "No data access or export mechanism found" \
    "Section 11 — Right to access information" \
    "No data export or access request functionality was found. Data Principals have the right to obtain a summary of their personal data." \
    "Implement data access/export endpoint. See implementation-patterns.md S2." \
    ""
else
  pass "G1" "Data access/export mechanism found" "Section 11"
fi

# --- G2: No data correction ---
echo "  [G2] Checking for data correction..." >&2
DATA_CORR=$(search_code_ext 'update.*profile|edit.*profile|correct.*data|modify.*data|profile.*edit|updateProfile|editProfile')

if [ -z "$DATA_CORR" ]; then
  finding "MEDIUM" "G2" "No data correction mechanism found" \
    "Section 12.1a — Right to correction" \
    "No profile update or data correction patterns were found. Data Principals have the right to correct inaccurate or incomplete personal data." \
    "Allow users to correct inaccurate or incomplete personal data." \
    ""
else
  pass "G2" "Data correction mechanism found" "Section 12.1a"
fi

# --- G3: No right to erasure ---
echo "  [G3] Checking for right to erasure..." >&2
ERASURE=$(search_code_ext 'delete.*account|account.*delet|erase.*data|right.*erasure|right.*forget|data.*delet|removeAccount|destroyUser')

if [ -z "$ERASURE" ]; then
  finding "HIGH" "G3" "No right to erasure implementation found" \
    "Section 12.1d — Right to erasure" \
    "No account/data deletion or erasure patterns were found. Data Principals have the right to erasure of their personal data." \
    "Implement account/data deletion. See implementation-patterns.md S2." \
    ""
else
  pass "G3" "Right to erasure implementation found" "Section 12.1d"
fi

# --- G4: No grievance mechanism ---
echo "  [G4] Checking for grievance mechanism..." >&2
GRIEVANCE=$(search_code_ext 'grievance|complaint|dpo|data.protection.officer|grievance_redressal|grievance_officer|raise.*complaint|file.*grievance')

if [ -z "$GRIEVANCE" ]; then
  finding "HIGH" "G4" "No grievance redressal mechanism found" \
    "Section 13 — Right of grievance redressal" \
    "No grievance or complaint handling patterns were found. Data Principals must have readily available means of grievance redressal." \
    "Implement grievance redressal mechanism. See implementation-patterns.md S2." \
    ""
else
  pass "G4" "Grievance mechanism found" "Section 13"
fi

# --- G5: No nomination mechanism ---
echo "  [G5] Checking for nomination mechanism..." >&2
NOMINATION=$(search_code 'nominee\|nominate\|successor\|estate\|next.*of.*kin\|death.*account\|incapacit')

if [ -z "$NOMINATION" ]; then
  finding "INFO" "G5" "No nomination mechanism found" \
    "Section 14 — Nomination" \
    "No nomination patterns were found. DPDPA allows Data Principals to nominate someone to exercise rights in case of death or incapacity." \
    "Consider allowing users to nominate someone to exercise rights in case of death/incapacity." \
    ""
else
  pass "G5" "Nomination mechanism found" "Section 14"
fi

# --- G6: No rights request tracking ---
echo "  [G6] Checking for rights request tracking..." >&2
RIGHTS_TRACK=$(search_code_ext 'dsar.*status|request.*status|sla.*track|response.*deadline|days.*remaining|request.*due|rights.*track|request_tracker')

if [ -z "$RIGHTS_TRACK" ]; then
  finding "LOW" "G6" "No rights request tracking" \
    "Sections 11-14 — Response deadlines" \
    "No DSAR/request tracking or SLA monitoring patterns were found. Rights requests must be responded to within prescribed deadlines." \
    "Track response times for rights requests to meet prescribed deadlines." \
    ""
else
  pass "G6" "Rights request tracking found" "Sections 11-14"
fi

# ============================================================
# SECTION H: Cross-Border Transfer (Section 16)
# ============================================================
echo ""
echo "## Section H: Cross-Border Transfer"
echo "*(DPDPA Section 16)*"

# --- H1: Data flow mapping ---
echo "  [H1] Advisory: data flow mapping..." >&2
finding "INFO" "H1" "Data flow mapping advisory" \
  "Section 16 — Transfer outside India" \
  "Cannot be fully verified by automated scan. Document all locations where personal data is stored or processed, including third-party cloud services." \
  "Document all locations where personal data is stored/processed, including third-party services." \
  ""

# --- H2: No transfer controls ---
echo "  [H2] Checking for transfer controls..." >&2
TRANSFER=$(search_code_ext 'data.*residency|region.*restrict|geo.*restrict|country.*block|allowed.*countries|transfer.*restrict|data.*locali')

if [ -z "$TRANSFER" ]; then
  finding "LOW" "H2" "No data transfer controls found" \
    "Section 16 — Restricted countries" \
    "No data residency or transfer restriction patterns were found. Transfer of personal data to countries blocked by Central Government notification must be restricted." \
    "Implement mechanisms to restrict data transfer to countries blocked by Central Government notification." \
    ""
else
  pass "H2" "Data transfer control patterns found" "Section 16"
fi

# --- H3: Third-party processor location ---
echo "  [H3] Advisory: third-party processor location..." >&2
finding "INFO" "H3" "Third-party processor location advisory" \
  "Section 16 — Processor jurisdictions" \
  "Cannot be verified by automated scan. Document the geographic locations of all third-party Data Processors (cloud providers, SaaS, analytics services)." \
  "Document locations of all third-party Data Processors (cloud providers, SaaS, analytics)." \
  ""

# ============================================================
# SECTION I: Data Processor Oversight (Section 7.2)
# ============================================================
echo ""
echo "## Section I: Data Processor Oversight"
echo "*(DPDPA Section 7.2)*"

# --- I1: Processor agreements ---
echo "  [I1] Advisory: processor agreements..." >&2
finding "INFO" "I1" "Processor agreements advisory" \
  "Section 7.2 — Data Processor obligations" \
  "Cannot be verified by automated scan. Ensure Data Processing Agreements (DPAs) exist with all third-party processors." \
  "Ensure Data Processing Agreements exist with all processors. See organizational-guidelines.md S3." \
  ""

# --- I2: Processor data minimization ---
echo "  [I2] Advisory: processor data minimization..." >&2
THIRD_PARTY=$(search_code 'stripe\|twilio\|sendgrid\|mailchimp\|intercom\|zendesk\|firebase\|supabase\|aws-sdk\|azure')
if [ -n "$THIRD_PARTY" ]; then
  finding "INFO" "I2" "Third-party processors detected — review data sharing" \
    "Section 7.2 — Processor data minimization" \
    "Third-party service integrations were found. Review the data sent to each processor to ensure only necessary data is shared." \
    "Review data sent to third-party processors. Share only what is necessary." \
    "$THIRD_PARTY"
else
  finding "INFO" "I2" "Processor data minimization advisory" \
    "Section 7.2 — Processor data minimization" \
    "No common third-party SDKs were detected, but review any external service integrations to ensure data minimization." \
    "Review data sent to third-party processors. Share only what is necessary." \
    ""
fi

# ============================================================
# SECTION J: Consent Manager Integration (Section 4.7)
# ============================================================
echo ""
echo "## Section J: Consent Manager Integration"
echo "*(DPDPA Section 4.7)*"

# --- J1: Consent Manager support ---
echo "  [J1] Checking for Consent Manager integration..." >&2
CMP=$(search_all_ext 'consent.*manager|cmp|onetrust|cookiebot|trustarc|quantcast|cookieyes|iubenda|consent.*platform')

if [ -n "$CMP" ]; then
  finding "INFO" "J1" "Consent Manager detected — verify Board registration" \
    "Section 4.7 — Consent Manager" \
    "Consent Manager patterns were detected. If using a registered Consent Manager, verify its registration with the Board (when registration is established)." \
    "If using a Consent Manager, verify registration with the Board (when registration is established)." \
    "$CMP"
else
  finding "INFO" "J1" "No Consent Manager integration detected" \
    "Section 4.7 — Consent Manager" \
    "No Consent Manager platform was detected. When available, consider integrating a Board-registered Consent Manager." \
    "If using a Consent Manager, verify registration with the Board (when registration is established)." \
    ""
fi

# ============================================================
# SECTION K: Legitimate Uses (Section 6)
# ============================================================
echo ""
echo "## Section K: Legitimate Uses"
echo "*(DPDPA Section 6)*"

# --- K1: Voluntary data repurposing ---
echo "  [K1] Advisory: voluntary data repurposing..." >&2
PURPOSE_LIM=$(search_code_ext 'purpose_limitation|purpose.*restrict|original.*purpose|repurpose|secondary.*use')
if [ -n "$PURPOSE_LIM" ]; then
  pass "K1" "Purpose limitation patterns found" "Section 6"
else
  finding "INFO" "K1" "Voluntary data repurposing advisory" \
    "Section 6 — Legitimate uses" \
    "No purpose limitation patterns were found. Voluntarily provided data may only be used for the stated purpose." \
    "Voluntarily provided data may only be used for the stated purpose. Do not repurpose without consent." \
    ""
fi

# --- K2: State function processing ---
echo "  [K2] Advisory: state function processing..." >&2
finding "INFO" "K2" "State function processing advisory" \
  "Section 6 — State functions" \
  "If processing personal data for State functions (subsidies, benefits, licenses, permits), document the statutory basis." \
  "If processing for State functions (subsidies, benefits, licenses), document the statutory basis." \
  ""

# --- K3: Legal obligation processing ---
echo "  [K3] Checking for legal hold mechanisms..." >&2
LEGAL_HOLD=$(search_code_ext 'legal_hold|court.*order|regulatory.*hold|statutory.*retention|legal.*preserv|litigation.*hold')

if [ -n "$LEGAL_HOLD" ]; then
  finding "INFO" "K3" "Legal hold mechanisms detected" \
    "Section 6 — Legal obligations" \
    "Legal hold or statutory retention patterns were found. Ensure these are properly documented and that deletion is suspended only as required." \
    "Document processing done under legal obligations. Implement legal holds to prevent deletion during proceedings." \
    "$LEGAL_HOLD"
else
  finding "INFO" "K3" "Legal obligation processing advisory" \
    "Section 6 — Legal obligations" \
    "No legal hold or statutory retention patterns were found. If processing under legal obligations, implement and document legal holds." \
    "Document processing done under legal obligations. Implement legal holds to prevent deletion during proceedings." \
    ""
fi

# ============================================================
# SUMMARY
# ============================================================
FINDINGS=$((CRITICAL + HIGH + MEDIUM + LOW + INFO))

if [ "$TOTAL" -gt 0 ]; then
  SCORE=$(( (PASS * 100) / TOTAL ))
else
  SCORE=0
fi

echo ""
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
echo "| Pass | $PASS |"
echo "| **Total Checks** | **$TOTAL** |"
echo ""
echo "**Compliance Score: ${SCORE}%** (${PASS} passed out of ${TOTAL} checks)"
echo ""
echo "| Score | Rating |"
echo "|-------|--------|"
echo "| 90-100% | Strong compliance posture |"
echo "| 70-89% | Moderate — address Critical and High items |"
echo "| 50-69% | Weak — significant remediation needed |"
echo "| Below 50% | Critical — substantial compliance risk |"
echo ""

if [ "$SCORE" -ge 90 ]; then
  echo "**Strong compliance posture detected.**"
elif [ "$SCORE" -ge 70 ]; then
  echo "**Moderate compliance. Focus on Critical and High severity items first.**"
elif [ "$SCORE" -ge 50 ]; then
  echo "**Weak compliance posture. Significant remediation needed.**"
else
  echo "**Critical compliance risk. Immediate attention required.**"
fi

echo ""
echo "Run a full manual audit using \`references/audit-checklist.md\` for comprehensive coverage."
echo ""
echo "---"
echo "*Generated by DPDPA Compliance Scanner v2.0 | $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')*"

} > "$REPORT_FILE"

echo "" >&2
echo "Scan complete. Report saved to: $REPORT_FILE" >&2
echo "Checks: $TOTAL | Pass: $PASS | Findings: $((CRITICAL + HIGH + MEDIUM + LOW + INFO))" >&2
echo "Critical: $CRITICAL | High: $HIGH | Medium: $MEDIUM | Low: $LOW | Info: $INFO" >&2
echo "Compliance Score: ${SCORE}%" >&2
