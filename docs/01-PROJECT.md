# Proyek dan Arsitektur

## Tujuan

Membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280. Desktop menggunakan Hyprland, Quickshell, dan Caelestia Shell sesuai dependensi upstream. BlackArch bersifat opsional dan selektif.

## Tujuh tahap resmi

1. **Live readiness:** validasi ISO, mode boot, perangkat, jaringan, dependensi, repository, test suite, dan prasyarat storage. Read-only terhadap sistem dan SSD target; validator tetap menulis laporan lokal dan test suite memakai disposable loop-backed image. Detail: [Stage 1](../stages/stage-1-live-readiness/README.md).
2. **Basic Arch installation:** instalasi dasar Arch pada SSD target setelah pemeriksaan identitas dan konfirmasi eksplisit. Destruktif. Detail: [Stage 2](../stages/stage-2-basic-arch-install/README.md).
3. **Desktop installation:** setup desktop dari Arch terpasang melalui TTY. Detail: [Stage 3](../stages/stage-3-desktop-install/README.md).
4. **Desktop functional validation:** pemeriksaan otomatis sesi, konfigurasi, proses, IPC, service, audio, jaringan, baterai, thermal, dan journal. Tidak menggantikan review interaksi pengguna. Detail: [Stage 4](../stages/stage-4-desktop-validation/README.md).
5. **Desktop customization:** tujuh workstream berurutan. Detail dan acceptance dimiliki [Stage 5 docs](../stages/stage-5-desktop-customization/docs/README.md). Arah desain lintas-komponen ada di [Design System](07-DESKTOP-DESIGN-SYSTEM.md).
6. **Desktop & hardware optimization:** CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas dan pengukuran baseline.
7. **Release:** hanya setelah acceptance, regression, dokumentasi, dan bukti final ditinjau.

Tahap tidak berpindah otomatis. Entry point dan prosedur umum berada di [Instalasi](02-INSTALLATION.md), [Desktop](03-DESKTOP.md), [Testing](04-TESTING.md), dan [Operations](05-OPERATIONS.md).

## Status proyek

Status implementasi, prioritas aktif, acceptance, dan gate berikutnya hanya dicatat di [06 — Status](06-STATUS.md).

## Keputusan arsitektur

- Tidak ada display manager atau autologin sebagai default instalasi.
- TTY login manual dipertahankan; autologin TTY1 adalah opsi terpisah dan opt-in.
- NetworkManager digunakan untuk jaringan.
- Hindari power manager yang saling bersaing; audit service aktif sebelum perubahan.
- AUR recipe harus direview dan package dibangun sebagai user non-root.
- Jangan menganggap exit code 0 atau file konfigurasi hadir sebagai bukti acceptance fungsional.

## Ide pengembangan di luar roadmap aktif

**Custom Arch ISO — IDE / NOT SCHEDULED.** Belum menjadi bagian dari tujuh tahap aktif, belum memiliki desain teknis, acceptance criteria, atau jadwal.

## Struktur repository

- `stages/<stage>/`: implementasi, dokumentasi, konfigurasi, library, test, dan report yang dimiliki Stage terkait.
- `shared/`: komponen yang digunakan lintas Stage; implementasi kanonis berada di `shared/lib/` dan `shared/config/`.
- `scripts/`: utilitas lintas tahap yang belum memiliki ownership Stage tunggal; pemetaan ada di dokumen owner.
- `tests/`: test integrasi lintas Stage, fixture, dan satu runner global.
- `reports/`: output runtime lokal dan arsip bukti historis.
- `docs/`: panduan proyek lintas tahap dan arsip historis.

Root-level `lib/` dan `config/` dipertahankan sementara sebagai symlink kompatibilitas menuju `shared/`; kode baru harus memakai path kanonis `shared/`.

## Terminologi status

PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED memiliki arti berbeda. Lihat [AGENTS.md](../AGENTS.md).
