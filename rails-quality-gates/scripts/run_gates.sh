#!/usr/bin/env bash
set -u

MODE="strict"
PROJECT_DIR="$PWD"
TEST_TARGET=""
RUBOCOP_TARGET=""
PERF_COMMAND=""
OUTPUT_FILE=""
REQUIRE_LSP=0

SKIP_SYNTAX=0
SKIP_LINT=0
SKIP_TESTS=0
SKIP_SECURITY=0
SKIP_PERF=0

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
Usage: run_gates.sh [options]

Run Rails quality gates with a consistent pass/warn/fail summary.

Options:
  --project-dir DIR      Rails project root (default: current directory)
  --mode MODE            strict | advisory (default: strict)
  --test-target TARGET   Focused test target for rspec or rails test
  --rubocop-target PATH  Focused target for rubocop
  --perf-command CMD     Command for performance smoke check
  --output-file FILE     Write markdown report to FILE
  --require-lsp          Fail if ENABLE_LSP_TOOL is not set to 1
  --skip-syntax          Skip syntax/autoload check gate
  --skip-lint            Skip lint gate
  --skip-tests           Skip test gate
  --skip-security        Skip security gate
  --skip-perf            Skip performance smoke gate
  -h, --help             Show this help

Examples:
  ./scripts/run_gates.sh
  ./scripts/run_gates.sh --test-target spec/requests/users_spec.rb
  ./scripts/run_gates.sh --mode advisory --skip-security
  ./scripts/run_gates.sh --perf-command "bundle exec ruby scripts/perf_smoke.rb"
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
    --test-target)
      TEST_TARGET="$2"
      shift 2
      ;;
    --rubocop-target)
      RUBOCOP_TARGET="$2"
      shift 2
      ;;
    --perf-command)
      PERF_COMMAND="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --require-lsp)
      REQUIRE_LSP=1
      shift
      ;;
    --skip-syntax)
      SKIP_SYNTAX=1
      shift
      ;;
    --skip-lint)
      SKIP_LINT=1
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    --skip-security)
      SKIP_SECURITY=1
      shift
      ;;
    --skip-perf)
      SKIP_PERF=1
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

if [ ! -d "$PROJECT_DIR" ]; then
  log_err "Project directory not found: $PROJECT_DIR"
  exit 2
fi

if ! command -v bundle >/dev/null 2>&1; then
  log_err "'bundle' command not found in PATH."
  exit 2
fi

cd "$PROJECT_DIR" || exit 2

if [ ! -f "Gemfile" ]; then
  log_warn "Gemfile not found. This does not look like a Rails app root."
fi
if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  if [ "$REQUIRE_LSP" -eq 1 ]; then
    log_err "ENABLE_LSP_TOOL is not set to 1 and --require-lsp is enabled."
    exit 2
  fi
  log_warn "ENABLE_LSP_TOOL is not set to 1. LSP-enabled sessions are recommended for better code-intel context during gate analysis."
fi

RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${PROJECT_DIR}/tmp/rails-quality-gates-${RUN_ID}"
mkdir -p "$LOG_DIR"
log_info "Logs: $LOG_DIR"

status_syntax="NOT_RUN"
status_lint="NOT_RUN"
status_tests="NOT_RUN"
status_security="NOT_RUN"
status_perf="NOT_RUN"

cmd_syntax=""
cmd_lint=""
cmd_tests=""
cmd_security=""
cmd_perf=""

run_cmd() {
  # $1 label, $2 command, $3 logfile
  log_info "$1 -> $2"
  bash -lc "$2" >"$3" 2>&1
}

# Gate 1: syntax/autoload
if [ "$SKIP_SYNTAX" -eq 1 ]; then
  log_warn "Syntax gate skipped."
else
  if bundle exec rails --version >/dev/null 2>&1; then
    cmd_syntax="bundle exec rails zeitwerk:check"
    if run_cmd "Syntax gate" "$cmd_syntax" "$LOG_DIR/syntax.log"; then
      status_syntax="PASS"
      log_ok "Syntax gate passed."
    else
      status_syntax="FAIL"
      log_err "Syntax gate failed. See $LOG_DIR/syntax.log"
    fi
  else
    status_syntax="NOT_RUN"
    log_warn "Syntax gate not run (rails command unavailable in bundle)."
  fi
fi

# Gate 2: lint
if [ "$SKIP_LINT" -eq 1 ]; then
  log_warn "Lint gate skipped."
else
  if bundle exec rubocop --version >/dev/null 2>&1; then
    cmd_lint="bundle exec rubocop ${RUBOCOP_TARGET}"
    if run_cmd "Lint gate" "$cmd_lint" "$LOG_DIR/lint.log"; then
      status_lint="PASS"
      log_ok "Lint gate passed."
    else
      status_lint="FAIL"
      log_err "Lint gate failed. See $LOG_DIR/lint.log"
    fi
  else
    status_lint="NOT_RUN"
    log_warn "Lint gate not run (rubocop unavailable)."
  fi
