# Stage 5 — Desktop Customization

Peta fisik dan ownership implementasi Stage 5. Status proyek tetap dimiliki [docs/06-STATUS.md](../../docs/06-STATUS.md); prosedur dan acceptance tiap workstream tetap dimiliki dokumen di [Stage 5 workstream docs](docs/README.md).

## Struktur kanonis

```text
stages/stage-5-desktop-customization/
├── README.md
├── docs/       # Prosedur dan acceptance workstream
├── scripts/    # Stage 5 support and appearance tools
├── tests/      # Test kontrak milik Stage 5
└── workstreams/
    ├── 01-boot-experience/
    │   ├── config/quickshell/k41-boot-splash/shell.qml
    │   ├── scripts/
    │   │   ├── k41-configure-boot-experience.sh
    │   │   ├── k41-enable-caelestia-autologin.sh
    │   │   ├── k41-install-animated-boot-splash.sh
    │   │   ├── k41-install-hyprland-launcher.sh
    │   │   ├── k41-install-plymouth-theme.sh
    │   │   ├── k41-lock-caelestia-after-start.sh
    │   │   ├── k41-plymouth-quit-after-lock.sh
    │   │   └── k41-start-hyprland.sh
    │   └── themes/plymouth/k41/
    │       ├── k41.plymouth
    │       └── k41.script
    └── 02-lock-screen/
        ├── config/quickshell/caelestia/modules/lock/
        │   ├── Center.qml
        │   ├── Content.qml
        │   ├── LockSurface.qml
        │   └── center/PasswordInput.qml
        └── scripts/
            ├── k41-apply-lockscreen-design.sh
            ├── k41-lockscreen-audit.sh
            ├── k41-report-lockscreen-failure.sh
            ├── k41-report-lockscreen-permissions.sh
            └── k41-report-lockscreen-session.sh
```

Stage 5 support scripts (appearance profile, Caelestia audit, baseline/inventory, desktop integration, boot visual diagnostics, and Guest Mode storage audit) are canonical under `scripts/` within this stage. Root `scripts/` names remain compatibility symlinks for existing command paths. Their reports are written under `reports/stage-5-desktop-customization/`.

## Workstream 1 — Boot Experience

Dokumen prosedur: [01 — Boot Experience](docs/01-BOOT-EXPERIENCE.md).

| Ownership | File / fungsi |
|---|---|
| Boot/TPM2/UKI | `workstreams/01-boot-experience/scripts/k41-configure-boot-experience.sh` — privileged; mengubah boot configuration, TPM2 enrollment additive, dan membangun ulang UKI |
| Plymouth | `.../scripts/k41-install-plymouth-theme.sh` dan `.../themes/plymouth/k41/` — deploy tema dan rebuild initramfs/UKI |
| Quickshell splash | `.../scripts/k41-install-animated-boot-splash.sh` dan `.../config/quickshell/k41-boot-splash/shell.qml` — deploy splash dan mengubah konfigurasi Hyprland user |
| Autologin opt-in | `.../scripts/k41-enable-caelestia-autologin.sh` — mutatif, mengubah tty1/login flow; tersedia rollback |
| Launcher | `.../scripts/k41-install-hyprland-launcher.sh` dan `.../scripts/k41-start-hyprland.sh` — memasang wrapper output-capturing untuk upstream `start-hyprland` |
| Lock handoff | `.../scripts/k41-lock-caelestia-after-start.sh` dan `.../scripts/k41-plymouth-quit-after-lock.sh` — meminta/verifikasi lock dan fail-closed release Plymouth |

Riwayat acceptance dan batas klaim Workstream 1 dimiliki [dokumen Workstream 1](docs/01-BOOT-EXPERIENCE.md). Status proyek terkini tetap dicatat di [docs/06-STATUS.md](../../docs/06-STATUS.md).

## Workstream 2 — Lock Screen

Dokumen prosedur: [02 — Lock Screen](docs/02-LOCK-SCREEN.md).

