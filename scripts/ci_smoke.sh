#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[INFO] Running shell syntax checks..."
bash -n ./install_skills_codex_claude.sh
bash -n ./uninstall_skills_codex_claude.sh
bash -n ./scripts/check_lsp_env.sh
bash -n ./scripts/ci_smoke.sh
bash -n ./rails-framework/scripts/run_framework_workflow.sh
bash -n ./rails-diagnose/scripts/run_diagnose.sh
bash -n ./rails-implementation-safety/scripts/safety_check.sh
bash -n ./rails-quality-gates/scripts/run_gates.sh

echo "[INFO] Validating --help surfaces..."
./install_skills_codex_claude.sh --help >/dev/null
./uninstall_skills_codex_claude.sh --help >/dev/null
./scripts/check_lsp_env.sh --help >/dev/null
./rails-framework/scripts/run_framework_workflow.sh --help >/dev/null
./rails-diagnose/scripts/run_diagnose.sh --help >/dev/null
./rails-implementation-safety/scripts/safety_check.sh --help >/dev/null
./rails-quality-gates/scripts/run_gates.sh --help >/dev/null

echo "[INFO] Validating strict LSP preflight failure path..."
if ENABLE_LSP_TOOL=0 ./scripts/check_lsp_env.sh --required >/dev/null 2>&1; then
  echo "[FAIL] check_lsp_env.sh --required should fail when ENABLE_LSP_TOOL!=1"
  exit 1
fi

echo "[INFO] Running framework dry smoke (no gem install, advisory mode)..."
./rails-framework/scripts/run_framework_workflow.sh \
  --project-dir "$ROOT_DIR" \
  --mode advisory \
  --no-auto-install-gems \
  --output-dir "$ROOT_DIR/tmp/ci-framework-smoke" >/dev/null

echo "[PASS] CI smoke checks completed."
