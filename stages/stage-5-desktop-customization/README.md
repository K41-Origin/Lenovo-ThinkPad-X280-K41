# Stage 5 — Desktop Customization

Dokumen ini adalah peta fisik dan ownership implementasi Stage 5. Status workstream tetap dimiliki `docs/06-STATUS.md`; tujuan, prosedur, dan acceptance tiap workstream tetap dimiliki dokumen `docs/08-STAGE-5/`.

## Struktur kanonis

```text
stages/stage-5-desktop-customization/
├── README.md
└── workstreams/
    ├── 01-boot-experience/
    │   ├── config/
    │   │   └── quickshell/k41-boot-splash/shell.qml
    │   ├── scripts/
    │   │   ├── k41-configure-boot-experience.sh
    │   │   ├── k41-enable-caelestia-autologin.sh
    │   │   ├── k41-install-animated-boot-splash.sh
    │   │   ├── k41-install-hyprland-launcher.sh
    │   │   ├── k41-install-plymouth-theme.sh
    │   │   ├── k41-lock-caelestia-after-start.sh
    │   │   ├── k41-plymouth-quit-after-lock.sh
    │   │   └── k41-start-hyprland.sh
    │   └── stages/stage-5-desktop-customization/workstreams/01-boot-experience/themes/plymouth/k41/
    │       ├── k41.plymouth
    │       └── k41.script
    └── 02-lock-screen/
        ├── stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/
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

Test tetap berada di `tests/` karena runner dan CI bersifat lintas-stage. Dokumen prosedur workstream tetap di `docs/08-STAGE-5/`; file tersebut bukan runtime implementation.

## Workstream 1 — Boot Experience

Dokumen pemilik: [01 — Boot Experience](../../docs/08-STAGE-5/01-BOOT-EXPERIENCE.md).

| File | Tanggung jawab |
|---|---|
| `workstreams/01-boot-experience/stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-configure-boot-experience.sh` | Konfigurasi boot/Plymouth, UKI, dan TPM2 enrollment additive; privileged dan berisiko pada jalur boot |
| `.../k41-install-plymouth-theme.sh` | Memasang tema Plymouth dan membangun ulang initramfs/UKI |
| `.../k41-install-animated-boot-splash.sh` | Deploy Quickshell handoff splash dan mengubah konfigurasi Hyprland user |
| `.../k41-enable-caelestia-autologin.sh` | Opt-in tty1 autologin dan startup/lock handoff; mutatif, punya rollback |
| `.../k41-install-hyprland-launcher.sh` | Migrasi managed login block ke output-capturing launcher |
| `.../k41-start-hyprland.sh` | Menjalankan upstream `start-hyprland` sambil menyimpan log privat |
| `.../k41-lock-caelestia-after-start.sh` | Menunggu Caelestia lock IPC, meminta lock, memverifikasi, lalu menutup splash |
| `.../k41-plymouth-quit-after-lock.sh` | Menunggu marker lock; fail-closed menghentikan tty1 autologin bila lock tidak siap |
| `workstreams/01-boot-experience/stages/stage-5-desktop-customization/workstreams/01-boot-experience/themes/plymouth/k41/` | Source tema Plymouth K41 |
| `workstreams/01-boot-experience/stages/stage-5-desktop-customization/workstreams/01-boot-experience/config/quickshell/k41-boot-splash/shell.qml` | Source overlay handoff Quickshell |

Status Workstream 1: **COMPLETED / USER ACCEPTED**. Status ini adalah keputusan penerimaan pengguna, bukan klaim bahwa seluruh firmware/TPM/recovery state telah diukur ulang.

## Workstream 2 — Lock Screen

Dokumen pemilik: [02 — Lock Screen](../../docs/08-STAGE-5/02-LOCK-SCREEN.md).

| File | Tanggung jawab |
|---|---|
| `workstreams/02-lock-screen/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh` | Deploy pinned Caelestia source tree dan override QML; privileged entry dengan privilege drop, backup, dan rollback |
| `.../k41-lockscreen-audit.sh` | Audit read-only kondisi lock screen dan membuat report lokal |
| `.../k41-report-lockscreen-session.sh` | Mengumpulkan hasil restart Caelestia dari sesi Wayland |
| `.../k41-report-lockscreen-failure.sh` | Collector diagnostik kegagalan deployment; read-only selain report |
| `.../k41-report-lockscreen-permissions.sh` | Audit read-only metadata ownership/permission; membuat report |
| `workstreams/02-lock-screen/stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/` | Empat override QML untuk layout, surface, dan password card |

Status Workstream 2: **IN PROGRESS**. File tersedia di repository; implementasi terbaru belum dinyatakan TESTED/VERIFIED pada X280. Jangan menjalankan installer atau audit sebagai bagian dari reorganisasi file.

## Artefak bersama yang tetap di lokasi global

| Path | Alasan |
|---|---|
| `tests/test-boot-experience.sh` | Test kontrak Workstream 1, tetap di manifest global |
| `tests/test-plymouth-k41-theme.sh` | Test source theme dan integrasi |
| `tests/test-animated-boot-splash.sh` | Test source splash dan installer |
| `tests/test-autologin-desktop.sh` | Test autologin/lock fail-safe yang beririsan dengan session behavior |
| `tests/test-lockscreen-design.sh` | Test kontrak deployment dan QML Workstream 2 |
| `tests/run.sh` | Global test runner |
| `.github/workflows/ci.yml` | Global CI dan ShellCheck manifest |
| `docs/08-STAGE-5/` | Dokumen prosedur, scope, acceptance, dan Guest Mode |
| `docs/07-DESKTOP-DESIGN-SYSTEM.md`, `docs/07-DESIGN-SYSTEM/` | Spesifikasi visual lintas-workstream |

## Komponen yang tidak dipindahkan

- `scripts/k41-apply-caelestia-profile.sh`, `scripts/k41-audit-caelestia.sh`, dan `scripts/k41-desktop-costumization-check.sh` tidak memiliki ownership eksplisit pada Workstream 1 atau 2 berdasarkan dokumen aktif. Tetap di lokasi semula sampai pemetaan/fungsi pemilik dipastikan.
- `scripts/k41-diagnose-boot-visuals.sh` dan test-nya adalah tooling diagnostik; tidak dimasukkan ke runtime Workstream 1 tanpa bukti ownership yang lebih kuat.
- Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual tetap di [03 — Guest Mode](../../docs/08-STAGE-5/03-GUEST-MODE.md); tidak ada implementasi yang dipindahkan atau dibuat.
- Workstream 3–7 masih PLANNED; jangan membuat direktori runtime kosong atau mengklaim komponen telah diimplementasikan.

## Batas keselamatan

1. Reorganisasi hanya memindahkan source files dan memperbarui path/callers. Tidak menjalankan installer, TPM2 enrollment, rebuild UKI, Plymouth deployment, autologin, Caelestia deployment, lock/unlock, atau repair.
2. Script boot/TPM2 dan installer mutatif bukan test command. Review dokumen workstream dan kondisi aktual sebelum menjalankannya secara terpisah.
3. Jangan mengubah PAM, password, LUKS keyslot, atau kebijakan autentikasi sebagai bagian dari kosmetik.
4. Test global tetap di `tests/`; jangan memindahkan runner atau menggandakan test.
5. Perubahan path tidak mengubah status: Workstream 1 tetap diterima; Workstream 2 tetap belum diverifikasi pada X280.

## Validasi reorganisasi

Setelah pemindahan, lakukan:
- Bash syntax check pada script yang dipindahkan;
- ShellCheck untuk daftar Stage 5 di CI;
- test `test-boot-experience.sh`, `test-plymouth-k41-theme.sh`, `test-animated-boot-splash.sh`, `test-autologin-desktop.sh`, dan `test-lockscreen-design.sh`;
- global `bash tests/run.sh`;
- pemeriksaan seluruh referensi path dan tautan dokumentasi.

Test statis tidak membuktikan runtime visual, boot/recovery, TPM2 unlock, atau lock/unlock pada perangkat. Review visual dilakukan langsung pengguna pada X280; screenshot bukan acceptance gate.
