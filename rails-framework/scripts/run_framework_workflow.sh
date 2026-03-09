#!/usr/bin/env bash
set -u

MODE="strict"
PROJECT_DIR="$PWD"
OUTPUT_DIR=""
TEST_TARGET=""
RUBOCOP_TARGET=""
PERF_COMMAND=""
REQUIRE_LSP=0
AUTO_INSTALL_GEMS=1
GEMSET="full"
GEM_DRY_RUN=0
FRAMEWORK_GEMS_STATUS="NOT_RUN"
FRAMEWORK_GEMS_TARGET_COUNT=0
FRAMEWORK_GEMS_PRESENT_COUNT=0
FRAMEWORK_GEMS_INSTALL_COUNT=0
FRAMEWORK_GEMS_FAIL_COUNT=0

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
Usage: run_framework_workflow.sh [options]

Run the Rails Framework workflow:
  1) Diagnose
  2) Implementation Safety
  3) Quality Gates

Options:
  --project-dir DIR      Rails project root (default: current directory)
  --mode MODE            strict | advisory (default: strict)
  --output-dir DIR       Directory for workflow reports/logs
  --test-target TARGET   Passed to quality gates script
  --rubocop-target PATH  Passed to quality gates script
  --perf-command CMD     Passed to quality gates script
  --no-auto-install-gems Skip framework gem bootstrap before running steps
  --gemset NAME          minimal | full (default: full)
  --gem-dry-run          Show planned gem installs without modifying Gemfile
  --require-lsp          Fail if ENABLE_LSP_TOOL is not set to 1
  -h, --help             Show this help

Examples:
  ./scripts/run_framework_workflow.sh
  ./scripts/run_framework_workflow.sh --project-dir /path/to/rails-app --mode advisory
  ./scripts/run_framework_workflow.sh --test-target spec/requests/users_spec.rb
  ./scripts/run_framework_workflow.sh --gemset minimal --no-auto-install-gems
EOF
}

