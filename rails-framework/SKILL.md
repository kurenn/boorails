---
name: rails-framework
description: Defines the operating framework for AI-assisted Ruby on Rails development. Use when planning architecture, framing implementation strategy, creating multi-step workflows, coordinating specialized Rails skills, or aligning a team on a consistent delivery model. Triggers on requests like framework definition, implementation workflow, Rails standards, feature planning, or system-level guidance.
---

# Rails Framework

## Overview

Use this skill as the top-level operating system for Rails work. It standardizes how requests are analyzed, implemented, verified, and improved.

## Execution Default (Required)

When this skill is invoked in Claude/Codex and shell execution is available, execute the workflow script first from the Rails app root unless the user explicitly asks for inspect-only output:

1. `bash /Users/abrahamkuri/workspace/workspace/rails skills/rails-framework/scripts/run_framework_workflow.sh --project-dir "$PWD" --mode strict --gemset full`
2. If LSP is required: add `--require-lsp`.
3. If user asks no changes: use `--gem-dry-run` or `--no-auto-install-gems`.

Do not claim framework execution is complete without showing the generated summary path (`tmp/rails-framework-workflow-*/00-summary.md`).

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but mark reduced confidence for symbol navigation and code-intel findings.

## Prompt Suggestions

Use one of these prompts when invoking this skill in Claude.

1. Whole-project inspection:
   `Use rails-framework. Inspect the whole Rails project first (app/, config/, db/, lib/, spec/) and return: architecture map, top risks, and prioritized next actions. Do not implement yet.`
2. Inspection + implementation:
   `Use rails-framework. Run Inspect -> Diagnose -> Design -> Implement -> Verify -> Improve for this project. Implement only the top 2 high-impact fixes and summarize residual risks.`
3. Release readiness:
   `Use rails-framework for pre-release hardening. Focus on performance, security, migrations, and test reliability. Return blockers, fixes, alternatives, and rollback notes.`
4. Force execution (recommended):
   `Use rails-framework and execute the framework workflow script immediately against the current project. Then return the summary report and key findings.`

When asking for a full inspection, always include:

1. Scope directories (for example: `app/, config/, db/, spec/`).
2. Priority focus (for example: N+1, auth gaps, risky migrations, flaky tests).
3. Implementation boundary (`inspect only` or `implement top N fixes`).

## Core Loop

Apply this sequence for every meaningful request:

1. Inspect: Understand context, conventions, dependencies, and constraints.
2. Diagnose: Identify risks, hotspots, unknowns, and likely failure modes.
3. Design: Pick a primary approach and at least one alternative.
4. Implement: Apply conventions-first Rails changes.
5. Verify: Run quality checks and targeted validation.
6. Improve: Capture patterns for reuse in skills/scripts.

## Output Contract

Every downstream skill response should include:

1. Context: What was inspected.
2. Findings: What matters and why.
3. Primary Fix: Chosen implementation path.
4. Alternatives: At least one credible option with tradeoffs.
5. Validation: What was checked and results.
6. Risk: Residual risk and rollback strategy.
7. Change Log: files changed, short summary per file, and rollback hint.

## Final Summary (Required)

Always end execution with:

1. Outcome: pass, warn, or fail.
2. What changed: files and short reason.
3. What was validated: checks run and status.
4. Remaining risk: unresolved items.
5. Next step: single highest-priority action.

## Orchestration Rules

Use specialized skills when needed:

1. Root-cause unclear: invoke `rails-diagnose`.
2. Deep appsec review needed: invoke `rails-security`.
3. Release readiness needed: invoke `rails-quality-gates`.
4. Security/data safety concerns: invoke `rails-implementation-safety`.
5. Architectural choice needed: invoke `rails-alternatives`.
6. Developer friction or slow loop: invoke `rails-fun-dx`.

## Scripted Orchestration

Use the workflow script to run core steps in sequence:

1. `scripts/run_framework_workflow.sh`
2. `scripts/run_framework_workflow.sh --project-dir /path/to/rails-app --mode advisory`
3. `scripts/run_framework_workflow.sh --test-target spec/requests/users_spec.rb`
4. `scripts/run_framework_workflow.sh --require-lsp` (hard fail if `ENABLE_LSP_TOOL!=1`)
5. `scripts/run_framework_workflow.sh --gemset minimal` (install only core gate gems)
6. `scripts/run_framework_workflow.sh --no-auto-install-gems` (skip gem bootstrap)

By default, the framework workflow bootstraps missing gems in the target Rails app before running steps.

Core (`--gemset minimal`):

1. `rubocop`
2. `rubocop-rails`
3. `brakeman`

Extended (`--gemset full`, default):

1. `rspec-rails`
2. `rubocop-rspec`
3. `bullet`
4. `strong_migrations`
5. `ruby-lsp`

The workflow executes:

1. `rails-diagnose/scripts/run_diagnose.sh`
2. `rails-security/scripts/run_security_audit.sh`
3. `rails-implementation-safety/scripts/safety_check.sh`
4. `rails-quality-gates/scripts/run_gates.sh`

Outputs are written to `tmp/rails-framework-workflow-<timestamp>/` with per-step reports and a consolidated summary.

## Non-Negotiables

1. Prefer Rails conventions over unnecessary abstraction.
2. Never skip validation for database, security, or production-impacting changes.
3. Avoid silent assumptions; surface unknowns explicitly.
4. Prefer reversible migrations and incremental rollout paths.

## References

Load [references/external-resources.md](references/external-resources.md) when decisions need canonical guidance.
