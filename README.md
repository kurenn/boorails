# BooRails

BooRails is a local set of AI skills for safer, faster Ruby on Rails development.

## Before Running Any Skill (Recommended)

Enable LSP in the shell where you launch Claude/Codex:

```bash
export ENABLE_LSP_TOOL=1
```

Why this matters:

- Better symbol navigation and code-intel quality.
- More accurate cross-file analysis and refactor safety.
- Higher confidence in diagnose, safety, and quality-gate results.

If you want strict enforcement, run skills with `--require-lsp`.

## Quick Preflight

```bash
./scripts/check_lsp_env.sh
```

Strict mode (fails if LSP is not enabled):

```bash
./scripts/check_lsp_env.sh --required
```

## Install Skills

```bash
./install_skills_codex_claude.sh --target both
```

## Smoke Checks

Run local smoke checks before release:

```bash
./scripts/ci_smoke.sh
```

## Framework Workflow Example

```bash
rails-framework/scripts/run_framework_workflow.sh --project-dir /path/to/rails-app --require-lsp
```

If you trigger `/rails-framework` inside Claude/Codex, explicitly ask it to execute the script (not just reason from instructions):

```text
Use rails-framework and run:
bash "/Users/abrahamkuri/workspace/workspace/rails skills/rails-framework/scripts/run_framework_workflow.sh" --project-dir "$PWD" --mode strict --gemset full --require-lsp
Then show tmp/rails-framework-workflow-*/00-summary.md
```

By default, `rails-framework` auto-installs missing framework gems before executing Diagnose/Safety/Gates.

- Default gemset (`full`): `rubocop`, `rubocop-rails`, `brakeman`, `rspec-rails`, `rubocop-rspec`, `bullet`, `strong_migrations`, `ruby-lsp`
- Core-only gemset (`minimal`): `rubocop`, `rubocop-rails`, `brakeman`

Opt-out and dry-run:

```bash
rails-framework/scripts/run_framework_workflow.sh --no-auto-install-gems
rails-framework/scripts/run_framework_workflow.sh --gem-dry-run --gemset full
```

## Multi-App Setup

For multiple Rails projects, prefer per-project environment setup (for example with `direnv`):

```bash
# .envrc
export ENABLE_LSP_TOOL=1
```

Then `direnv allow` in each app.

## Claude Prompt Example

```text
Use rails-framework. Inspect the whole Rails project first (app/, config/, db/, lib/, spec/) and return architecture map, top risks, and prioritized next actions.
```
