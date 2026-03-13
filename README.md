# BooRails

Script-first Ruby on Rails skills for safer shipping, faster diagnosis, and cleaner delivery.

> **Quick start (install):**
> `bash -lc 'set -euo pipefail; REPO="$HOME/.boorails"; [ -d "$REPO/.git" ] || git clone https://github.com/kurenn/boorails.git "$REPO"; git -C "$REPO" pull --ff-only origin main; "$REPO"/install_skills_codex_claude.sh --target both --force'`

## Why BooRails?

Most AI workflows stop at suggestions. BooRails is built to execute the Rails workflow end-to-end and return evidence.

- Script-first framework execution (`Diagnose -> Security -> Safety -> Quality Gates`)
- Explicit execution summary and report files
- Gem bootstrap feedback (target/present/installed/failed)
- LSP-aware guidance for stronger symbol-level analysis

## What's Included

### Core Framework

- `rails-framework`: orchestrates workflow, gem bootstrap, and consolidated summary.

### 6 Supporting Skills

| Skill | What it does |
|------|---------------|
| `rails-diagnose` | Root-cause heuristics for reliability/performance smells |
| `rails-security` | Deep appsec audit for XSS/SQLi/CSRF/uploads/command risks |
| `rails-implementation-safety` | Safety checks for risky patterns and migrations |
| `rails-quality-gates` | Tests/lint/security/smoke gates with pass/warn/fail |
| `rails-alternatives` | Structured option/tradeoff evaluation |
| `rails-fun-dx` | Developer experience and loop-speed improvements |

## Installation

### One-liner (Recommended)

```bash
bash -lc 'set -euo pipefail; REPO="$HOME/.boorails"; [ -d "$REPO/.git" ] || git clone https://github.com/kurenn/boorails.git "$REPO"; git -C "$REPO" pull --ff-only origin main; "$REPO"/install_skills_codex_claude.sh --target both --force'
```

### Manual

```bash
git clone https://github.com/kurenn/boorails.git "$HOME/.boorails"
cd "$HOME/.boorails"
./install_skills_codex_claude.sh --target both --force
```

## Update

### One-liner update (pull + reinstall)

```bash
bash -lc 'set -euo pipefail; REPO="$HOME/.boorails"; [ -d "$REPO/.git" ] || git clone https://github.com/kurenn/boorails.git "$REPO"; "$REPO"/update_skills.sh --repo-dir "$REPO"'
```

### Local update command

```bash
./update_skills.sh
```

## Use Skills in Claude/Codex

### 1) Start from your Rails app root

```bash
cd /path/to/your/rails_app
```

### 2) Enable LSP (recommended)

```bash
export ENABLE_LSP_TOOL=1
```

### 3) Run slash commands

```text
/rails-framework
/rails-security
/rails-diagnose
/rails-quality-gates
/rails-implementation-safety
/rails-alternatives
/rails-fun-dx
```

Most common entrypoint: `/rails-framework`

### 4) What success looks like for `/rails-framework`

Open:

- `tmp/rails-framework-workflow-<timestamp>/00-summary.md`

It links to:

- `00-framework-gems.md`
- `01-diagnose.md`
- `02-security.md`
- `03-safety.md`
- `04-quality-gates.md`

### Optional: Run framework script directly from terminal

```bash
bash "$HOME/.boorails/rails-framework/scripts/run_framework_workflow.sh" --project-dir "$PWD" --mode strict --gemset full --require-lsp
```

## Run Individual Skills (Optional)

```bash
bash "$HOME/.boorails/rails-diagnose/scripts/run_diagnose.sh" --project-dir "$PWD" --require-lsp
bash "$HOME/.boorails/rails-security/scripts/run_security_audit.sh" --project-dir "$PWD" --require-lsp
bash "$HOME/.boorails/rails-implementation-safety/scripts/safety_check.sh" --project-dir "$PWD" --require-lsp
bash "$HOME/.boorails/rails-quality-gates/scripts/run_gates.sh" --project-dir "$PWD" --require-lsp
```

## Gem Bootstrap Modes

- Default: installs missing gems (`--gemset full`)
- Core-only: `--gemset minimal`
- Dry-run only: `--gem-dry-run`
- Disable install: `--no-auto-install-gems`

## Smoke Checks

```bash
./scripts/ci_smoke.sh
```

## Supported Tools

- Claude Code
- Codex

## License

MIT. See [LICENSE](LICENSE).
