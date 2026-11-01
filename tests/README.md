# Tests

Status: First-slice common/preflight tests are implemented and passed locally against temporary copies whose Git blob hashes matched the committed files. The installer now has a diagnostic-only entry point and focused entry-point tests; actual installation remains unimplemented and has not been tested end to end.

Run the focused tests from the repository root with `bash tests/test-common-preflight.sh`, `bash tests/test-installer-entry.sh`, and `bash tests/test-preflight-gate.sh`. The entry test checks argument handling, relative module loading, diagnostic-only behavior, and a static safety boundary. The gate test uses a mocked preflight module in a temporary copy to exercise unresolved boot-mode, required-command, and optional network-diagnostic outcomes. These are not end-to-end installation tests.

Initial test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests must use mocks/loop devices in an isolated environment; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) must be marked NOT TESTED until run on the actual device.

Never treat a successful syntax check as proof that installation works.
