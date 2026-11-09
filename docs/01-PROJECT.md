# Proyek dan Arsitektur

## Tujuan

Membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280. Desktop menggunakan Hyprland, Quickshell, dan Caelestia Shell sesuai dependensi upstream. BlackArch bersifat opsional dan selektif.

## Tujuh tahap resmi

1. **Live readiness:** validasi ISO, mode boot, perangkat, jaringan, dependensi, repository, test suite, dan prasyarat storage. Read-only dalam arti tidak mengubah sistem atau SSD target; validator tetap menulis laporan lokal dan test suite memakai disposable loop-backed image. Detail alur dan batasnya ada di [Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md).
2. **Basic Arch installation:** instalasi dasar Arch pada SSD target setelah pemeriksaan identitas dan konfirmasi eksplisit. Destruktif.
3. **Desktop installation:** setup desktop dari Arch terpasang melalui TTY.
4. **Desktop functional validation:** pemeriksaan otomatis sesi, konfigurasi, proses, IPC, service, audio, jaringan, baterai, thermal, dan journal. Tidak menggantikan review interaksi pengguna.
5. **Desktop customization:** tujuh workstream berurutan: (1) boot experience, (2) lock screen, (3) dashboard, (4) taskbar/panel, (5) launcher, (6) sidebar, (7) utilities. Arah desain lintas-komponen ada di [Design System](07-DESKTOP-DESIGN-SYSTEM.md).
6. **Desktop & hardware optimization:** CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas dan pengukuran baseline.
7. **Release:** hanya setelah acceptance, regression, dokumentasi, dan bukti final ditinjau.

Tahap tidak berpindah otomatis. Entry point dan prosedur berada di [Instalasi](02-INSTALLATION.md), [Desktop](03-DESKTOP.md), [Testing](04-TESTING.md), dan [Operations](05-OPERATIONS.md).

## Status Stage 5

- **Workstream 1 — Boot Experience: COMPLETED / USER ACCEPTED (2026-11-10).** Keputusan penutupan diberikan secara eksplisit oleh pengguna. Catatan lama tentang visual boot adalah histori sebelum penutupan dan tidak menjadi pekerjaan aktif.
- **Workstream 2 — Lock Screen: IN PROGRESS.** Implementasi QML dan installer deployment tersedia; runtime terbaru, lock/unlock, wake, dan penerimaan visual pada X280 belum dinyatakan lulus. Detail ada di [Workstream 2](08-STAGE-5/02-LOCK-SCREEN.md).
- **Workstream 3–7: PLANNED**, mengikuti urutan Stage 5.
- **Guest Mode: NOT IMPLEMENTED / DEFERRED.** Fitur opsional terpisah; spesifikasi ada di [03 — Guest Mode](08-STAGE-5/03-GUEST-MODE.md).

Penerimaan Workstream 1 tidak boleh ditafsirkan sebagai klaim bahwa setiap detail teknis (misalnya TPM2 token atau Secure Boot) telah diukur ulang. Itu adalah status penyelesaian workstream berdasarkan penerimaan pengguna. Jangan membuka kembali workstream hanya berdasarkan catatan historis; evaluasi isu baru bila pengguna melaporkannya.

## Entry point kanonis

- `stages/stage-1-live-readiness/scripts/k41-live-validation.sh` — peta rinci: [Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md).
- `scripts/k41-install-basic-arch.sh` → delegasi internal `scripts/install-arch-x280.sh`
- `scripts/k41-install-desktop.sh` → delegasi internal `scripts/setup-desktop-x280.sh`
- `scripts/k41-desktop-validation.sh`
- `scripts/k41-desktop-repair.sh`

Wrapper harus tetap tipis dan tidak menggandakan implementasi.

## Keputusan arsitektur

- Tidak ada display manager atau autologin sebagai default instalasi.
- TTY login manual dipertahankan; autologin TTY1 adalah opsi terpisah dan opt-in.
- NetworkManager digunakan untuk jaringan.
- Hindari power manager yang saling bersaing; audit service aktif sebelum perubahan.
- AUR recipe harus direview dan package dibangun sebagai user non-root.
- Jangan menganggap exit code 0 atau file konfigurasi hadir sebagai bukti acceptance fungsional.

## Struktur repository

- `scripts/`: entry point dan workflow.
- `lib/`: modul bersama.
- `config/`: konfigurasi target.
- `tests/`: automated checks.
- `reports/`: output lokal dan arsip bukti historis.
- `docs/`: panduan umum proyek dan histori.
- `stages/`: dokumentasi dan script yang dimiliki masing-masing tahap.

## Terminologi status

PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED memiliki arti berbeda. Lihat [AGENTS.md](../AGENTS.md) untuk definisi kanonis.
