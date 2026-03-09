# Upload Hardening

## Baseline

1. Prefer ActiveStorage over manual file writes.
2. Validate uploads by content type, extension, and size.
3. Sanitize/ignore user-provided filenames for storage.
4. Store outside `public/` and serve through authenticated controllers when sensitive.

## Extended Controls

1. For high-risk uploads, validate magic bytes/signatures.
2. Force dangerous formats to binary download (for example `image/svg+xml`, `text/html`).
3. Add malware scanning in production workflows.

## Verification

1. Detect attachment declarations (`has_one_attached`, `has_many_attached`).
2. Confirm matching validations exist for allowed type/size.
3. Check ActiveStorage inline/binary content type configuration.
