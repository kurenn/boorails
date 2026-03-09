---
name: rails-alternatives
description: Generates and compares implementation alternatives for Ruby on Rails decisions. Use when choosing between architectural approaches, query patterns, service boundaries, framework features, or rollout strategies. Triggers on alternatives, tradeoffs, option A/B, design choice, compare approaches, or should we use X vs Y.
---

# Rails Alternatives

## Overview

Use this skill when a single answer is risky or when decisions involve meaningful tradeoffs.

## LSP Recommendation

Strongly recommend enabling LSP before running this skill:

1. `ENABLE_LSP_TOOL=1` in the shell running Claude/Codex.
2. Run from the Rails app root directory.
3. Ensure a Ruby LSP backend is available in the app bundle (`ruby-lsp` and/or `solargraph`).

If LSP is not enabled, continue execution but call out lower confidence on dependency-impact analysis.

## Alternative Generation Rules

Always provide at least two and usually three options:

1. Conservative option: lowest risk, highest convention fit.
2. Balanced option: best overall tradeoff.
3. Aggressive option: highest speed or leverage with more risk.

## Comparison Dimensions

Score each option using:

1. Delivery Speed.
2. Complexity.
3. Security/Data Risk.
4. Performance Impact.
5. Maintainability.
6. Reversibility.

## Recommendation Rule

State one recommended option and explicitly justify it. Do not provide options without a recommendation unless user asks for neutral comparison only.

## Output Contract

1. Option Matrix.
2. Recommended Path.
3. Why Not the Others.
4. Migration/Rollback Plan.

## Final Summary (Required)

Always end execution with:

1. Recommended option and reason.
2. Key tradeoffs accepted.
3. Main risk and mitigation.
4. Rollback/reversibility note.
5. Immediate execution step.

## References

Load [references/external-resources.md](references/external-resources.md) for architectural and Rails guideline references.
