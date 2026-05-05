#!/usr/bin/env bash
set -u

MODE="strict"
PROJECT_DIR="$PWD"
OUTPUT_FILE=""
MAX_HITS=25
REQUIRE_LSP=0
RUN_BRAKEMAN=1

if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  C_RESET="\033[0m"
  C_INFO="\033[36m"
  C_OK="\033[32m"
  C_WARN="\033[33m"
  C_ERR="\033[31m"
else
  C_RESET=""
  C_INFO=""
  C_OK=""
  C_WARN=""
  C_ERR=""
fi

usage() {
  cat <<'USAGE'
Usage: run_security_audit.sh [options]

Run a focused Rails security audit with blocker/warn/pass outcomes.

Options:
  --project-dir DIR   Rails project root (default: current directory)
  --mode MODE         strict | advisory (default: strict)
  --output-file FILE  Write markdown report to FILE
  --max-hits N        Max findings shown per check (default: 25)
  --skip-brakeman     Skip Brakeman execution
  --require-lsp       Fail if ENABLE_LSP_TOOL is not set to 1
  -h, --help          Show this help

Examples:
  ./scripts/run_security_audit.sh
  ./scripts/run_security_audit.sh --project-dir /path/to/rails-app --mode advisory
  ./scripts/run_security_audit.sh --output-file tmp/security-report.md --skip-brakeman
USAGE
}

log_info() { printf "%b[INFO]%b %s\n" "$C_INFO" "$C_RESET" "$1"; }
log_ok() { printf "%b[PASS]%b %s\n" "$C_OK" "$C_RESET" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_WARN" "$C_RESET" "$1"; }
log_err() { printf "%b[FAIL]%b %s\n" "$C_ERR" "$C_RESET" "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --max-hits)
      MAX_HITS="$2"
      shift 2
      ;;
    --skip-brakeman)
      RUN_BRAKEMAN=0
      shift
      ;;
    --require-lsp)
      REQUIRE_LSP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_err "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

if [ "$MODE" != "strict" ] && [ "$MODE" != "advisory" ]; then
  log_err "Invalid mode: $MODE (expected strict or advisory)"
  exit 2
fi

if ! [ "$MAX_HITS" -eq "$MAX_HITS" ] 2>/dev/null; then
  log_err "--max-hits must be an integer."
  exit 2
fi

if [ ! -d "$PROJECT_DIR" ]; then
  log_err "Project directory not found: $PROJECT_DIR"
  exit 2
fi

cd "$PROJECT_DIR" || exit 2

if [ ! -f "Gemfile" ]; then
  log_warn "Gemfile not found. Results may be less meaningful outside a Rails app root."
fi

if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  if [ "$REQUIRE_LSP" -eq 1 ]; then
    log_err "ENABLE_LSP_TOOL is not set to 1 and --require-lsp is enabled."
    exit 2
  fi
  log_warn "ENABLE_LSP_TOOL is not set to 1. LSP-enabled sessions are strongly recommended for security analysis."
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_DIR/tmp/rails-security-${RUN_ID}"
mkdir -p "$LOG_DIR"
log_info "Logs: $LOG_DIR"

BLOCKER_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

BLOCKERS_FILE="$LOG_DIR/blockers.txt"
WARNS_FILE="$LOG_DIR/warnings.txt"
PASSES_FILE="$LOG_DIR/passes.txt"
BRAKEMAN_LOG="$LOG_DIR/brakeman.log"
BRAKEMAN_JSON="$LOG_DIR/brakeman.json"

touch "$BLOCKERS_FILE" "$WARNS_FILE" "$PASSES_FILE"

path_exists() {
  [ -e "$1" ]
}

