#!/usr/bin/env bash
set -u

MODE="strict"
PROJECT_DIR="$PWD"
OUTPUT_FILE=""
MAX_HITS=25
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
Usage: run_diagnose.sh [options]

Run static root-cause diagnostics for common Rails risks and regressions.

Options:
  --project-dir DIR   Rails project root (default: current directory)
  --mode MODE         strict | advisory (default: strict)
  --output-file FILE  Write markdown report to FILE
  --max-hits N        Max findings shown per check (default: 25)
  --require-lsp       Fail if ENABLE_LSP_TOOL is not set to 1
  -h, --help          Show this help

Examples:
  ./scripts/run_diagnose.sh
  ./scripts/run_diagnose.sh --project-dir /path/to/rails-app
  ./scripts/run_diagnose.sh --mode advisory --output-file tmp/diagnose-report.md
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
  log_warn "Gemfile not found. Diagnostics may be less meaningful outside a Rails app root."
fi
if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  if [ "$REQUIRE_LSP" -eq 1 ]; then
    log_err "ENABLE_LSP_TOOL is not set to 1 and --require-lsp is enabled."
    exit 2
  fi
  log_warn "ENABLE_LSP_TOOL is not set to 1. LSP-enabled sessions are strongly recommended for better symbol-level diagnosis."
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_DIR/tmp/rails-diagnose-${RUN_ID}"
mkdir -p "$LOG_DIR"
log_info "Logs: $LOG_DIR"

HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
PASS_COUNT=0

HIGH_FILE="$LOG_DIR/high_findings.md"
MEDIUM_FILE="$LOG_DIR/medium_findings.md"
LOW_FILE="$LOG_DIR/low_findings.md"
PASS_FILE="$LOG_DIR/passed_checks.md"
touch "$HIGH_FILE" "$MEDIUM_FILE" "$LOW_FILE" "$PASS_FILE"

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

add_finding() {
  # $1 severity, $2 title, $3 guidance, $4 evidence
  local severity="$1"
  local title="$2"
  local guidance="$3"
  local evidence="$4"
  local target_file=""

  case "$severity" in
    HIGH)
      HIGH_COUNT=$((HIGH_COUNT + 1))
      target_file="$HIGH_FILE"
      log_err "$title"
      ;;
    MEDIUM)
      MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
      target_file="$MEDIUM_FILE"
      log_warn "$title"
      ;;
    LOW)
      LOW_COUNT=$((LOW_COUNT + 1))
      target_file="$LOW_FILE"
      log_warn "$title"
      ;;
    *)
      return
      ;;
  esac

  {
    echo "### $title"
    echo
    echo "Guidance: $guidance"
    echo
    echo "Evidence:"
    if [ -n "$evidence" ]; then
      echo "$evidence"
    else
      echo "(no line-level evidence captured)"
    fi
    echo
  } >>"$target_file"
}

add_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "- $1" >>"$PASS_FILE"
  log_ok "$1"
}

log_info "Running diagnostic heuristics..."

# 1) Query composition with all() in controllers (N+1 risk candidate).
hits_all_in_controllers="$(run_search '\.all\b' app/controllers | grep -vE 'includes|preload|eager_load' || true)"
if [ -n "$hits_all_in_controllers" ]; then
  add_finding \
    "MEDIUM" \
    "Controller queries using .all without eager-loading hints" \
    "Review index/listing actions for possible N+1 and loading pressure; consider includes/preload/eager_load." \
    "$hits_all_in_controllers"
else
  add_pass "No obvious .all usage in controllers without eager-loading hints."
fi

# 2) Render loops in views (view-level N+1 candidate).
hits_view_loops="$(run_search '\.each do \|' app/views)"
if [ -n "$hits_view_loops" ]; then
  add_finding \
    "MEDIUM" \
    "View loops detected (potential N+1 candidates)" \
    "Review looped templates for association access that triggers per-row queries." \
    "$hits_view_loops"
else
  add_pass "No enumerable loops detected in app/views."
fi

# 3) Broad rescue patterns can hide root causes.
hits_broad_rescue="$(run_search 'rescue\s*(StandardError|Exception)?\s*=>|^\s*rescue\s*$' app lib)"
if [ -n "$hits_broad_rescue" ]; then
  add_finding \
    "HIGH" \
    "Broad rescue patterns may mask failures" \
    "Rescue specific exceptions and preserve debugging signal with explicit handling and logging context." \
    "$hits_broad_rescue"
else
  add_pass "No broad rescue patterns detected in app/lib."
fi

# 4) High callback density in models increases hidden behavior risk.
callback_density=""
if [ -d "app/models" ]; then
  while IFS= read -r model_file; do
    callback_count="$(rg -n '^\s*(before_|after_|around_)' "$model_file" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$callback_count" -ge 4 ]; then
      callback_density="${callback_density}${model_file}: callbacks=${callback_count}"$'\n'
    fi
  done < <(find app/models -type f -name '*.rb' | sort)
