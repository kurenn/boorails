#!/usr/bin/env bash
set -u

MODE="strict"
PROJECT_DIR="$PWD"
OUTPUT_FILE=""
MAX_HITS=20
REQUIRE_LSP=0

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
  cat <<'EOF'
Usage: safety_check.sh [options]

Run a Rails implementation safety audit and return blocker/warn/pass status.

Options:
  --project-dir DIR   Rails project root (default: current directory)
  --mode MODE         strict | advisory (default: strict)
  --output-file FILE  Write markdown report to FILE
  --max-hits N        Max findings shown per check (default: 20)
  --require-lsp       Fail if ENABLE_LSP_TOOL is not set to 1
  -h, --help          Show this help

Examples:
  ./scripts/safety_check.sh
  ./scripts/safety_check.sh --project-dir /path/to/rails-app
  ./scripts/safety_check.sh --mode advisory --output-file tmp/safety-report.md
EOF
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
  log_warn "Gemfile not found. Checks may be less meaningful outside a Rails app root."
fi
if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  if [ "$REQUIRE_LSP" -eq 1 ]; then
    log_err "ENABLE_LSP_TOOL is not set to 1 and --require-lsp is enabled."
    exit 2
  fi
  log_warn "ENABLE_LSP_TOOL is not set to 1. LSP-enabled sessions are strongly recommended for symbol-level safety checks."
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_DIR/tmp/rails-safety-check-${RUN_ID}"
mkdir -p "$LOG_DIR"
log_info "Logs: $LOG_DIR"

BLOCKER_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

BLOCKERS_FILE="$LOG_DIR/blockers.txt"
WARNS_FILE="$LOG_DIR/warnings.txt"
PASSES_FILE="$LOG_DIR/passes.txt"
touch "$BLOCKERS_FILE" "$WARNS_FILE" "$PASSES_FILE"

path_exists() {
  [ -e "$1" ]
}

run_search() {
  # $1 pattern, $2.. paths
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
  # $1 title, $2 guidance, $3 hits
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
  # $1 title, $2 guidance, $3 hits
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
  # $1 message
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "- $1" >>"$PASSES_FILE"
  log_ok "$1"
}

log_info "Running static safety scans..."

# Blocker: SQL interpolation in ActiveRecord query methods.
hits_sql_interp="$(run_search '(where|find_by|find_by_sql|order|group|having|joins)\s*\([^)]*#\{' app lib)"
if [ -n "$hits_sql_interp" ]; then
  add_blocker \
    "Possible SQL interpolation with user-controlled input" \
    "Use parameterized queries (`where(name: value)` or placeholders) and avoid string interpolation." \
    "$hits_sql_interp"
else
  add_pass "No SQL interpolation patterns detected in app/lib."
fi

# Blocker: command injection vectors.
hits_cmd_interp="$(run_search '(system|exec|spawn)\s*\([^)]*#\{' app lib)"
hits_cmd_backticks="$(run_search '`[^`]*#\{[^`]*`' app lib)"
hits_eval="$(run_search '\b(eval|instance_eval|class_eval)\s*\(' app lib)"
combined_cmd_hits="$(printf "%s\n%s\n%s" "$hits_cmd_interp" "$hits_cmd_backticks" "$hits_eval" | sed '/^$/d')"
if [ -n "$combined_cmd_hits" ]; then
  add_blocker \
    "Possible command/code injection vectors" \
    "Avoid interpolated shell commands and eval-family methods; prefer safe APIs and strict allowlists." \
    "$combined_cmd_hits"
else
  add_pass "No obvious command/code injection patterns detected."
fi

# Blocker: risky migration operations.
hits_risky_migrations="$(run_search '\b(remove_column|change_column|rename_column|drop_table)\b' db/migrate)"
if [ -n "$hits_risky_migrations" ]; then
  add_blocker \
    "Potentially risky migration operations detected" \
    "Review for zero-downtime safety, backfill strategy, lock impact, and rollback plan before merge." \
    "$hits_risky_migrations"
else
  add_pass "No risky migration operations detected in db/migrate."
fi

# Blocker: dangerous rendering helpers.
hits_xss="$(run_search '\b(html_safe|raw\s*\()' app/views app/helpers app/components)"
if [ -n "$hits_xss" ]; then
  add_blocker \
    "Potential XSS exposure via html_safe/raw" \
    "Prefer default escaping and `sanitize` with explicit allowlists when rich content is required." \
    "$hits_xss"
else
  add_pass "No html_safe/raw usage detected in views/helpers/components."
fi

# Blocker: open redirect patterns.
hits_redirect="$(run_search 'redirect_to\s+params\[' app/controllers)"
if [ -n "$hits_redirect" ]; then
  add_blocker \
    "Potential open redirect via redirect_to params" \
    "Use an allowlist of redirect targets or validated URL helpers." \
    "$hits_redirect"
else
  add_pass "No obvious redirect_to params[...] patterns detected."