log_info() { printf "%b[INFO]%b %s\n" "$C_INFO" "$C_RESET" "$1"; }
log_ok() { printf "%b[PASS]%b %s\n" "$C_OK" "$C_RESET" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_WARN" "$C_RESET" "$1"; }
log_err() { printf "%b[FAIL]%b %s\n" "$C_ERR" "$C_RESET" "$1"; }

gem_declared() {
  local gem_name="$1"
  if grep -Eq "^[[:space:]]*gem[[:space:]]*\\(?[[:space:]]*['\"]${gem_name}['\"]" "$PROJECT_DIR/Gemfile" 2>/dev/null; then
    return 0
  fi
  if [ -f "$PROJECT_DIR/Gemfile.lock" ] && grep -Eq "^[[:space:]]{4}${gem_name}([[:space:]]|\\()" "$PROJECT_DIR/Gemfile.lock" 2>/dev/null; then
    return 0
  fi
  return 1
}

bootstrap_framework_gems() {
  # Writes a markdown report and sets FRAMEWORK_GEMS_STATUS.
  local report_file="$1"
  local log_file="$2"
  local records=""
  local actions=""
  local total_count=0
  local present_count=0
  local install_count=0
  local fail_count=0
  local status="PASS"
  local gem_name=""
  local gem_group=""
  local gem_reason=""

  FRAMEWORK_GEMS_STATUS="NOT_RUN"
  FRAMEWORK_GEMS_TARGET_COUNT=0
  FRAMEWORK_GEMS_PRESENT_COUNT=0
  FRAMEWORK_GEMS_INSTALL_COUNT=0
  FRAMEWORK_GEMS_FAIL_COUNT=0

  if [ "$AUTO_INSTALL_GEMS" -eq 0 ]; then
    FRAMEWORK_GEMS_STATUS="SKIPPED"
    {
      echo "# Framework Gem Bootstrap"
      echo
      echo "- Status: SKIPPED"
      echo "- Reason: disabled via --no-auto-install-gems"
    } >"$report_file"
    return 0
  fi

  if [ ! -f "$PROJECT_DIR/Gemfile" ]; then
    FRAMEWORK_GEMS_STATUS="WARN"
    {
      echo "# Framework Gem Bootstrap"
      echo
      echo "- Status: WARN"
      echo "- Reason: Gemfile not found at project root; gem bootstrap skipped"
    } >"$report_file"
    return 0
  fi

  if ! command -v bundle >/dev/null 2>&1; then
    FRAMEWORK_GEMS_STATUS="FAIL"
    {
      echo "# Framework Gem Bootstrap"
      echo
      echo "- Status: FAIL"
      echo "- Reason: bundle command not found"
    } >"$report_file"
    return 1
  fi

  records="$(cat <<'EOF'
rubocop|development,test|Lint gate baseline
rubocop-rails|development,test|Rails-specific lint cops
brakeman|development,test|Security gate
EOF
)"
  if [ "$GEMSET" = "full" ]; then
    records="${records}"$'\n'"rspec-rails|development,test|RSpec quality gate support"
    records="${records}"$'\n'"rubocop-rspec|development,test|RSpec lint cops"
    records="${records}"$'\n'"bullet|development,test|N+1 diagnostics support"
    records="${records}"$'\n'"strong_migrations|development|Migration safety support"
    records="${records}"$'\n'"ruby-lsp|development,test|LSP support for symbol-level analysis"
  fi

  : >"$log_file"
  while IFS='|' read -r gem_name gem_group gem_reason; do
    [ -z "$gem_name" ] && continue
    total_count=$((total_count + 1))
    if gem_declared "$gem_name"; then
      present_count=$((present_count + 1))
      actions="${actions}- \`${gem_name}\` already present (${gem_reason})"$'\n'
      continue
    fi

    if [ "$GEM_DRY_RUN" -eq 1 ]; then
      install_count=$((install_count + 1))
      actions="${actions}- \`${gem_name}\` missing; dry-run would run: \`bundle add ${gem_name} --group ${gem_group}\`"$'\n'
      continue
    fi

    if bundle add "$gem_name" --group "$gem_group" >>"$log_file" 2>&1; then
      install_count=$((install_count + 1))
      actions="${actions}- Installed \`${gem_name}\` in group \`${gem_group}\` (${gem_reason})"$'\n'
    else
      fail_count=$((fail_count + 1))
      actions="${actions}- FAILED to install \`${gem_name}\` (see \`$(basename "$log_file")\`)"$'\n'
    fi
  done <<<"$records"

  if [ "$fail_count" -gt 0 ]; then
    status="FAIL"
  elif [ "$GEM_DRY_RUN" -eq 1 ] || [ "$install_count" -gt 0 ]; then
    status="WARN"
  fi

  FRAMEWORK_GEMS_STATUS="$status"
  FRAMEWORK_GEMS_TARGET_COUNT="$total_count"
  FRAMEWORK_GEMS_PRESENT_COUNT="$present_count"
  FRAMEWORK_GEMS_INSTALL_COUNT="$install_count"
  FRAMEWORK_GEMS_FAIL_COUNT="$fail_count"
  {
    echo "# Framework Gem Bootstrap"
    echo
    echo "- Status: $status"
    echo "- Gemset: $GEMSET"
    echo "- Dry run: $GEM_DRY_RUN"
    echo "- Target gems: $total_count"
    echo "- Present: $present_count"
    echo "- Installed/Planned: $install_count"
    echo "- Failed: $fail_count"
    echo
    echo "## Actions"
    echo
    if [ -n "$actions" ]; then
      printf "%b" "$actions"
    else
      echo "- No gem actions performed."
    fi
    if [ "$GEM_DRY_RUN" -eq 0 ]; then
      echo
      echo "## Install Log"
      echo
      echo "- $log_file"
    fi
  } >"$report_file"

  if [ "$fail_count" -gt 0 ]; then
    return 1
  fi
  return 0
}

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
    --output-dir)
      OUTPUT_DIR="$2"
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
    --no-auto-install-gems)
      AUTO_INSTALL_GEMS=0
      shift
      ;;
    --gemset)
      GEMSET="$2"
      shift 2
      ;;
    --gem-dry-run)
      GEM_DRY_RUN=1
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
if [ "$GEMSET" != "minimal" ] && [ "$GEMSET" != "full" ]; then
  log_err "Invalid --gemset value: $GEMSET (expected minimal or full)"
  exit 2
fi

