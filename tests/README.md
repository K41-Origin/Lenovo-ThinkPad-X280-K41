# Tests

Status: First-slice common/preflight tests are implemented and passed locally against temporary copies whose Git blob hashes matched the committed files. The installer itself remains a skeleton and has not been tested end to end.

Run the first-slice unit tests from the repository root with `bash tests/test-common-preflight.sh`. This exercises mocked/read-only helper behavior and does not test installer integration.

Initial test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests must use mocks/loop devices in an isolated environment; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) must be marked NOT TESTED until run on the actual device.

Never treat a successful syntax check as proof that installation works.