fi
if [ -n "$callback_density" ]; then
  add_finding \
    "MEDIUM" \
    "Models with high callback density detected" \
    "Consider moving orchestration logic to services/interactors for clearer flow and easier debugging." \
    "$callback_density"
else
  add_pass "No models with high callback density detected."
fi

# 5) Large controller files often correlate with mixed responsibilities.
fat_controllers=""
if [ -d "app/controllers" ]; then
  while IFS= read -r controller_file; do
    line_count="$(wc -l < "$controller_file" | tr -d ' ')"
    if [ "$line_count" -ge 260 ]; then
      fat_controllers="${fat_controllers}${controller_file}: lines=${line_count}"$'\n'
    fi
  done < <(find app/controllers -type f -name '*_controller.rb' | sort)
fi
if [ -n "$fat_controllers" ]; then
  add_finding \
    "MEDIUM" \
    "Large controller files detected" \
    "Review for action bloat and extract service/query objects where appropriate." \
    "$fat_controllers"
else
  add_pass "No oversized controller files detected (>=260 lines)."
fi

# 6) Flaky test hints.
hits_sleep_tests="$(run_search '\bsleep\(' spec test)"
if [ -n "$hits_sleep_tests" ]; then
  add_finding \
    "LOW" \
    "sleep() calls found in tests (flakiness risk)" \
    "Replace static sleeps with deterministic waiting/assertion mechanisms." \
    "$hits_sleep_tests"
else
  add_pass "No sleep() calls found in test files."
fi

# 7) Jobs with side effects and no explicit retry/idempotency hints.
job_risk=""
if [ -d "app/jobs" ]; then
  while IFS= read -r job_file; do
    if rg -q 'def perform' "$job_file" 2>/dev/null; then
      if rg -q '(create!|update!|delete_all|update_all|deliver_now)' "$job_file" 2>/dev/null; then
        if ! rg -q '(retry_on|discard_on|idempot|find_or_create_by|upsert)' "$job_file" 2>/dev/null; then
          job_risk="${job_risk}${job_file}: perform has side effects without explicit retry/idempotency hints"$'\n'
        fi
      fi
    fi
  done < <(find app/jobs -type f -name '*.rb' | sort)
fi
if [ -n "$job_risk" ]; then
  add_finding \
    "MEDIUM" \
    "Background job side-effect risk detected" \
    "Add explicit idempotency and retry strategy for job safety under retries and duplicates." \
    "$job_risk"
else
  add_pass "No obvious side-effect job risk patterns detected."
fi

# 8) Debt markers.
hits_todo="$(run_search '\b(TODO|FIXME|HACK)\b' app lib config)"
if [ -n "$hits_todo" ]; then
  add_finding \
    "LOW" \
    "TODO/FIXME/HACK markers found in runtime code" \
    "Track unresolved markers with issue references and ensure they are not hidden production risks." \
    "$hits_todo"
else
  add_pass "No TODO/FIXME/HACK markers found in app/lib/config."
fi

overall="PASS"
if [ "$HIGH_COUNT" -gt 0 ]; then
  overall="FAIL"
elif [ "$MEDIUM_COUNT" -gt 0 ] || [ "$LOW_COUNT" -gt 0 ]; then
  overall="WARN"
fi

printf "\n"
log_info "Execution Summary (Diagnose)"
printf "  - High findings:   %s\n" "$HIGH_COUNT"
printf "  - Medium findings: %s\n" "$MEDIUM_COUNT"
printf "  - Low findings:    %s\n" "$LOW_COUNT"
printf "  - Passed checks:   %s\n" "$PASS_COUNT"
printf "  - Overall:         %s\n" "$overall"

if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  {
    echo "# Rails Diagnose Report"
    echo
    echo "- Mode: $MODE"
    echo "- Project: $PROJECT_DIR"
    echo "- Logs: $LOG_DIR"
    echo "- Overall: $overall"
    echo "- High findings: $HIGH_COUNT"
    echo "- Medium findings: $MEDIUM_COUNT"
    echo "- Low findings: $LOW_COUNT"
    echo "- Passed checks: $PASS_COUNT"
    echo
    echo "## Passed Checks"
    echo
    cat "$PASS_FILE"
    echo
    echo "## High Findings"
    echo
    if [ "$HIGH_COUNT" -gt 0 ]; then
      cat "$HIGH_FILE"
    else
      echo "None."
    fi
    echo
    echo "## Medium Findings"
    echo
    if [ "$MEDIUM_COUNT" -gt 0 ]; then
      cat "$MEDIUM_FILE"
    else
      echo "None."
    fi
    echo
    echo "## Low Findings"
    echo
    if [ "$LOW_COUNT" -gt 0 ]; then
      cat "$LOW_FILE"
    else
      echo "None."
    fi
  } >"$OUTPUT_FILE"
  log_info "Report written to $OUTPUT_FILE"
fi

if [ "$MODE" = "strict" ] && [ "$overall" = "FAIL" ]; then
  exit 1
fi

exit 0
