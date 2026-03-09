#!/usr/bin/env bash
set -u

TARGET="both"
MODE="symlink"
FORCE=0
DRY_RUN=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}/skills"

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
Usage: install_skills_codex_claude.sh [options]

Install local rails-* skills into Codex and/or Claude skills directories.

Options:
  --target TARGET      codex | claude | both (default: both)
  --mode MODE          symlink | copy (default: symlink)
  --source-dir DIR     Source folder containing rails-* skill directories
  --codex-dir DIR      Override Codex skills destination
  --claude-dir DIR     Override Claude skills destination
  --force              Replace existing destination skills
  --dry-run            Show actions without writing
  -h, --help           Show this help

Examples:
  ./install_skills_codex_claude.sh
  ./install_skills_codex_claude.sh --target codex --mode copy
  ./install_skills_codex_claude.sh --dry-run --force
EOF
}

log_info() { printf "%b[INFO]%b %s\n" "$C_INFO" "$C_RESET" "$1"; }
log_ok() { printf "%b[PASS]%b %s\n" "$C_OK" "$C_RESET" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_WARN" "$C_RESET" "$1"; }
log_err() { printf "%b[FAIL]%b %s\n" "$C_ERR" "$C_RESET" "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --codex-dir)
      CODEX_DIR="$2"
      shift 2
      ;;
    --claude-dir)
      CLAUDE_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=1
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

if [ ! -d "$SOURCE_DIR" ]; then
  log_err "Source directory not found: $SOURCE_DIR"
  exit 2
fi

gather_skills() {
  find "$SOURCE_DIR" -maxdepth 1 -type d -name 'rails-*' | while IFS= read -r d; do
    if [ -f "$d/SKILL.md" ]; then
      basename "$d"
    fi
  done | sort
}

SKILLS="$(gather_skills)"
if [ -z "$SKILLS" ]; then
  log_err "No rails-* skill directories with SKILL.md found in $SOURCE_DIR"
  exit 1
fi

perform_install() {
  # $1 destination_root, $2 label
  local dest_root="$1"
  local label="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[$label] would ensure destination: $dest_root"
  else
    mkdir -p "$dest_root"
  fi

  local installed=0
  local skipped=0
  local replaced=0
  local skill src dest

  while IFS= read -r skill; do
    src="$SOURCE_DIR/$skill"
    dest="$dest_root/$skill"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ "$FORCE" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          log_info "[$label] would replace existing: $dest"
        else
          rm -rf "$dest"
        fi
        replaced=$((replaced + 1))
      else
        log_warn "[$label] exists, skipping (use --force to replace): $dest"
        skipped=$((skipped + 1))
        continue
      fi
    fi

    if [ "$MODE" = "symlink" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[$label] would symlink: $dest -> $src"
      else
        ln -s "$src" "$dest"
      fi
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[$label] would copy: $src -> $dest"
      else
        cp -R "$src" "$dest"
      fi
    fi
    installed=$((installed + 1))
  done <<<"$SKILLS"

  log_ok "[$label] done. installed=$installed replaced=$replaced skipped=$skipped"
}

log_info "Source directory: $SOURCE_DIR"
log_info "Mode: $MODE"
log_info "Target: $TARGET"
log_info "Force replace: $FORCE"
log_info "Dry run: $DRY_RUN"
log_info "Skills:"
while IFS= read -r skill; do
  printf "  - %s\n" "$skill"
done <<<"$SKILLS"

if [ "$TARGET" = "codex" ] || [ "$TARGET" = "both" ]; then
  perform_install "$CODEX_DIR" "codex"
fi

if [ "$TARGET" = "claude" ] || [ "$TARGET" = "both" ]; then
  perform_install "$CLAUDE_DIR" "claude"
fi

printf "\n"
log_info "Recommendation: enable LSP for better Rails skill results."
printf "  - Session-level: ENABLE_LSP_TOOL=1 <claude-or-codex-command>\n"
printf "  - Multi-app setup: use direnv with .envrc per Rails repo:\n"
printf "      export ENABLE_LSP_TOOL=1\n"
printf "  - Preflight check in this repo:\n"
printf "      ./scripts/check_lsp_env.sh --required\n"

exit 0
