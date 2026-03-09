---
name: rails-diagnose
description: Performs root-cause diagnosis for Ruby on Rails issues across performance, correctness, architecture, security, and reliability. Use when requests involve bugs, regressions, N+1 queries, slow endpoints, flaky tests, unexpected behavior, or unclear failures. Triggers on words like diagnose, debug, investigate, root cause, slowdown, flaky, regression, N+1, timeout.
---

# Rails Diagnose

## Overview

Use this skill to move from symptom to root cause with evidence, not guesses.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but mark reduced confidence for symbol-resolution findings.

## Diagnostic Workflow

1. Reproduce: Confirm the problem and capture exact failure signal.
2. Scope: Identify impacted code paths, models, endpoints, and environments.
3. Observe: Inspect logs, queries, stack traces, and recent changes.
4. Hypothesize: List candidate causes and rank by probability.
5. Prove: Validate or invalidate each hypothesis with targeted checks.
6. Conclude: Report root cause, fix plan, and prevention step.

## Investigation Matrix

1. Performance: query count, N+1 patterns, missing indexes, cache misses.
2. Correctness: wrong assumptions, nil handling, callback side effects.
3. Security: unsafe params, interpolation in SQL, authorization gaps.
4. Reliability: flaky specs, race conditions, background retry behavior.

## Evidence Requirements

Never close diagnosis without at least one direct evidence source:

1. Repro steps.
2. Log/trace evidence.
3. Query or timing evidence.
4. Test demonstrating failure and/or fix.

## Scripted Execution

Use the bundled diagnostic runner for repeatable investigation:

1. `scripts/run_diagnose.sh`
2. `scripts/run_diagnose.sh --project-dir /path/to/rails-app`
3. `scripts/run_diagnose.sh --mode advisory --output-file tmp/diagnose-report.md`
4. `scripts/run_diagnose.sh --require-lsp` (hard fail if `ENABLE_LSP_TOOL!=1`)

Default behavior:

1. Scans for likely N+1 hotspots, broad rescue patterns, callback overload, oversized controllers, flaky test hints, and job idempotency risk.
2. Categorizes findings into `HIGH`, `MEDIUM`, and `LOW`.
3. Persists logs in `tmp/rails-diagnose-<timestamp>/`.

In `strict` mode, `HIGH` findings return exit code `1`.

## Output Contract

1. Symptom.
2. Root Cause.
3. Evidence.
4. Primary Fix.
5. Alternative Fix.
6. Guardrail to prevent recurrence.

## Final Summary (Required)

Always end execution with:

1. Diagnostic outcome: confirmed root cause or pending unknown.
2. Top findings by severity.
3. Recommended fix and one alternative.
4. Evidence references used.
5. Immediate next step.

## References

Load [references/external-resources.md](references/external-resources.md) for canonical debugging and Active Record references.
