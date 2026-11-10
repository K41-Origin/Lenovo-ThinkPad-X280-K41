# Stage 5 — Desktop Customization

Peta fisik dan ownership implementasi Stage 5. Status proyek tetap dimiliki [docs/06-STATUS.md](../../docs/06-STATUS.md); prosedur dan acceptance tiap workstream tetap dimiliki dokumen di [Stage 5 workstream docs](docs/README.md).

## Struktur kanonis

```text
stages/stage-5-desktop-customization/
├── README.md
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

- Test: `tests/test-boot-experience.sh`, `tests/test-plymouth-k41-theme.sh`, `tests/test-animated-boot-splash.sh`, `tests/test-autologin-desktop.sh`, `tests/test-lockscreen-design.sh`.
- `tests/run.sh`, `.github/workflows/ci.yml`, dan `.github/workflows/bash-tests.yml`: runner dan CI lintas-stage. Kedua workflow memiliki cakupan yang tumpang tindih; lihat [Testing dan CI](../../docs/04-TESTING.md).
- `docs/08-STAGE-5/`: prosedur, scope, acceptance, Guest Mode.
- `docs/07-DESKTOP-DESIGN-SYSTEM.md` dan `docs/07-DESIGN-SYSTEM/`: spesifikasi visual lintas-komponen.

Test Stage 5 yang terpisah kini dicantumkan di global runner. Jangan memindahkan test ke direktori stage atau membuat runner duplikat.

## Tidak dipindahkan

- `scripts/k41-apply-caelestia-profile.sh`, `scripts/k41-audit-caelestia.sh`, dan `scripts/k41-desktop-costumization-check.sh`: ownership workstream belum ditetapkan secara eksplisit.
- `scripts/k41-diagnose-boot-visuals.sh` beserta test: tooling diagnostik; tidak dimasukkan ke runtime Workstream 1 tanpa bukti ownership yang lebih kuat.
- Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual tetap di [03 — Guest Mode](docs/03-GUEST-MODE.md).
- Workstream 3–7 masih PLANNED; tidak dibuat direktori runtime kosong.

## Safety dan validasi

Reorganisasi hanya memindahkan source dan memperbarui referensi. Tidak menjalankan installer, TPM2 enrollment, rebuild UKI, Plymouth deployment, autologin, Caelestia deployment, lock/unlock, atau repair. Jangan mengubah PAM, password, LUKS keyslot, atau kebijakan autentikasi sebagai bagian dari kosmetik.

Validasi yang diperlukan:
1. Bash syntax dan ShellCheck seluruh script yang dipindahkan.
2. Test Stage 5: `bash tests/test-boot-experience.sh`, `bash tests/test-plymouth-k41-theme.sh`, `bash tests/test-animated-boot-splash.sh`, `bash tests/test-autologin-desktop.sh`, `bash tests/test-lockscreen-design.sh`.
3. Global `bash tests/run.sh`.
4. Pemeriksaan semua referensi path dan tautan dokumentasi.

Test statis tidak membuktikan runtime visual, boot/recovery, TPM2 unlock, atau lock/unlock pada perangkat. Review visual dilakukan langsung pengguna pada X280; screenshot bukan acceptance gate.
