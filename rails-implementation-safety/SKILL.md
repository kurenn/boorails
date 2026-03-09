---
name: rails-implementation-safety
description: Applies implementation safety checklists for Ruby on Rails code changes. Use when writing or reviewing code that touches user input, authorization, database migrations, background jobs, external APIs, or production-critical paths. Triggers on secure, safe migration, pre-merge checklist, rollout risk, data integrity, and production hardening.
---

# Rails Implementation Safety

## Overview

Use this skill before finalizing code to reduce production risk and prevent common Rails failure patterns.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but mark reduced confidence for symbol-level static checks.

## Safety Checklist

1. Input Safety: strong params, sanitization, no unsafe SQL interpolation.
2. Auth Safety: authenticate and authorize all protected flows.
3. Data Safety: reversible migrations, constraints, index strategy.
4. Async Safety: idempotent jobs, retry behavior, dead-letter handling.
5. Runtime Safety: nil handling, explicit error paths, timeouts.
6. Deploy Safety: rollout plan, rollback path, observability hooks.

## Blockers

Do not mark ready if any blocker exists:

1. Unbounded destructive migration.
2. Missing authorization on sensitive action.
3. Unsanitized user input in dangerous context.
4. Unverified background side effects.

## Scripted Execution

Use the bundled checker for repeatable safety audits:

1. `scripts/safety_check.sh`
2. `scripts/safety_check.sh --project-dir /path/to/rails-app`
3. `scripts/safety_check.sh --mode advisory`
4. `scripts/safety_check.sh --output-file tmp/safety-report.md`
5. `scripts/safety_check.sh --require-lsp` (hard fail if `ENABLE_LSP_TOOL!=1`)

Default behavior:

1. Detects blockers for SQL interpolation, command/code injection vectors, risky migrations, XSS-prone rendering helpers, and open redirects.
2. Detects warnings for likely strong-params gaps, CSRF layout issues, upload validation gaps, and non-idempotent job patterns.
3. Persists logs in `tmp/rails-safety-check-<timestamp>/`.

In `strict` mode, any blocker returns exit code `1`.

## Output Contract

1. Checklist Status.
2. Blockers.
3. Remediations.
4. Residual Risk.
5. Rollback Notes.

## Final Summary (Required)

Always end execution with:

1. Safety outcome: pass, warn, or fail.
2. Blockers that must be fixed before merge.
3. Warnings and mitigations.
4. Rollback readiness note.
5. Next safest action.

## References

Load [references/external-resources.md](references/external-resources.md) for Rails Security and OWASP-aligned checks.
