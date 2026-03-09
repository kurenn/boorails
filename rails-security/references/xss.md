# XSS Hardening

## Secure Defaults

1. Rely on Rails auto-escaping in ERB by default.
2. Treat `html_safe` and `raw` as security-sensitive operations.
3. Use `sanitize` with explicit allowlists for rich text.

## High-Risk Patterns

1. Rendering user input with `html_safe`.
2. Passing unsanitized user content into helper methods returning HTML-safe strings.
3. Inline scripts/styles without nonce-based CSP.

## Recommended Controls

1. Add and maintain `config/initializers/content_security_policy.rb`.
2. Use nonces for inline scripts that cannot be removed.
3. Keep rich text tags/attributes allowlists minimal.

## Verification

1. Search for `html_safe` and `raw(` in views/helpers/components.
2. Verify CSP exists and does not rely on permissive `unsafe-inline` for scripts.
3. Add tests for malicious payload rendering as escaped text.
