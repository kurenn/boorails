# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] — 2026-05-05

**Breaking** repackaging as a Claude Code plugin. All 7 skills renamed
under the `boo-*` namespace to avoid clash with sister tools that also
ship Rails-specific skills.

### Renamed (breaking)

| Old skill name | New skill name |
|---|---|
| `rails-alternatives` | `boo-alternatives` |
| `rails-diagnose` | `boo-diagnose` |
| `rails-framework` | `boo-framework` |
| `rails-fun-dx` | `boo-dx` |
| `rails-implementation-safety` | `boo-safety` |
| `rails-quality-gates` | `boo-quality` |
| `rails-security` | `boo-security` |

The user-visible output directory naming (e.g. `tmp/rails-security-<run-id>/`)
is preserved — only the slash-command names changed.

### Added

- `.claude-plugin/plugin.json` manifest. Install via marketplace:
  ```
  claude plugin marketplace add kurenn/marketplace
  claude plugin install boorails@kurenn
  ```

### Changed

- All 7 skill directories moved from repo root into `skills/` to follow
  the Claude Code plugin layout convention.
- Cross-skill references inside SKILL.md files updated to the new boo-*
  names (e.g. `boo-framework` now points to `boo-diagnose`, `boo-security`,
  etc., not the old `rails-*` names).
- Hardcoded absolute paths (`/Users/abrahamkuri/workspace/workspace/...`)
  replaced with `${CLAUDE_PLUGIN_ROOT}` for portable plugin install.

### Moved

- `install_skills_codex_claude.sh`, `uninstall_skills_codex_claude.sh`, and
  `update_skills.sh` moved to `legacy/` since the marketplace install path
  obsoletes them. Kept available for users who installed via the legacy
  manual script flow.

### Migration

If you installed boorails via the legacy `install_skills_codex_claude.sh`
script, the slash commands you've been using (`rails-security`, etc.) no
longer exist under those names. You have two options:

1. **Switch to the marketplace install** (recommended):
   ```
   bash legacy/uninstall_skills_codex_claude.sh
   claude plugin marketplace add kurenn/marketplace
   claude plugin install boorails@kurenn
   ```
   New slash commands: `/boo-security`, `/boo-quality`, etc.

2. **Stay on the legacy install** by checking out `v0.2.0`:
   ```
   git checkout v0.2.0
   bash install_skills_codex_claude.sh
   ```
   The old `rails-*` skill names still work on that tag.

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
