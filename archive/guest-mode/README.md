# Guest Mode — Archived Planning Artifacts

**Status: ARCHIVED — NOT PART OF THE ACTIVE PROJECT.**

Guest Mode was explicitly excluded from the active project scope. These files are retained only as historical planning/audit artifacts; they are not a workstream, roadmap item, implementation target, or acceptance gate.

## Contents

- `scripts/k41-guest-storage-audit.sh`: one consolidated copy of the former read-only audit collector. The duplicate root-level and Stage 5 copies were identical and have been consolidated here.
- `tests/test-guest-storage-audit.sh`: historical static safety/contract test. It is intentionally excluded from `tests/run.sh`.

The archived test references the archived collector and can be run manually from the repository root if historical review is needed. It is not part of the supported test suite.

No Guest account, service, mount, storage policy, or runtime workflow is installed or maintained by this repository.