if [ ! -d "$PROJECT_DIR" ]; then
  log_err "Project directory not found: $PROJECT_DIR"
  exit 2
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DIAG_SCRIPT="$SKILLS_ROOT/rails-diagnose/scripts/run_diagnose.sh"
SAFE_SCRIPT="$SKILLS_ROOT/rails-implementation-safety/scripts/safety_check.sh"
GATES_SCRIPT="$SKILLS_ROOT/rails-quality-gates/scripts/run_gates.sh"

for required in "$DIAG_SCRIPT" "$SAFE_SCRIPT" "$GATES_SCRIPT"; do
  if [ ! -f "$required" ]; then
    log_err "Missing required script: $required"
    exit 2
  fi
done

RUN_ID="$(date +%Y%m%d-%H%M%S)"
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$PROJECT_DIR/tmp/rails-framework-workflow-${RUN_ID}"
fi
mkdir -p "$OUTPUT_DIR"

log_info "Workflow output: $OUTPUT_DIR"
log_info "Project: $PROJECT_DIR"
log_info "Mode: $MODE"
log_info "Gem bootstrap: auto_install=$AUTO_INSTALL_GEMS gemset=$GEMSET dry_run=$GEM_DRY_RUN"
if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  if [ "$REQUIRE_LSP" -eq 1 ]; then
    log_err "ENABLE_LSP_TOOL is not set to 1 and --require-lsp is enabled."
    exit 2
  fi
  log_warn "ENABLE_LSP_TOOL is not set to 1. LSP-enabled sessions are strongly recommended for framework-level analysis."
fi

git_available=0
git_head="N/A"
change_log_md="Git repository not detected."
if command -v git >/dev/null 2>&1; then
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_available=1
    git_head="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  fi
fi

DIAG_REPORT="$OUTPUT_DIR/01-diagnose.md"
SAFE_REPORT="$OUTPUT_DIR/02-safety.md"
GATES_REPORT="$OUTPUT_DIR/03-quality-gates.md"
GEMS_REPORT="$OUTPUT_DIR/00-framework-gems.md"
GEMS_LOG="$OUTPUT_DIR/00-framework-gems.log"

gems_status="SKIPPED"
diag_status="NOT_RUN"
safe_status="NOT_RUN"
gates_status="NOT_RUN"

if bootstrap_framework_gems "$GEMS_REPORT" "$GEMS_LOG"; then
  gems_status="$FRAMEWORK_GEMS_STATUS"
  if [ "$gems_status" = "PASS" ]; then
    log_ok "Framework gem bootstrap passed."
  elif [ "$gems_status" = "WARN" ]; then
    log_warn "Framework gem bootstrap completed with warnings."
  else
    log_warn "Framework gem bootstrap skipped."
  fi
else
  gems_status="$FRAMEWORK_GEMS_STATUS"
  log_err "Framework gem bootstrap failed."
fi

diag_cmd=(bash "$DIAG_SCRIPT" --project-dir "$PROJECT_DIR" --mode "$MODE" --output-file "$DIAG_REPORT")
safe_cmd=(bash "$SAFE_SCRIPT" --project-dir "$PROJECT_DIR" --mode "$MODE" --output-file "$SAFE_REPORT")
gates_cmd=(bash "$GATES_SCRIPT" --project-dir "$PROJECT_DIR" --mode "$MODE" --output-file "$GATES_REPORT")

if [ "$REQUIRE_LSP" -eq 1 ]; then
  diag_cmd+=(--require-lsp)
  safe_cmd+=(--require-lsp)
  gates_cmd+=(--require-lsp)
fi

if [ -n "$TEST_TARGET" ]; then
  gates_cmd+=(--test-target "$TEST_TARGET")
fi
if [ -n "$RUBOCOP_TARGET" ]; then
  gates_cmd+=(--rubocop-target "$RUBOCOP_TARGET")
fi
if [ -n "$PERF_COMMAND" ]; then
  gates_cmd+=(--perf-command "$PERF_COMMAND")
fi

if [ "$MODE" = "strict" ] && [ "$gems_status" = "FAIL" ]; then
  log_err "Stopping workflow because gem bootstrap failed in strict mode."
