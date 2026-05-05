# Security Review Checklist

## Blockers

1. SQL interpolation from request/user input.
2. Interpolated command execution or eval-family usage on untrusted input.
3. CSRF disabled on non-API/session-authenticated controllers.
4. User-controlled HTML rendered unsafely (`html_safe`/`raw`) without strict sanitization.

## Warnings

1. Missing CSP initializer or permissive CSP policy.
2. Uploads without explicit type/size validation.
3. Missing session cookie hardening flags.
4. Dangerous file types not forced to binary download.
5. Strong-params gaps in write actions.

## Validation Evidence

1. Brakeman results (if available).
2. Focused grep/static findings with file references.
3. Targeted tests for remediated paths.
4. Residual risk statement for items intentionally deferred.
