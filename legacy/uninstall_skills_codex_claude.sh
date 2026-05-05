#!/usr/bin/env bash
set -u

TARGET="both"
SOURCE_DIR=""
SKILLS_CSV=""
ALL_RAILS=0
FORCE=0
DRY_RUN=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${SOURCE_DIR}" ]; then
  SOURCE_DIR="$SCRIPT_DIR"
fi
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
Usage: uninstall_skills_codex_claude.sh [options]

Uninstall rails-* skills from Codex and/or Claude skills directories.

Options:
  --target TARGET      codex | claude | both (default: both)
  --source-dir DIR     Source folder containing rails-* skill directories
  --skills CSV         Comma-separated skill names to remove
  --all-rails          Remove all rails-* skills from target directories
  --codex-dir DIR      Override Codex skills destination
  --claude-dir DIR     Override Claude skills destination
  --force              Remove even if destination is not symlinked to source-dir
  --dry-run            Show actions without writing
  -h, --help           Show this help

Examples:
  ./uninstall_skills_codex_claude.sh
  ./uninstall_skills_codex_claude.sh --target codex --skills rails-diagnose,rails-framework
  ./uninstall_skills_codex_claude.sh --all-rails --force
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
    --source-dir)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --skills)
      SKILLS_CSV="$2"
      shift 2
      ;;
    --all-rails)
      ALL_RAILS=1
      shift
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

if [ "$ALL_RAILS" -eq 0 ] && [ -z "$SKILLS_CSV" ] && [ ! -d "$SOURCE_DIR" ]; then
  log_err "Source directory not found: $SOURCE_DIR"
  exit 2
fi

gather_skills_from_source() {
  find "$SOURCE_DIR" -maxdepth 1 -type d -name 'rails-*' | while IFS= read -r d; do
    if [ -f "$d/SKILL.md" ]; then
      basename "$d"
    fi
  done | sort
}

skills_from_csv() {
  printf "%s" "$SKILLS_CSV" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | sed '/^$/d' | sort -u
}

skills_from_target() {
  # $1 destination root
  local dest_root="$1"
  if [ ! -d "$dest_root" ]; then
    return
  fi
  find "$dest_root" -maxdepth 1 -type d -name 'rails-*' -print | while IFS= read -r d; do
    basename "$d"
  done | sort -u
}

remove_one() {
  # $1 label, $2 dest_root, $3 skill
  local label="$1"
  local dest_root="$2"
  local skill="$3"
  local dest="$dest_root/$skill"
  local src="$SOURCE_DIR/$skill"

  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    log_warn "[$label] not found, skipping: $dest"
    return 2
  fi

  if [ "$FORCE" -eq 0 ] && [ -L "$dest" ]; then
    local link_target
    link_target="$(readlink "$dest" || true)"
    if [ -n "$link_target" ] && [ "$link_target" != "$src" ] && [ "$ALL_RAILS" -eq 0 ]; then
      log_warn "[$label] symlink points elsewhere, skipping (use --force): $dest -> $link_target"
      return 3
    fi
  fi

  if [ "$FORCE" -eq 0 ] && [ ! -L "$dest" ] && [ "$ALL_RAILS" -eq 0 ]; then
    log_warn "[$label] destination is not a symlink. Skipping (use --force): $dest"
    return 4
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[$label] would remove: $dest"
  else
    rm -rf "$dest"
    log_ok "[$label] removed: $dest"
  fi
  return 0
}

perform_uninstall() {
  # $1 destination_root, $2 label, $3 skills_text
  local dest_root="$1"
  local label="$2"
  local skills_text="$3"

  if [ ! -d "$dest_root" ]; then
    log_warn "[$label] destination not found, skipping: $dest_root"
    return
  fi

  local removed=0
  local skipped=0
  local missing=0
  local skill

  while IFS= read -r skill; do
    if [ -z "$skill" ]; then
      continue
    fi
    if remove_one "$label" "$dest_root" "$skill"; then
      removed=$((removed + 1))
    else
      case "$?" in
        2) missing=$((missing + 1)) ;;
        *) skipped=$((skipped + 1)) ;;
      esac
    fi
  done <<<"$skills_text"

  log_ok "[$label] done. removed=$removed skipped=$skipped missing=$missing"
}

SKILLS=""
if [ "$ALL_RAILS" -eq 1 ]; then
  if [ "$TARGET" = "codex" ]; then
    SKILLS="$(skills_from_target "$CODEX_DIR")"
  elif [ "$TARGET" = "claude" ]; then
    SKILLS="$(skills_from_target "$CLAUDE_DIR")"
  else
    SKILLS="$(printf "%s\n%s\n" "$(skills_from_target "$CODEX_DIR")" "$(skills_from_target "$CLAUDE_DIR")" | sed '/^$/d' | sort -u)"
  fi
elif [ -n "$SKILLS_CSV" ]; then
  SKILLS="$(skills_from_csv)"
else
  SKILLS="$(gather_skills_from_source)"
fi

if [ -z "$SKILLS" ]; then
  log_warn "No skills selected for uninstall."
  exit 0
fi

log_info "Target: $TARGET"
log_info "Source directory: $SOURCE_DIR"
log_info "Force remove: $FORCE"
log_info "Dry run: $DRY_RUN"
log_info "Selected skills:"
while IFS= read -r skill; do
  printf "  - %s\n" "$skill"
done <<<"$SKILLS"

if [ "$TARGET" = "codex" ] || [ "$TARGET" = "both" ]; then
  perform_uninstall "$CODEX_DIR" "codex" "$SKILLS"
fi

if [ "$TARGET" = "claude" ] || [ "$TARGET" = "both" ]; then
  perform_uninstall "$CLAUDE_DIR" "claude" "$SKILLS"
fi

exit 0
