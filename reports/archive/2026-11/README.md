# Historical report archive — November 2026

The complete historical report snapshot is preserved in Git history in commit:

`02f6194ed04c8f13ea64eda35b7afb94f7006504`

Browse the immutable snapshot:
https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/tree/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11

- Preserved historical report files: **594**
- Snapshot period: **2026-11**
- Original category and timestamp paths were retained.
- No report contents were rewritten or intentionally discarded.
- The 594 report files are intentionally absent from the current `main` tree so routine repository and AI context stays focused. They remain retrievable from the snapshot commit.

Restore or inspect a specific file without checking out the old tree:

```bash
git show 02f6194ed04c8f13ea64eda35b7afb94f7006504:reports/archive/2026-11/<category>/<timestamp>/<file>
```

## Categories

| Category | Files |
|---|---:|
| `boot-audit` | 1 |
| `boot-visual-diagnostics` | 2 |
| `caelestia-audit` | 3 |
| `caelestia-customization` | 10 |
| `caelestia-diagnostics` | 6 |
| `caelestia-permissions-diagnostics` | 4 |
| `desktop` | 25 |
| `desktop-customization` | 6 |
| `desktop-customization-audit` | 53 |
| `desktop-customization-baseline` | 8 |
| `desktop-diagnostics` | 3 |
| `desktop-profile` | 4 |
| `desktop-repair` | 40 |
| `desktop-validation` | 344 |
| `first-boot` | 25 |
| `guest-mode-audit` | 5 |
| `hardware-audit` | 2 |
| `installer` | 5 |
| `live-readiness` | 4 |
| `live-validation` | 3 |
| `lockscreen-apply` | 12 |
| `lockscreen-audit` | 2 |
| `power-management-audit` | 4 |
| `test-runs` | 22 |
| `x280-archiso-test` | 1 |
| **Total** | **594** |

## Handling and privacy

These snapshots are historical evidence, not authoritative statements about current machine or project state. Prefer current owning documentation and explicitly curated acceptance evidence.

Diagnostic reports may contain device identifiers, package inventories, paths, journal excerpts, network or hardware metadata, and other environment details. Review and redact before sharing outside the project. Never add credentials, passwords, LUKS recovery material, tokens, cookies, or other secrets.

AI agents and maintainers must not enumerate or read the historical snapshot during routine work. Retrieve a specific file only when historical evidence is explicitly required or a current document links to it.