fi

# Warn: controllers with create/update and no permit.
controller_warns=""
if [ -d "app/controllers" ]; then
  while IFS= read -r controller; do
    if rg -q 'def (create|update)' "$controller" 2>/dev/null; then
      if rg -q 'params' "$controller" 2>/dev/null; then
        if ! rg -q '\.permit\s*\(' "$controller" 2>/dev/null; then
          controller_warns="${controller_warns}${controller}: create/update uses params but no .permit found"$'\n'
        fi
      fi
    fi
  done < <(find app/controllers -type f -name '*_controller.rb' | sort)
fi
if [ -n "$controller_warns" ]; then
  add_warn \
    "Possible missing strong parameters in controllers" \
    "Review parameter whitelisting to avoid mass-assignment risk." \
    "$controller_warns"
else
  add_pass "No obvious strong-parameters gaps detected by heuristic check."
fi

# Warn: CSRF tags missing in default layout (if layout exists).
if [ -f "app/views/layouts/application.html.erb" ]; then
  if rg -q 'csrf_meta_tags' app/views/layouts/application.html.erb 2>/dev/null; then
    add_pass "CSRF meta tags present in application layout."
  else
    add_warn \
      "Missing csrf_meta_tags in app/views/layouts/application.html.erb" \
      "Add `csrf_meta_tags` to ensure request forgery protection metadata is available." \
      "app/views/layouts/application.html.erb"
  fi
else
  add_warn \
    "Default application layout not found for CSRF check" \
    "Confirm CSRF metadata is present in the active layout." \
    "app/views/layouts/application.html.erb (missing)"
fi

# Warn: attachment models without obvious validations.
attachment_warns=""
if [ -d "app/models" ]; then
  while IFS= read -r model; do
    if rg -q '(has_one_attached|has_many_attached)' "$model" 2>/dev/null; then
      if ! rg -q 'validates' "$model" 2>/dev/null; then
        attachment_warns="${attachment_warns}${model}: attachment declared without obvious validation"$'\n'
      fi
    fi
  done < <(find app/models -type f -name '*.rb' | sort)
fi
if [ -n "$attachment_warns" ]; then
  add_warn \
    "Attachment declarations without obvious validation" \
    "Validate file type, size, and content constraints for uploads." \
    "$attachment_warns"
else
  add_pass "No obvious attachment validation gaps detected."
fi

# Warn: jobs with side effects lacking explicit idempotency hints.
job_warns=""
if [ -d "app/jobs" ]; then
  while IFS= read -r job; do
    if rg -q 'def perform' "$job" 2>/dev/null; then
      if rg -q '(create!|update!|deliver_now|delete_all|update_all)' "$job" 2>/dev/null; then
        if ! rg -q '(idempot|dedup|unique|find_or_create_by)' "$job" 2>/dev/null; then
          job_warns="${job}: side-effect operations found without explicit idempotency hint"$'\n'"${job_warns}"
        fi
      fi
    fi
  done < <(find app/jobs -type f -name '*.rb' | sort)
fi
if [ -n "$job_warns" ]; then
  add_warn \
    "Background jobs may be non-idempotent" \
    "Add idempotency strategy for retries and duplicate execution safety." \
    "$job_warns"
else
  add_pass "No obvious non-idempotent job patterns detected."
fi

overall="PASS"
if [ "$BLOCKER_COUNT" -gt 0 ]; then
  overall="FAIL"
elif [ "$WARN_COUNT" -gt 0 ]; then
  overall="WARN"
fi

printf "\n"
log_info "Execution Summary (Safety)"
printf "  - Blockers: %s\n" "$BLOCKER_COUNT"
printf "  - Warnings: %s\n" "$WARN_COUNT"
printf "  - Passed checks: %s\n" "$PASS_COUNT"
printf "  - Overall: %s\n" "$overall"

if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  {
    echo "# Rails Implementation Safety Report"
    echo
    echo "- Mode: $MODE"
    echo "- Project: $PROJECT_DIR"
    echo "- Logs: $LOG_DIR"
    echo "- Overall: $overall"
    echo "- Blockers: $BLOCKER_COUNT"
    echo "- Warnings: $WARN_COUNT"
    echo "- Passed checks: $PASS_COUNT"
    echo
    echo "## Passed Checks"
    echo
    cat "$PASSES_FILE"
    echo
    echo "## Blockers"
    echo
    if [ "$BLOCKER_COUNT" -gt 0 ]; then
      cat "$BLOCKERS_FILE"
    else
      echo "None."
    fi
    echo
    echo "## Warnings"
    echo
    if [ "$WARN_COUNT" -gt 0 ]; then
      cat "$WARNS_FILE"
    else
      echo "None."
    fi
  } >"$OUTPUT_FILE"
  log_info "Report written to $OUTPUT_FILE"
fi

if [ "$MODE" = "strict" ] && [ "$BLOCKER_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
