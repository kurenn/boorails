#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

TARGET="both"
MODE="symlink"
FORCE=1
SKIP_PULL=0
DRY_RUN=0
ALLOW_DIRTY=0

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
Usage: update_skills.sh [options]

Update BooRails skills by optionally pulling latest git changes and reinstalling
skills into Codex and/or Claude.

Options:
  --repo-dir DIR    BooRails repo directory (default: script directory)
  --target TARGET   codex | claude | both (default: both)
  --mode MODE       symlink | copy (default: symlink)
  --skip-pull       Do not run git pull before reinstall
  --allow-dirty     Allow git pull even with local uncommitted changes
  --no-force        Do not pass --force to installer
  --dry-run         Show actions without writing
  -h, --help        Show this help

Examples:
  ./update_skills.sh
  ./update_skills.sh --skip-pull --target codex
  ./update_skills.sh --mode copy --dry-run
USAGE
}

log_info() { printf "%b[INFO]%b %s\n" "$C_INFO" "$C_RESET" "$1"; }
log_ok() { printf "%b[PASS]%b %s\n" "$C_OK" "$C_RESET" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_WARN" "$C_RESET" "$1"; }
log_err() { printf "%b[FAIL]%b %s\n" "$C_ERR" "$C_RESET" "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-dir)
      REPO_DIR="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --no-force)
      FORCE=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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

if [ "$TARGET" != "codex" ] && [ "$TARGET" != "claude" ] && [ "$TARGET" != "both" ]; then
  log_err "Invalid --target '$TARGET'. Expected codex, claude, or both."
  exit 2
fi

if [ "$MODE" != "symlink" ] && [ "$MODE" != "copy" ]; then
  log_err "Invalid --mode '$MODE'. Expected symlink or copy."
  exit 2
fi

if [ ! -d "$REPO_DIR" ]; then
  log_err "Repo directory not found: $REPO_DIR"
  exit 2
fi

INSTALL_SCRIPT="$REPO_DIR/install_skills_codex_claude.sh"
if [ ! -f "$INSTALL_SCRIPT" ]; then
  log_err "Installer not found: $INSTALL_SCRIPT"
  exit 2
fi

log_info "Repo: $REPO_DIR"
log_info "Target: $TARGET"
log_info "Mode: $MODE"
log_info "Force replace: $FORCE"
log_info "Dry run: $DRY_RUN"

if [ "$SKIP_PULL" -eq 1 ]; then
  log_info "Skipping git pull (--skip-pull)."
else
  if command -v git >/dev/null 2>&1 && git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    current_branch="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    origin_url="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
    dirty_state="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null || true)"

    if [ -z "$origin_url" ]; then
      log_warn "No git origin configured. Skipping pull."
    elif [ -z "$current_branch" ]; then
      log_warn "Could not determine current branch. Skipping pull."
    elif [ -n "$dirty_state" ] && [ "$ALLOW_DIRTY" -ne 1 ]; then
      log_warn "Working tree has local changes; skipping pull. Use --allow-dirty to override."
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        log_info "Would run: git -C '$REPO_DIR' pull --ff-only origin '$current_branch'"
      else
        log_info "Pulling latest changes from origin/$current_branch..."
        if git -C "$REPO_DIR" pull --ff-only origin "$current_branch"; then
          log_ok "Git pull completed."
        else
          log_err "Git pull failed. Resolve first, then re-run update."
          exit 1
        fi
      fi
    fi
  else
    log_warn "No git repository detected in $REPO_DIR. Skipping pull."
  fi
fi

install_cmd=(bash "$INSTALL_SCRIPT" --target "$TARGET" --mode "$MODE")
if [ "$FORCE" -eq 1 ]; then
  install_cmd+=(--force)
fi
if [ "$DRY_RUN" -eq 1 ]; then
  install_cmd+=(--dry-run)
fi

log_info "Running installer..."
"${install_cmd[@]}"

printf "\n"
log_ok "Skills update flow completed."
log_info "Restart Claude/Codex session to ensure fresh skill metadata is loaded."

exit 0
