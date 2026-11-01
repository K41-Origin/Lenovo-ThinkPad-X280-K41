# Implementation Status and Changelog

## Status

| Area | Status | Evidence / next action |
| --- | --- | --- |
| Repository baseline | VERIFIED | Initial commit inspected; baseline contains LICENSE and a minimal README.md. |
| Requirements capture | IMPLEMENTED | User-approved planning choices recorded in requirements/decision log. |
| Documentation split | IMPLEMENTED | Domain documents added in this change. |
| Installer architecture | PLANNED | Verify upstream dependencies and installation/post-install boundary. |
| ISO installer | PLANNED | Not implemented. |
| Post-install setup | PLANNED | Not implemented. |
| Hardware optimization | PLANNED | Actual hardware inventory and compatibility checks required. |
| Automated tests | PLANNED | No installer code added; no installer tests run. |
| X280 installation / hibernation | NOT TESTED | Requires controlled hardware testing. |

## Changelog

### 2026-11-01 — Documentation split
- Added project charter, requirements/decisions, architecture outline, installation/disk, security/authentication, desktop UX, hardware/power/network, package/software management, development/bug bounty, recovery/reporting, testing/acceptance, and implementation status.
- README is the intended project entry point and documentation index.
- No installer code or system configuration changed.
- No installer behavior was tested or verified by this documentation change.

## Updating status
- PLANNED: not implemented.
- IMPLEMENTED: changes exist.
- TESTED: specified tests ran.
- VERIFIED: behavior confirmed with evidence.
- RELEASED: included in a designated release.

For each test, record the exact test/command, date, outcome, and limitations. Writing a configuration file alone does not verify behavior.
