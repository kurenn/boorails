# CSRF Hardening

## Session-Based Apps

1. Keep CSRF protection enabled for cookie-authenticated controllers.
2. Ensure `csrf_meta_tags` exists in active layout.
3. Ensure JS requests send `X-CSRF-Token`.
4. Prefer `same_site: :lax` or stricter where possible.

## Stateless APIs

1. Only skip CSRF in truly stateless API controllers.
2. Require explicit token auth (`Authorization: Bearer ...`).
3. Do not mix cookie-session auth with CSRF disabled endpoints.

## Verification

1. Find all `skip_before_action :verify_authenticity_token` usages.
2. Classify each as API-safe vs risky/non-API usage.
3. Validate session store flags: `secure`, `httponly`, `same_site`.