| Ownership | File / fungsi |
|---|---|
| Deployment | `workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh` — pinned Caelestia source deployment, privilege drop, backup, rollback |
| Audit | `.../scripts/k41-lockscreen-audit.sh` — read-only inventory; menulis report lokal |
| Session report | `.../scripts/k41-report-lockscreen-session.sh` — mengumpulkan restart log dari sesi Wayland |
| Failure report | `.../scripts/k41-report-lockscreen-failure.sh` — collector diagnostik read-only selain output report |
| Permission report | `.../scripts/k41-report-lockscreen-permissions.sh` — audit metadata ownership/permission |
| QML overrides | `workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/` — `Content.qml`, `Center.qml`, `LockSurface.qml`, dan `center/PasswordInput.qml` |

Source implementasi tersedia di repository. Status pengujian dan verifikasi terbaru pada X280 hanya dicatat di [docs/06-STATUS.md](../../docs/06-STATUS.md).

## Artefak global yang sengaja tidak dipindahkan

- Stage-owned tests: `stages/stage-5-desktop-customization/tests/` (boot experience, Plymouth, animated splash, autologin, lock-screen, Guest Mode audit, and boot visual diagnostics).
- `tests/run.sh`, `.github/workflows/bash-tests.yml`: runner dan CI lintas-stage. Workflow CI tunggal menjalankan syntax, ShellCheck, shfmt terpilih, dan test suite; lihat [Testing dan CI](../../docs/04-TESTING.md).
- `stages/stage-5-desktop-customization/docs/`: prosedur, scope, acceptance, Guest Mode.
- `docs/07-DESKTOP-DESIGN-SYSTEM.md` dan `docs/07-DESIGN-SYSTEM/`: spesifikasi visual lintas-komponen.

Manifest global `tests/run.sh` memanggil test Stage 5 dari direktori stage. Jangan membuat runner duplikat.

## Tidak dipindahkan

- Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual tetap di [03 — Guest Mode](docs/03-GUEST-MODE.md).
- Workstream 3 — Dashboard: PLANNED dan ditunda sementara sampai Taskbar selesai.
- Workstream 4 — Taskbar/Panel: implementasi awal tersedia; deployment dan validasi perangkat masih berlangsung.
- Workstream 5–7 — Launcher, Sidebar, Utilities: PLANNED; tidak dibuat direktori runtime kosong.

## Safety dan validasi

Reorganisasi memindahkan source, tests, dan laporan runtime ke ownership Stage; root script paths dipertahankan sebagai symlink kompatibilitas. Tidak menjalankan installer, TPM2 enrollment, rebuild UKI, Plymouth deployment, autologin, Caelestia deployment, lock/unlock, atau repair. Jangan mengubah PAM, password, LUKS keyslot, atau kebijakan autentikasi sebagai bagian dari kosmetik.

Validasi yang diperlukan:
1. Bash syntax dan ShellCheck seluruh script yang dipindahkan.
2. Test Stage 5: `bash stages/stage-5-desktop-customization/tests/test-boot-experience.sh`, `bash stages/stage-5-desktop-customization/tests/test-plymouth-k41-theme.sh`, `bash stages/stage-5-desktop-customization/tests/test-animated-boot-splash.sh`, `bash stages/stage-5-desktop-customization/tests/test-autologin-desktop.sh`, `bash stages/stage-5-desktop-customization/tests/test-lockscreen-design.sh`, `bash stages/stage-5-desktop-customization/tests/test-guest-storage-audit.sh`, dan `bash stages/stage-5-desktop-customization/tests/test-boot-visual-diagnostics.sh`.
3. Global `bash tests/run.sh`.
4. Pemeriksaan semua referensi path dan tautan dokumentasi.

Test statis tidak membuktikan runtime visual, boot/recovery, TPM2 unlock, atau lock/unlock pada perangkat. Review visual dilakukan langsung pengguna pada X280; screenshot bukan acceptance gate.

## Tests and reports

Stage 5 contract tests live in `stages/stage-5-desktop-customization/tests/` and are invoked through `bash tests/run.sh`. Lock-screen deployment reports use `reports/stage-5-desktop-customization/02-lock-screen/lockscreen-apply/`.