else
  log_info "Step 1/3: Diagnose"
  if "${diag_cmd[@]}"; then
    diag_status="PASS"
    log_ok "Diagnose completed."
  else
    diag_status="FAIL"
    log_err "Diagnose returned non-zero."
  fi

  log_info "Step 2/3: Implementation Safety"
  if "${safe_cmd[@]}"; then
    safe_status="PASS"
    log_ok "Implementation safety completed."
  else
    safe_status="FAIL"
    log_err "Implementation safety returned non-zero."
  fi

  log_info "Step 3/3: Quality Gates"
  if "${gates_cmd[@]}"; then
    gates_status="PASS"
    log_ok "Quality gates completed."
  else
    gates_status="FAIL"
    log_err "Quality gates returned non-zero."
  fi
fi

overall="PASS"
if [ "$gems_status" = "FAIL" ] || [ "$diag_status" = "FAIL" ] || [ "$safe_status" = "FAIL" ] || [ "$gates_status" = "FAIL" ]; then
  overall="FAIL"
elif [ "$gems_status" = "WARN" ] || [ "$gems_status" = "SKIPPED" ] || [ "$diag_status" = "NOT_RUN" ] || [ "$safe_status" = "NOT_RUN" ] || [ "$gates_status" = "NOT_RUN" ]; then
  overall="WARN"
fi

SUMMARY_FILE="$OUTPUT_DIR/00-summary.md"
if [ "$git_available" -eq 1 ]; then
  raw_changes="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)"
  if [ -n "$raw_changes" ]; then
    # Convert porcelain rows into markdown bullets.
    change_log_md="$(printf "%s\n" "$raw_changes" | awk '{status=substr($0,1,2); file=substr($0,4); gsub(/^ +| +$/,"",status); printf "- `%s` %s\n", file, status}')"
  else
    change_log_md="- No working tree changes detected."
  fi
fi

{
  echo "# Rails Framework Workflow Summary"
  echo
  echo "- Mode: $MODE"
  echo "- Project: $PROJECT_DIR"
  echo "- Git HEAD: $git_head"
  echo "- Overall: $overall"
  echo
  echo "## Step Results"
  echo
  echo "- Gem Bootstrap: $gems_status ([report]($(basename "$GEMS_REPORT")))"
  echo "  - Target gems: $FRAMEWORK_GEMS_TARGET_COUNT"
  echo "  - Present: $FRAMEWORK_GEMS_PRESENT_COUNT"
  echo "  - Installed/Planned: $FRAMEWORK_GEMS_INSTALL_COUNT"
  echo "  - Failed: $FRAMEWORK_GEMS_FAIL_COUNT"
  echo "- Diagnose: $diag_status ([report]($(basename "$DIAG_REPORT")))"
  echo "- Implementation Safety: $safe_status ([report]($(basename "$SAFE_REPORT")))"
  echo "- Quality Gates: $gates_status ([report]($(basename "$GATES_REPORT")))"
  echo
  echo "## Reports"
  echo
  echo "1. $GEMS_REPORT"
  echo "2. $DIAG_REPORT"
  echo "3. $SAFE_REPORT"
  echo "4. $GATES_REPORT"
  echo
  echo "## Change Log"
  echo
  printf "%b\n" "$change_log_md"
} >"$SUMMARY_FILE"

printf "\n"
log_info "Execution Summary (Framework Workflow)"
printf "  - Gem bootstrap:        %s\n" "$gems_status"
printf "  - Gem target count:     %s\n" "$FRAMEWORK_GEMS_TARGET_COUNT"
printf "  - Gems already present: %s\n" "$FRAMEWORK_GEMS_PRESENT_COUNT"
printf "  - Gems installed/plan:  %s\n" "$FRAMEWORK_GEMS_INSTALL_COUNT"
printf "  - Gems failed install:  %s\n" "$FRAMEWORK_GEMS_FAIL_COUNT"
printf "  - Diagnose:             %s\n" "$diag_status"
printf "  - Implementation safety:%s\n" "$safe_status"
printf "  - Quality gates:        %s\n" "$gates_status"
printf "  - Overall:              %s\n" "$overall"
log_info "Summary report: $SUMMARY_FILE"

if [ "$MODE" = "strict" ] && [ "$overall" = "FAIL" ]; then
  exit 1
fi

exit 0
