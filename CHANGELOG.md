# Changelog

All notable changes to this project will be documented in this file.

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
