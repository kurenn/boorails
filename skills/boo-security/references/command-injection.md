# Command and Path Injection Hardening

## Secure Execution

1. Use array-argument form for process execution (`system("cmd", arg1, arg2)`).
2. Prefer Ruby APIs (`FileUtils`, `Open3`, library calls) over shell commands.
3. Validate user-derived args with strict allowlists.

## High-Risk Patterns

1. Interpolated shell commands.
2. Backticks / `%x()` with user input.
3. `eval`, `instance_eval`, `class_eval` on untrusted input.
4. Path traversal via `../` and unchecked `send_file` paths.

## Verification

1. Search command invocations for interpolation.
2. Validate any user-controlled path via `expand_path` + base-dir prefix checks.
3. Confirm high-risk operations are isolated and logged.
