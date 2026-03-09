#!/usr/bin/env bash
set -u

REQUIRED=0

usage() {
  cat <<'USAGE'
Usage: scripts/check_lsp_env.sh [options]

Check whether LSP is enabled for Rails skills usage.

Options:
  --required    Exit non-zero if ENABLE_LSP_TOOL is not set to 1
  -h, --help    Show this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --required)
      REQUIRED=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[FAIL] Unknown option: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

printf '[INFO] ENABLE_LSP_TOOL=%s\n' "${ENABLE_LSP_TOOL:-<unset>}"

if [ "${ENABLE_LSP_TOOL:-0}" != "1" ]; then
  printf '[WARN] LSP is not enabled. Recommended: export ENABLE_LSP_TOOL=1\n'
  if [ "$REQUIRED" -eq 1 ]; then
    printf '[FAIL] Strict mode enabled and LSP is not active.\n' >&2
    exit 2
  fi
else
  printf '[PASS] LSP is enabled.\n'
fi

if [ -f "Gemfile" ]; then
  if rg -n "ruby-lsp|solargraph" Gemfile Gemfile.lock >/dev/null 2>&1; then
    printf '[PASS] Ruby LSP dependency detected in Gemfile/Gemfile.lock.\n'
  else
    printf '[WARN] No ruby-lsp/solargraph found in Gemfile or Gemfile.lock.\n'
  fi
else
  printf '[INFO] No Gemfile in current directory; skipping Ruby LSP gem check.\n'
fi

printf '[INFO] Preflight complete.\n'
exit 0
