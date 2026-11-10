# Lenovo ThinkPad X280 — Arch Linux

Proyek ini membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280, dengan Hyprland, Quickshell, dan Caelestia Shell.

## Alur kerja kanonis

| Tahap | Lingkungan | Entry point |
|---|---|---|
| 1. Live readiness | Arch Linux Live ISO | `bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh` · [Peta Stage 1](stages/stage-1-live-readiness/README.md) |
| 2. Basic Arch installation | Arch Linux Live ISO | `bash stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh` · [Peta Stage 2](stages/stage-2-basic-arch-install/README.md) |
| 3. Desktop installation | Arch Linux terpasang, TTY | `sudo bash stages/stage-3-desktop-install/scripts/k41-install-desktop.sh` · [Peta Stage 3](stages/stage-3-desktop-install/README.md) |
| 4. Desktop functional validation | Sesi Hyprland | `bash stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` · [Peta Stage 4](stages/stage-4-desktop-validation/README.md) |
| 5. Desktop customization | Desktop hasil tahap 4 | [Dokumentasi Stage 5](stages/stage-5-desktop-customization/docs/README.md) · [Peta implementasi](stages/stage-5-desktop-customization/README.md) · [Design System](docs/07-DESKTOP-DESIGN-SYSTEM.md) |
| 6. Desktop & hardware optimization | Setelah customization diterima | [Operations](docs/05-OPERATIONS.md) |
| 7. Release | Setelah seluruh gate lulus | [Status](docs/06-STATUS.md) |

Gunakan entry point kanonis. Script implementasi lama yang dipanggil oleh wrapper bukan entry point tambahan.

## Mulai di sini

1. Baca [AGENTS.md](AGENTS.md) dan [Panduan Awal](docs/00-START-HERE.md).
2. Ikuti [alur instalasi](docs/02-INSTALLATION.md) dan [peta Stage 1](stages/stage-1-live-readiness/README.md).
3. Periksa [status aktual](docs/06-STATUS.md) sebelum mengubah kode atau konfigurasi.
4. Untuk Stage 5, ikuti [dokumentasi workstream](stages/stage-5-desktop-customization/docs/README.md) dan [Design System](docs/07-DESKTOP-DESIGN-SYSTEM.md).

## Status proyek

Status tahapan, prioritas aktif, acceptance, dan keterbatasan integrasi hanya dicatat di [docs/06-STATUS.md](docs/06-STATUS.md).

## Keselamatan

Tahap 1 tidak menulis ke SSD instalasi target, tetapi membuat laporan lokal dan test suite menggunakan disposable loop-backed image. Tahap 2 bersifat destruktif terhadap SSD target dan memerlukan identifikasi target, backup, review rencana, serta konfirmasi eksplisit. Jangan menebak device path, melewati signature verification, atau menjalankan remote script melalui pipe ke shell.

First-boot collector bersifat opsional. BlackArch bersifat opt-in dan selektif.

Struktur utama: `stages/`, `shared/`, `scripts/`, `tests/`, `reports/`, dan `docs/`. Root-level `lib/` dan `config/` adalah symlink kompatibilitas; gunakan `shared/lib/` dan `shared/config/` untuk referensi baru. Laporan runtime baru lokal secara default; kebijakan arsip ada di [reports/README.md](reports/README.md). Lisensi: [LICENSE](LICENSE).
