# Reports

This directory is the output root for runtime diagnostics, validation, test runs, and repair evidence.

## Policy

- Runtime-generated reports are local artifacts by default and are ignored by Git.
- Do not commit every diagnostic run. Keep only small, reviewed, redacted evidence that is necessary for a documented acceptance decision.
- Historical reports already committed before this policy are preserved in [archive/2026-11](archive/2026-11/README.md).
- Historical snapshots are not current system state. Use the owning document in `docs/` for current decisions and status.
- Never store passwords, LUKS passphrases/recovery keys, tokens, cookies, or credentials in reports.
- Review hardware identifiers, serial numbers, journal excerpts, usernames, paths, and network metadata before sharing or curating evidence.

## Runtime compatibility

Existing scripts continue writing to their established `reports/<category>/<timestamp>/` paths. Those paths are intentionally unchanged; newly generated output remains local and is not committed automatically.

## AI and maintenance guidance

Do not enumerate or read `reports/archive/` during routine repository work. Access a specific archived artifact only when historical investigation is explicitly required or a current document links to it.
