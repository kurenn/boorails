---
name: rails-quality-gates
description: Runs and interprets quality gates for Ruby on Rails delivery. Use when validating PR readiness, release safety, or implementation quality across tests, linting, security, and performance checks. Triggers on quality gate, readiness, release check, CI parity, lint, test suite, security scan, or pre-merge validation.
---

# Rails Quality Gates

## Overview

Use this skill to enforce a consistent definition of done before merging or deploying Rails changes.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but highlight reduced confidence in code navigation-based checks.

## Gate Order

Run fast-to-slow for rapid feedback:

1. Syntax and static sanity.
2. Lint/style.
3. Targeted tests for touched scope.
4. Security scan.
5. Performance smoke checks.

## Standard Commands

Use available tools in project context. Typical sequence:

1. `bundle exec rubocop`
2. `bundle exec rspec` or focused specs
3. `bundle exec brakeman`
4. Performance spot checks (query count, N+1, endpoint timing)

If a tool is unavailable, report as `Not Run` with reason and risk impact.

## Scripted Execution

Use the bundled script for repeatable gate runs:

1. `scripts/run_gates.sh`
2. `scripts/run_gates.sh --test-target spec/requests/users_spec.rb`
3. `scripts/run_gates.sh --mode advisory --skip-security`
4. `scripts/run_gates.sh --perf-command "bundle exec ruby scripts/perf_smoke.rb"`
5. `scripts/run_gates.sh --require-lsp` (hard fail if `ENABLE_LSP_TOOL!=1`)

Default behavior:

1. Runs syntax/autoload, lint, tests, security, and optional performance smoke.
2. Persists logs in `tmp/rails-quality-gates-<timestamp>/`.
3. Produces `PASS`, `WARN`, or `FAIL` overall summary.

Use `--output-file <path>` to persist a markdown report for PR or release notes.

## Gate Decisions

1. Pass: no blocking failures.
2. Warn: non-blocking issues with mitigation.
3. Fail: must fix before merge.

## Output Contract

1. Gate Summary (pass/warn/fail).
2. Detailed Results by gate.
3. Blocking Issues.
4. Suggested Fixes.
5. Follow-up Checks.

## Final Summary (Required)

Always end execution with:

1. Overall gate status: pass, warn, or fail.
2. Blocking gates and why.
3. Non-blocking warnings.
4. Commands executed (or skipped with reason).
5. Merge/deploy recommendation.

## References

Load [references/external-resources.md](references/external-resources.md) for official guides and tooling docs.