run_search() {
  local pattern="$1"
  shift
  local paths=()
  local p

  for p in "$@"; do
    if path_exists "$p"; then
      paths+=("$p")
    fi
  done

  if [ ${#paths[@]} -eq 0 ]; then
    return 0
  fi

  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading -S "$pattern" "${paths[@]}" 2>/dev/null | head -n "$MAX_HITS" || true
  else
    grep -RInE "$pattern" "${paths[@]}" 2>/dev/null | head -n "$MAX_HITS" || true
  fi
}

add_blocker() {
  BLOCKER_COUNT=$((BLOCKER_COUNT + 1))
  {
    echo "### $1"
    echo
    echo "Guidance: $2"
    echo
    echo "Findings:"
    if [ -n "$3" ]; then
      echo "$3"
    else
      echo "(no line-level hits captured)"
    fi
    echo
  } >>"$BLOCKERS_FILE"
  log_err "$1"
}

add_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  {
    echo "### $1"
    echo
    echo "Guidance: $2"
    echo
    echo "Findings:"
    if [ -n "$3" ]; then
      echo "$3"
    else
      echo "(no line-level hits captured)"
    fi
    echo
  } >>"$WARNS_FILE"
  log_warn "$1"
}

add_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "- $1" >>"$PASSES_FILE"
  log_ok "$1"
}

run_brakeman_check() {
  if [ "$RUN_BRAKEMAN" -ne 1 ]; then
    add_warn "Brakeman not run" "Run without --skip-brakeman for deeper static analysis coverage." "Skipped by flag"
    return 0
  fi

  if ! command -v bundle >/dev/null 2>&1; then
    add_warn "Brakeman not run" "Install bundler/ruby toolchain in this environment to run Brakeman." "bundle command not found"
    return 0
  fi

  if bundle exec brakeman -q -f json -o "$BRAKEMAN_JSON" >"$BRAKEMAN_LOG" 2>&1; then
    :
  else
    # Brakeman may return non-zero when warnings exist; continue if JSON produced.
    if [ ! -s "$BRAKEMAN_JSON" ]; then
      add_warn "Brakeman execution failed" "Check brakeman installation and app bootability." "See $BRAKEMAN_LOG"
      return 0
    fi
  fi

  if ! [ -s "$BRAKEMAN_JSON" ]; then
    add_warn "Brakeman report missing" "Ensure Brakeman can produce JSON output." "Expected: $BRAKEMAN_JSON"
    return 0
  fi

  local counts
  counts="$(ruby -rjson -e '
    data = JSON.parse(File.read(ARGV[0]))
    warnings = data.fetch("warnings", [])
    high = warnings.count { |w| w["confidence"].to_s.casecmp("High").zero? }
    med = warnings.count { |w| w["confidence"].to_s.casecmp("Medium").zero? }
    low = warnings.count { |w| w["confidence"].to_s.casecmp("Weak").zero? || w["confidence"].to_s.casecmp("Low").zero? }
    puts [high, med, low, warnings.length].join("|")
  ' "$BRAKEMAN_JSON" 2>/dev/null || true)"

  if [ -z "$counts" ]; then
    add_warn "Brakeman summary unavailable" "Review $BRAKEMAN_JSON manually." "JSON parse failed"
    return 0
  fi

  local high med low total
  IFS='|' read -r high med low total <<EOF_COUNTS
$counts
EOF_COUNTS

  local detail="high=$high medium=$med low_or_weak=$low total=$total (report: $BRAKEMAN_JSON)"

  if [ "$high" -gt 0 ]; then
    add_blocker "Brakeman high-confidence warnings detected" "Address high-confidence findings before merge/release." "$detail"
  elif [ "$med" -gt 0 ]; then
    add_warn "Brakeman medium-confidence warnings detected" "Review and triage medium-confidence findings." "$detail"
  else
    add_pass "Brakeman did not report high/medium confidence warnings."
  fi
}

log_info "Running security checks..."

run_brakeman_check

