---
name: rails-security
description: Deep security workflow for Ruby on Rails applications. Use when auditing or implementing controls for XSS, SQL injection, CSRF, file uploads, command injection, session/cookie hardening, and security monitoring. Triggers on appsec audit, security review, OWASP, CSP, CSRF, upload hardening, or secure coding requests.
---

# Rails Security

## Overview

Use this skill for focused application security work in Rails. It complements broad safety and quality checks with deeper, security-specific analysis and remediations.

## Execution Default (Required)

When shell execution is available and the user does not request inspect-only output, run:

1. `bash /Users/abrahamkuri/workspace/workspace/rails skills/rails-security/scripts/run_security_audit.sh --project-dir "$PWD" --mode strict`
2. Add `--require-lsp` when symbol-level confidence is required.
3. For non-mutating audits, pair with `rails-framework` in inspect/advisory mode.

Do not claim completion without reporting the generated summary path: `tmp/rails-security-*/00-summary.md`.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is disabled, continue but mark reduced confidence for cross-file security findings.

## Threat Scope

Prioritize these rails-relevant vectors:

1. XSS in views/components/helpers.
2. SQL injection in dynamic query composition.
3. CSRF gaps in cookie/session-authenticated flows.
4. File upload abuse (type spoofing, dangerous inline formats, oversized uploads).
5. Command injection and path traversal.
6. Weak session/cookie and header hardening.

## Non-Negotiables

1. Never allow SQL interpolation with user input.
2. Never allow command execution with interpolated user input.
3. Never skip CSRF checks for session-authenticated controllers.
4. Never trust upload filename/content-type alone.
5. Never mark security checks as pass without evidence.

## Workflow

1. Inspect: map auth model, input surfaces, upload paths, command execution points.
2. Diagnose: run scripted audit and targeted grep-based checks.
3. Design: choose primary fix and one alternative with tradeoffs.
4. Implement: apply minimal, reversible hardening changes.
5. Verify: run security checks/tests and explain residual risk.
6. Improve: capture reusable guardrails/tests for recurrence prevention.

## Scripted Execution

Use the bundled security runner:

1. `scripts/run_security_audit.sh`
2. `scripts/run_security_audit.sh --project-dir /path/to/rails-app`
3. `scripts/run_security_audit.sh --mode advisory --output-file tmp/security-report.md`
4. `scripts/run_security_audit.sh --skip-brakeman` (if Brakeman not available)
5. `scripts/run_security_audit.sh --require-lsp` (hard fail if `ENABLE_LSP_TOOL!=1`)

Default behavior:

1. Runs Brakeman when available and summarizes confidence counts.
2. Scans for critical rails security anti-patterns.
3. Produces `PASS`, `WARN`, or `FAIL` with blocker/warn split.
4. Persists logs in `tmp/rails-security-<timestamp>/`.

In `strict` mode, blockers return exit code `1`.

## Output Contract

1. Surface map: where risky input enters and is rendered/executed.
2. Blockers: must-fix items with file-level evidence.
3. Warnings: important but non-blocking hardening gaps.
4. Primary remediation plan + one alternative.
5. Validation evidence (commands run and outputs).
6. Residual risk and rollback notes.
7. Change log summary (if implementation happened).

## Final Summary (Required)

Always end with:

1. Security outcome: pass, warn, or fail.
2. Blockers that prevent merge/release.
3. Key warnings and mitigations.
4. Evidence used (reports/tests/logs).
5. Single highest-priority next action.

## References

Load these files only when needed:

1. [references/xss.md](references/xss.md)
2. [references/sql-injection.md](references/sql-injection.md)
3. [references/csrf.md](references/csrf.md)
4. [references/uploads.md](references/uploads.md)
5. [references/command-injection.md](references/command-injection.md)
6. [references/checklist.md](references/checklist.md)
7. [references/external-resources.md](references/external-resources.md)
