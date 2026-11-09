# Lenovo ThinkPad X280 — Arch Linux

Proyek ini membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280, dengan Hyprland, Quickshell, dan Caelestia Shell.

## Alur kerja kanonis

| Tahap | Lingkungan | Entry point |
|---|---|---|
| 1. Live readiness | Arch Linux Live ISO | `bash scripts/k41-live-validation.sh` · [Peta Stage 1](stages/stage-1-live-readiness/README.md) |
| 2. Basic Arch installation | Arch Linux Live ISO | `bash scripts/k41-install-basic-arch.sh` |
| 3. Desktop installation | Arch Linux terpasang, TTY | `sudo bash scripts/k41-install-desktop.sh` |
| 4. Desktop functional validation | Sesi Hyprland | `bash scripts/k41-desktop-validation.sh` |
| 5. Desktop customization | Desktop hasil tahap 4 | [Workstream](docs/08-STAGE-5/README.md) · [Design System](docs/07-DESKTOP-DESIGN-SYSTEM.md) |
| 6. Desktop & hardware optimization | Setelah customization diterima | [Operations](docs/05-OPERATIONS.md) |
| 7. Release | Setelah seluruh gate lulus | [Status](docs/06-STATUS.md) |

Gunakan entry point kanonis. Script implementasi lama yang dipanggil oleh wrapper bukan entry point tambahan; jangan menjalankan keduanya untuk tugas yang sama.

## Mulai di sini

1. Baca [AGENTS.md](AGENTS.md) dan [Panduan Awal](docs/00-START-HERE.md).
2. Ikuti [alur instalasi](docs/02-INSTALLATION.md) dan [peta Stage 1](stages/stage-1-live-readiness/README.md).
3. Periksa [status aktual](docs/06-STATUS.md) sebelum mengubah kode atau konfigurasi.
4. Untuk Stage 5, ikuti urutan [workstream](docs/08-STAGE-5/README.md) dan gunakan [Design System](docs/07-DESKTOP-DESIGN-SYSTEM.md).

## Status proyek

- Stage 1–4: implementasi tersedia; Stage 4 telah diterima berdasarkan hasil validasi dan konfirmasi pengguna.
- Stage 5: aktif. Workstream 1 — Boot Experience **COMPLETED / USER ACCEPTED**. Workstream 2 — Lock Screen adalah pekerjaan aktif.
- Guest Mode: **NOT IMPLEMENTED** dan ditunda sebagai fitur opsional. Lihat [spesifikasi Guest Mode](docs/08-STAGE-5/03-GUEST-MODE.md).
- Stage 6–7: PLANNED.

Penerimaan Workstream 1 adalah keputusan pengguna pada 2026-11-10. Catatan lebih lama tentang isu visual boot merupakan histori sebelum keputusan penutupan, bukan backlog aktif.

## Kebijakan bukti visual

Tidak menggunakan screenshot sebagai persyaratan, gate, ataupun artefak penerimaan. Review visual dilakukan langsung oleh pengguna pada ThinkPad X280. Dokumentasi cukup mencatat hasil/keputusan pengguna, kondisi pengujian, dan isu yang benar-benar dilaporkan.

## Keselamatan

Tahap 1 tidak mengubah konfigurasi sistem atau menulis ke SSD instalasi target, tetapi membuat laporan lokal dan test suite menggunakan disposable loop-backed image. Tahap 2 bersifat destruktif terhadap SSD target dan memerlukan identifikasi target, backup, review rencana, serta konfirmasi eksplisit. Jangan menebak device path, melewati signature verification, atau menjalankan remote script melalui pipe ke shell.

First-boot collector bersifat opsional, bukan gerbang wajib sebelum tahap 3. BlackArch bersifat opt-in dan selektif.

Struktur utama: `scripts/`, `lib/`, `config/`, `tests/`, `reports/`, dan `docs/`. Laporan runtime baru lokal secara default; kebijakan arsip ada di [reports/README.md](reports/README.md). Lisensi: [LICENSE](LICENSE).