hits_sql_interp="$(run_search '(where|find_by|find_by_sql|order|group|having|joins|pluck)\s*\([^)]*#\{' app lib)"
if [ -n "$hits_sql_interp" ]; then
  add_blocker \
    "Possible SQL interpolation with user-controlled input" \
    "Use hash conditions/placeholders and allowlists for dynamic order clauses." \
    "$hits_sql_interp"
else
  add_pass "No obvious SQL interpolation patterns detected in app/lib."
fi

hits_cmd_interp="$(run_search '(system|exec|spawn|Open3\.(capture2|capture2e|capture3|popen2|popen3))\s*\([^)]*#\{' app lib)"
hits_cmd_backticks="$(run_search '`[^`]*#\{[^`]*`|%x\([^)]*#\{[^)]*\)' app lib)"
hits_eval="$(run_search '\b(eval|instance_eval|class_eval)\s*\(' app lib)"
combined_cmd_hits="$(printf "%s\n%s\n%s" "$hits_cmd_interp" "$hits_cmd_backticks" "$hits_eval" | sed '/^$/d')"
if [ -n "$combined_cmd_hits" ]; then
  add_blocker \
    "Possible command/code injection vectors" \
    "Use array-argument command execution, strict allowlists, and avoid eval-family methods." \
    "$combined_cmd_hits"
else
  add_pass "No obvious command/code injection patterns detected."
fi

hits_xss="$(run_search '\b(html_safe|raw\s*\()' app/views app/helpers app/components)"
if [ -n "$hits_xss" ]; then
  add_blocker \
    "Potential XSS exposure via html_safe/raw" \
    "Prefer default escaping and explicit sanitize allowlists for trusted rich content only." \
    "$hits_xss"
else
  add_pass "No html_safe/raw usage detected in views/helpers/components."
fi

hits_skip_csrf="$(run_search 'skip_before_action\s+:verify_authenticity_token' app/controllers)"
if [ -n "$hits_skip_csrf" ]; then
  hits_skip_csrf_non_api="$(printf "%s\n" "$hits_skip_csrf" | grep -Evi '/api/|::Api|Api::' || true)"
  hits_skip_csrf_api="$(printf "%s\n" "$hits_skip_csrf" | grep -Ei '/api/|::Api|Api::' || true)"

  if [ -n "$hits_skip_csrf_non_api" ]; then
    add_blocker \
      "CSRF verification skipped in non-API controller context" \
      "Keep CSRF enabled for cookie/session-authenticated flows; scope skipping to stateless API controllers only." \
      "$hits_skip_csrf_non_api"
  fi

  if [ -n "$hits_skip_csrf_api" ]; then
    add_warn \
      "CSRF verification skipped in API controller context" \
      "Confirm endpoint is truly stateless and protected by token auth, not cookie session auth." \
      "$hits_skip_csrf_api"
  fi
else
  add_pass "No CSRF-skip patterns detected in controllers."
fi

layout_file="app/views/layouts/application.html.erb"
if [ -f "$layout_file" ]; then
  if grep -q "csrf_meta_tags" "$layout_file"; then
    add_pass "CSRF meta tags present in default application layout."
  else
    add_warn \
      "Missing csrf_meta_tags in application layout" \
      "Add csrf_meta_tags so JS requests can include authenticity tokens." \
      "$layout_file"
  fi
else
  add_warn \
    "Default application layout not found for CSRF check" \
    "Confirm csrf_meta_tags are present in the active layout." \
    "$layout_file"
fi

if [ -f "config/initializers/content_security_policy.rb" ]; then
  hits_csp_inline="$(run_search 'unsafe-inline' config/initializers/content_security_policy.rb)"
  if [ -n "$hits_csp_inline" ]; then
    add_warn \
      "CSP allows unsafe-inline" \
      "Prefer nonce/hash-based policies over unsafe-inline for scripts." \
      "$hits_csp_inline"
  else
    add_pass "CSP initializer detected without unsafe-inline patterns."
  fi
else
  add_warn \
    "Missing content_security_policy initializer" \
    "Add CSP headers for defense-in-depth against XSS." \
    "config/initializers/content_security_policy.rb"
