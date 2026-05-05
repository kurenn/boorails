# SQL Injection Hardening

## Secure Patterns

1. Prefer ActiveRecord hash conditions (`where(name: value)`).
2. Use placeholders for complex clauses (`where("name = ?", value)`).
3. Use `sanitize_sql_like` for `LIKE` patterns.
4. Use allowlists for dynamic sort columns/directions.

## High-Risk Patterns

1. String interpolation inside query strings.
2. Dynamic `order/group/having` using unvalidated params.
3. Raw SQL concatenation from request input.

## Verification

1. Search for `#{` inside query method arguments.
2. Review dynamic sort/order code for strict allowlists.
3. Confirm no interpolated SQL in scopes/query objects.
