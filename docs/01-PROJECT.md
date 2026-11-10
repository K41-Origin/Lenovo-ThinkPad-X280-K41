# Proyek dan Arsitektur

## Tujuan

Membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280. Desktop menggunakan Hyprland, Quickshell, dan Caelestia Shell sesuai dependensi upstream. BlackArch bersifat opsional dan selektif.

## Tujuh tahap resmi

1. **Live readiness:** validasi ISO, mode boot, perangkat, jaringan, dependensi, repository, test suite, dan prasyarat storage. Read-only dalam arti tidak mengubah sistem atau SSD target; validator tetap menulis laporan lokal dan test suite memakai disposable loop-backed image. Detail alur dan batasnya ada di [Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md).
2. **Basic Arch installation:** instalasi dasar Arch pada SSD target setelah pemeriksaan identitas dan konfirmasi eksplisit. Destruktif. Peta implementasi dan batas operasional: [Stage 2 — Basic Arch Installation](../stages/stage-2-basic-arch-install/README.md).
3. **Desktop installation:** setup desktop dari Arch terpasang melalui TTY.
4. **Desktop functional validation:** pemeriksaan otomatis sesi, konfigurasi, proses, IPC, service, audio, jaringan, baterai, thermal, dan journal. Tidak menggantikan review interaksi pengguna.
5. **Desktop customization:** tujuh workstream berurutan: (1) boot experience, (2) lock screen, (3) dashboard, (4) taskbar/panel, (5) launcher, (6) sidebar, (7) utilities. Arah desain lintas-komponen ada di [Design System](07-DESKTOP-DESIGN-SYSTEM.md).
6. **Desktop & hardware optimization:** CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas dan pengukuran baseline.
7. **Release:** hanya setelah acceptance, regression, dokumentasi, dan bukti final ditinjau.

Tahap tidak berpindah otomatis. Entry point dan prosedur berada di [Instalasi](02-INSTALLATION.md), [Desktop](03-DESKTOP.md), [Testing](04-TESTING.md), dan [Operations](05-OPERATIONS.md).

## Status proyek

Status implementasi, prioritas aktif, acceptance, dan gate berikutnya hanya dicatat di [06 — Status](06-STATUS.md). Dokumen ini mempertahankan tujuan dan arsitektur, bukan salinan status workstream.

## Entry point kanonis

- `stages/stage-1-live-readiness/scripts/k41-live-validation.sh` — peta rinci: [Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md).
- `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh` → delegasi internal `install-arch-x280.sh`; peta rinci: [Stage 2 — Basic Arch Installation](../stages/stage-2-basic-arch-install/README.md)
- `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh` → delegasi internal `stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh`; peta rinci: [Stage 3 — Desktop Installation](../stages/stage-3-desktop-install/README.md)
- `stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` and `stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh` — peta rinci, side effects, bukti, dan test: [Stage 4 — Desktop Functional Validation](../stages/stage-4-desktop-validation/README.md)

Wrapper harus tetap tipis dan tidak menggandakan implementasi.

## Keputusan arsitektur

- Tidak ada display manager atau autologin sebagai default instalasi.
- TTY login manual dipertahankan; autologin TTY1 adalah opsi terpisah dan opt-in.
- NetworkManager digunakan untuk jaringan.
- Hindari power manager yang saling bersaing; audit service aktif sebelum perubahan.
- AUR recipe harus direview dan package dibangun sebagai user non-root.
- Jangan menganggap exit code 0 atau file konfigurasi hadir sebagai bukti acceptance fungsional.

## Ide pengembangan di luar roadmap aktif

**Custom Arch ISO — IDE / NOT SCHEDULED.** Tahap 1 dan 2 dapat menjadi dasar evaluasi untuk ISO Arch kustom yang menyertakan tooling proyek. Ini belum menjadi bagian dari tujuh tahap aktif, belum memiliki desain teknis, acceptance criteria, atau jadwal. Jangan mulai implementasi sebelum kebutuhan, metode build ISO, pemeliharaan paket, keamanan supply chain, dan strategi update ditetapkan secara terpisah.

## Struktur repository

- `scripts/`: workflow dan utilitas lintas tahap.
- `lib/`: modul bersama.
- `config/`: konfigurasi target.
- `tests/`: automated checks.
- `reports/`: output lokal dan arsip bukti historis.
- `docs/`: panduan umum proyek dan histori.
- `stages/`: dokumentasi dan script yang dimiliki masing-masing tahap.

## Terminologi status

PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED memiliki arti berbeda. Lihat [AGENTS.md](../AGENTS.md) untuk definisi kanonis.
