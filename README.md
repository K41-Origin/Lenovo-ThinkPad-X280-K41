# Lenovo ThinkPad X280 — Arch Linux

Proyek instalasi Arch Linux yang modular, aman, dan dapat diuji untuk ThinkPad X280 dengan Hyprland, Caelestia Shell, dan Quickshell.

Mulai dengan [AGENTS.md](AGENTS.md), [Panduan Awal](docs/00-START-HERE.md), lalu [Status](docs/06-STATUS.md).

## Dokumentasi aktif
- [01 Proyek](docs/01-PROJECT.md)
- [02 Instalasi](docs/02-INSTALLATION.md)
- [03 Desktop](docs/03-DESKTOP.md)
- [04 Pengujian](docs/04-TESTING.md)
- [05 Operasional](docs/05-OPERATIONS.md)
- [06 Status](docs/06-STATUS.md)

Dokumen lama dipindahkan tanpa dihapus ke [docs/archive/legacy](docs/archive/legacy/). Arsip adalah histori, bukan prosedur aktif.

## Urutan tahap
1. Validasi fungsional desktop.
2. Kustomisasi desktop minimal, premium, monochromatic.
3. Integrasi software opsional terpilih.
4. Kustomisasi hardware dan sistem (tahap terakhir).

Installer OS dapat menghapus SSD target. Wajib review source, readiness, identifikasi target, recovery, dan otorisasi eksplisit. `./installer --preflight` hanya diagnostik. Jangan menonaktifkan signature verification atau menjalankan remote script melalui pipe ke shell.

Struktur: `installer`, `scripts/`, `lib/`, `config/`, `tests/`, `reports/`, `docs/`. Lisensi: [LICENSE](LICENSE).
