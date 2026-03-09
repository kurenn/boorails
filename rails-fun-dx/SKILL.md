---
name: rails-fun-dx
description: Optimizes developer experience in Ruby on Rails workflows without compromising safety or quality. Use when teams face slow feedback loops, repetitive tasks, unclear errors, onboarding friction, or low development flow. Triggers on DX, developer productivity, faster feedback, workflow friction, onboarding, and ergonomics.
---

# Rails Fun DX

## Overview

Use this skill to make Rails development faster, clearer, and more enjoyable while preserving production standards.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but note reduced precision for refactor/navigation suggestions.

## DX Optimization Areas

1. Feedback Loop Speed: shorten edit-test-debug cycles.
2. Cognitive Load: simplify workflows and naming.
3. Repetition Reduction: templates, scripts, and defaults.
4. Error Clarity: improve messages and failure hints.
5. Onboarding Flow: make first contribution easier.

## Improvement Workflow

1. Identify top friction points.
2. Estimate effort vs impact.
3. Ship high-impact quick wins first.
4. Validate no regression in safety/quality gates.
5. Document the new workflow.

## Guardrails

1. Never trade away security for speed.
2. Never skip test coverage for convenience.
3. Prefer small, reversible workflow changes.

## Output Contract

1. Friction Findings.
2. Quick Wins.
3. Structural Improvements.
4. Impact Forecast.
5. Validation Plan.

## Final Summary (Required)

Always end execution with:

1. DX outcome and expected impact.
2. Changes proposed/implemented.
3. Safety and quality constraints preserved.
4. Validation approach.
5. Next highest-impact DX improvement.

## References

Load [references/external-resources.md](references/external-resources.md) for Rails philosophy and workflow practices.
