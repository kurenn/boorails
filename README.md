# BooRails

Script-first Ruby on Rails skills for safer shipping, faster diagnosis, and cleaner delivery — packaged as a [Claude Code](https://claude.ai/code) plugin.

Seven `boo-*` skills covering the Rails dev lifecycle from design to release. Each skill ships an executable script for deterministic execution and a SKILL.md that orchestrates the workflow inside Claude Code or Codex.

## Why BooRails?

Most AI workflows stop at suggestions. BooRails executes the Rails workflow end-to-end and returns evidence.

- Script-first framework execution (`Diagnose → Security → Safety → Quality Gates`)
- Explicit execution summary and report files
- Gem bootstrap feedback (target/present/installed/failed)
- LSP-aware guidance for stronger symbol-level analysis

## What's included

### Core orchestrator

- **`/boo-framework`** — orchestrates the full workflow, runs gem bootstrap, and produces a consolidated summary report.

### Six focused skills

| Skill | What it does |
|---|---|
| `/boo-diagnose` | Root-cause heuristics for reliability/performance smells |
| `/boo-security` | Deep appsec audit for XSS/SQLi/CSRF/uploads/command risks |
| `/boo-safety` | Implementation safety checks for risky patterns and migrations |
| `/boo-quality` | Tests/lint/security/smoke gates with pass/warn/fail |
| `/boo-alternatives` | Structured option/tradeoff evaluation |
| `/boo-dx` | Developer experience and loop-speed improvements |

## Install

### Recommended — via the kurenn marketplace

```bash
claude plugin marketplace add kurenn/marketplace   # one-time per user
claude plugin install boorails@kurenn              # one-time install
```

After install, restart your Claude Code session and the seven `/boo-*` skills appear in the slash menu.

To pull updates:

```bash
claude plugin marketplace update kurenn
claude plugin update boorails
```

### Local plugin dir (development)

```bash
git clone https://github.com/kurenn/boorails ~/workspace/boorails
claude --plugin-dir ~/workspace/boorails
```

### Legacy install (pre-2.0)

If you were using the manual shell-script install (`install_skills_codex_claude.sh`) and want to stay on it, those scripts are still in `legacy/`. They install the OLD `rails-*` skill names from the v0.2.0 tag. New work should switch to the marketplace install above.

## Use the skills

### 1) Start from your Rails app root

```bash
cd /path/to/your/rails_app
```

### 2) Enable LSP (recommended)

```bash
export ENABLE_LSP_TOOL=1
```

### 3) In a Claude Code session, run a slash command

```
/boo-framework
/boo-security
/boo-diagnose
/boo-quality
/boo-safety
/boo-alternatives
/boo-dx
```

Most common entrypoint: `/boo-framework`.

### 4) What success looks like for `/boo-framework`

Open:

- `tmp/rails-framework-workflow-<timestamp>/00-summary.md`

It links to:

- `00-framework-gems.md`
- `01-diagnose.md`
- `02-security.md`
- `03-safety.md`
- `04-quality-gates.md`

### Optional — run scripts directly from terminal

After plugin install, the scripts live under your Claude plugins cache. From any Rails app root:

```bash
PLUGIN=~/.claude/plugins/cache/kurenn/boorails/2.0.0
bash "$PLUGIN/skills/boo-framework/scripts/run_framework_workflow.sh" --project-dir "$PWD" --mode strict --gemset full --require-lsp
bash "$PLUGIN/skills/boo-diagnose/scripts/run_diagnose.sh" --project-dir "$PWD" --require-lsp
bash "$PLUGIN/skills/boo-security/scripts/run_security_audit.sh" --project-dir "$PWD" --require-lsp
bash "$PLUGIN/skills/boo-safety/scripts/safety_check.sh" --project-dir "$PWD" --require-lsp
bash "$PLUGIN/skills/boo-quality/scripts/run_gates.sh" --project-dir "$PWD" --require-lsp
```

## Gem bootstrap modes

- Default: installs missing gems (`--gemset full`)
- Core-only: `--gemset minimal`
- Dry-run only: `--gem-dry-run`
- Disable install: `--no-auto-install-gems`

## Smoke checks

```bash
./scripts/ci_smoke.sh
```

## Supported tools

- Claude Code
- Codex (via the legacy install path)

## Migrating from v0.2.x

If you've been using boorails via `install_skills_codex_claude.sh`, the slash commands you've been using (`/rails-security`, `/rails-framework`, etc.) no longer exist under those names in 2.0. Two options:

1. **Switch to the marketplace install** (recommended) — see CHANGELOG.md for the full migration table.
2. **Stay on v0.2** — `git checkout v0.2.0` and run the legacy install script. The old `rails-*` skill names still work on that tag.

## License

MIT. See [LICENSE](LICENSE).
