# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-03-09

### Added
- New `rails-security` skill with focused references:
  - XSS hardening
  - SQL injection prevention
  - CSRF/session hardening
  - Upload security
  - Command/path injection prevention
  - Security review checklist
- New deterministic security runner:
  - `rails-security/scripts/run_security_audit.sh`
  - Blocker/Warn/Pass summary output in `tmp/rails-security-<timestamp>/00-summary.md`
  - Optional Brakeman execution with structured triage

### Changed
- `rails-framework` workflow now runs:
  - Diagnose -> Security Audit -> Implementation Safety -> Quality Gates
- Framework summary/report outputs now include explicit security step artifacts.
- README installation/run docs updated for script-first workflow clarity and security step outputs.
- Homepage content updated to reflect security step in framework flow and skill stack.

### Fixed
- Framework gem bootstrap summary now reports target/present/installed/failed counters consistently.
- Clarified runbook and output verification guidance for Claude/Codex usage.

## [0.1.1] - 2026-03-08

### Changed
- Rebranded project docs/site surface from Rails Forge to BooRails.

### Added
- GitHub Pages custom domain file (`CNAME`) for `boorails.dev`.


## [0.1.0] - 2026-03-08

### Added
- Initial Rails skills suite:
  - rails-framework
  - rails-diagnose
  - rails-implementation-safety
  - rails-quality-gates
  - rails-alternatives
  - rails-fun-dx
- Installer and uninstaller for Codex and Claude skills.
- LSP preflight checker: `scripts/check_lsp_env.sh`.
- Framework workflow with structured execution summaries.
- Optional strict LSP enforcement via `--require-lsp`.
- Framework gem bootstrap support in workflow (`minimal` and `full` gemsets).
- Website landing page inspired by hacker/terminal style.
- CI smoke workflow to validate scripts and docs.