fi

hits_attachments="$(run_search '\bhas_(one|many)_attached\b' app/models)"
if [ -n "$hits_attachments" ]; then
  hits_upload_validations="$(run_search 'validates\s+:[a-zA-Z0-9_]+.*(content_type|size)' app/models)"
  if [ -z "$hits_upload_validations" ]; then
    add_warn \
      "ActiveStorage attachments detected without explicit type/size validations" \
      "Add model-level validation for allowed content types and size limits." \
      "$hits_attachments"
  else
    add_pass "ActiveStorage attachments and validation patterns detected."
  fi
else
  add_pass "No ActiveStorage attachment declarations detected in app/models."
fi

if [ -f "config/initializers/session_store.rb" ]; then
  hits_session_flags="$(run_search 'same_site:|httponly:|secure:' config/initializers/session_store.rb)"
  if [ -z "$hits_session_flags" ]; then
    add_warn \
      "Session store found without explicit secure cookie flags" \
      "Set same_site, secure, and httponly explicitly for session cookies." \
      "config/initializers/session_store.rb"
  else
    add_pass "Session store hardening flags detected in initializer."
  fi
else
  add_warn \
    "Session store initializer missing" \
    "Confirm cookie session security flags in environment/session configuration." \
    "config/initializers/session_store.rb"
fi

hits_send_file_params="$(run_search 'send_file\s+.*params\[' app/controllers)"
if [ -n "$hits_send_file_params" ]; then
  add_warn \
    "Potential path traversal risk in send_file with params" \
    "Validate and constrain paths using expand_path plus allowed base directory checks." \
    "$hits_send_file_params"
else
  add_pass "No obvious send_file params[...] path patterns detected."
fi

overall="PASS"
if [ "$BLOCKER_COUNT" -gt 0 ]; then
  overall="FAIL"
elif [ "$WARN_COUNT" -gt 0 ]; then
  overall="WARN"
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$LOG_DIR/00-summary.md"
fi

{
  echo "# Rails Security Audit"
  echo
  echo "- Mode: $MODE"
  echo "- Project: $PROJECT_DIR"
  echo "- Overall: $overall"
  echo
  echo "## Scoreboard"
  echo
  echo "- Blockers: $BLOCKER_COUNT"
  echo "- Warnings: $WARN_COUNT"
  echo "- Pass checks: $PASS_COUNT"
  echo
  echo "## Blockers"
  echo
  if [ -s "$BLOCKERS_FILE" ]; then
    cat "$BLOCKERS_FILE"
  else
    echo "- None"
    echo
  fi

  echo "## Warnings"
  echo
  if [ -s "$WARNS_FILE" ]; then
    cat "$WARNS_FILE"
  else
    echo "- None"
    echo
  fi

  echo "## Passed Checks"
  echo
  if [ -s "$PASSES_FILE" ]; then
    cat "$PASSES_FILE"
  else
    echo "- None"
    echo
  fi

  echo "## Artifacts"
  echo
  echo "- Log directory: $LOG_DIR"
  if [ -s "$BRAKEMAN_JSON" ]; then
    echo "- Brakeman JSON: $BRAKEMAN_JSON"
  fi
  if [ -s "$BRAKEMAN_LOG" ]; then
    echo "- Brakeman log: $BRAKEMAN_LOG"
  fi
} >"$OUTPUT_FILE"

printf "\n"
log_info "Execution Summary (Rails Security)"
printf "  - Blockers:   %s\n" "$BLOCKER_COUNT"
printf "  - Warnings:   %s\n" "$WARN_COUNT"
printf "  - Pass checks:%s\n" "$PASS_COUNT"
printf "  - Overall:    %s\n" "$overall"
log_info "Summary report: $OUTPUT_FILE"

if [ "$MODE" = "strict" ] && [ "$overall" = "FAIL" ]; then
  exit 1
fi

exit 0
