# Lenovo ThinkPad X280 — Arch Linux

Proyek membangun instalasi Arch Linux yang modular, aman, reproducible, dan dapat diuji untuk ThinkPad X280, dengan Hyprland, Quickshell, dan Caelestia Shell.

## Alur kerja kanonis

| Tahap | Lingkungan | Entry point |
|---|---|---|
| 1. Live Readiness | Arch Linux Live ISO | `bash scripts/k41-live-validation.sh` |
| 2. Basic Arch Installation | Arch Linux Live ISO | `bash scripts/k41-install-basic-arch.sh` |
| 3. Desktop Installation | Basic Arch Linux, TTY | `sudo bash scripts/k41-install-desktop.sh` |
| 4. Desktop Functional Validation | Sesi Hyprland | `bash scripts/k41-desktop-validation.sh` |
| 5. Desktop Customization | Desktop yang telah diterima | [Panduan desktop](docs/03-DESKTOP.md) |
| 6. Desktop & Hardware Optimization | Desktop yang telah dikustomisasi | [Operasional](docs/05-OPERATIONS.md) |
| 7. Release | Setelah seluruh gate lulus | [Status](docs/06-STATUS.md) |

Ketiga nama script di atas adalah entry point kanonis. Script lama dipertahankan sebagai implementasi internal/backward compatibility; jangan menjalankan keduanya secara berurutan untuk tugas yang sama.

## Mulai di sini

1. Baca [AGENTS.md](AGENTS.md) dan [Panduan Awal](docs/00-START-HERE.md).
2. Ikuti [alur instalasi](docs/02-INSTALLATION.md).
3. Periksa [status dan gate aktif](docs/06-STATUS.md).

## Keselamatan

Tahap 1 bersifat read-only dan memvalidasi kesiapan lingkungan serta target. Tahap 2 **destruktif**: installer menghapus SSD internal target setelah identitas, rencana, dan konfirmasi eksplisit diverifikasi. Backup wajib tersedia. Jangan menebak device path, melewati signature verification, atau menjalankan remote script melalui pipe ke shell.

`./installer --preflight` tetap hanya diagnostik. First-boot collector tersedia sebagai alat diagnosis opsional, bukan gerbang wajib sebelum tahap 3.

Struktur utama: `scripts/`, `lib/`, `config/`, `tests/`, `reports/`, `docs/`. Lisensi: [LICENSE](LICENSE).