fi

# Gate 3: tests
if [ "$SKIP_TESTS" -eq 1 ]; then
  log_warn "Test gate skipped."
else
  if bundle exec rspec --version >/dev/null 2>&1; then
    cmd_tests="bundle exec rspec ${TEST_TARGET}"
    if run_cmd "Test gate" "$cmd_tests" "$LOG_DIR/tests.log"; then
      status_tests="PASS"
      log_ok "Test gate passed."
    else
      status_tests="FAIL"
      log_err "Test gate failed. See $LOG_DIR/tests.log"
    fi
  elif bundle exec rails test -h >/dev/null 2>&1; then
    cmd_tests="bundle exec rails test ${TEST_TARGET}"
    if run_cmd "Test gate" "$cmd_tests" "$LOG_DIR/tests.log"; then
      status_tests="PASS"
      log_ok "Test gate passed."
    else
      status_tests="FAIL"
      log_err "Test gate failed. See $LOG_DIR/tests.log"
    fi
  else
    status_tests="NOT_RUN"
    log_warn "Test gate not run (no rspec or rails test available)."
  fi
fi

# Gate 4: security
if [ "$SKIP_SECURITY" -eq 1 ]; then
  log_warn "Security gate skipped."
else
  if bundle exec brakeman --version >/dev/null 2>&1; then
    cmd_security="bundle exec brakeman --no-pager -q"
    if run_cmd "Security gate" "$cmd_security" "$LOG_DIR/security.log"; then
      status_security="PASS"
      log_ok "Security gate passed."
    else
      status_security="FAIL"
      log_err "Security gate failed. See $LOG_DIR/security.log"
    fi
  else
    status_security="NOT_RUN"
    log_warn "Security gate not run (brakeman unavailable)."
  fi
fi

# Gate 5: performance smoke
if [ "$SKIP_PERF" -eq 1 ]; then
  log_warn "Performance gate skipped."
else
  if [ -n "$PERF_COMMAND" ]; then
    cmd_perf="$PERF_COMMAND"
    if run_cmd "Performance gate" "$cmd_perf" "$LOG_DIR/perf.log"; then
      status_perf="PASS"
      log_ok "Performance gate passed."
    else
      status_perf="FAIL"
      log_err "Performance gate failed. See $LOG_DIR/perf.log"
    fi
  else
    status_perf="NOT_RUN"
    log_warn "Performance gate not run. Provide --perf-command to enable."
  fi
fi

overall="PASS"
if [ "$status_syntax" = "FAIL" ] || [ "$status_lint" = "FAIL" ] || [ "$status_tests" = "FAIL" ] || [ "$status_security" = "FAIL" ] || [ "$status_perf" = "FAIL" ]; then
  overall="FAIL"
elif [ "$status_syntax" = "NOT_RUN" ] || [ "$status_lint" = "NOT_RUN" ] || [ "$status_tests" = "NOT_RUN" ] || [ "$status_security" = "NOT_RUN" ] || [ "$status_perf" = "NOT_RUN" ]; then
  overall="WARN"
fi

printf "\n"
log_info "Execution Summary (Quality Gates)"
printf "  - Syntax:      %s\n" "$status_syntax"
printf "  - Lint:        %s\n" "$status_lint"
printf "  - Tests:       %s\n" "$status_tests"
printf "  - Security:    %s\n" "$status_security"
printf "  - Performance: %s\n" "$status_perf"
printf "  - Overall:     %s\n" "$overall"

if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  {
    echo "# Rails Quality Gates Report"
    echo
    echo "- Mode: $MODE"
    echo "- Project: $PROJECT_DIR"
    echo "- Logs: $LOG_DIR"
    echo "- Overall: $overall"
    echo
    echo "## Gate Results"
    echo
    echo "- Syntax: $status_syntax"
    echo "- Lint: $status_lint"
    echo "- Tests: $status_tests"
    echo "- Security: $status_security"
    echo "- Performance: $status_perf"
    echo
    echo "## Commands"
    echo
    echo "- Syntax: ${cmd_syntax:-N/A}"
    echo "- Lint: ${cmd_lint:-N/A}"
    echo "- Tests: ${cmd_tests:-N/A}"
    echo "- Security: ${cmd_security:-N/A}"
    echo "- Performance: ${cmd_perf:-N/A}"
  } >"$OUTPUT_FILE"
  log_info "Report written to $OUTPUT_FILE"
fi

if [ "$MODE" = "strict" ] && [ "$overall" = "FAIL" ]; then
  exit 1
fi

exit 0
