# Panduan Awal

## Alur kerja utama

1. **Arch Linux Live ISO — Readiness:** jalankan `bash scripts/k41-live-validation.sh`.
2. **Arch Linux Live ISO — Basic Arch:** setelah readiness PASS dan hasilnya direview, jalankan `bash scripts/k41-install-basic-arch.sh`. Tahap ini menghapus SSD target.
3. **Basic Arch Linux — Desktop setup:** setelah boot ke TTY Arch Linux, login sebagai user biasa lalu jalankan `sudo bash scripts/k41-install-desktop.sh`.
4. **Desktop Functional Validation:** jalankan `bash scripts/k41-desktop-validation.sh`, tinjau semua WARN/FAIL, dan simpan laporan. Tahap 4 telah diterima pada snapshot 2026-11-09; bukti ada di `reports/desktop-validation/20261109T081724Z/`.
5. **Desktop Customization:** tahap aktif berikutnya. Mulai setelah audit konfigurasi aktif dan baseline visual.
6. **Desktop & Hardware Optimization:** optimasi desktop, CPU/GPU, termal, daya, baterai, dan sleep/resume setelah customization diterima.
7. **Release:** hanya setelah seluruh acceptance gate dan regression checks lulus.

## Entry point dan implementasi

| Entry point kanonis | Implementasi yang dipakai saat ini |
|---|---|
| `k41-live-validation.sh` | Implementasi langsung |
| `k41-install-basic-arch.sh` | `install-arch-x280.sh` |
| `k41-install-desktop.sh` | `setup-desktop-x280.sh` |
| `k41-desktop-validation.sh` | Menjalankan collector desktop/Caelestia dan membuat satu laporan validasi terpadu |

Gunakan entry point kanonis. Nama lama dipertahankan agar perubahan antarmuka tidak memaksa pemindahan besar pada implementasi yang sudah ada.

## Sumber kebenaran

Kode branch `main` adalah implementasi. Test runner dan hasil test aktual adalah sumber hasil test. `reports/` menyimpan bukti untuk commit dan lingkungan yang tercatat. Dokumen aktif menjelaskan workflow saat ini; `docs/archive/` adalah histori, bukan instruksi operasional.

## Pemilik topik

| Topik | Dokumen |
|---|---|
| Tujuan, 7 tahap, arsitektur | [01 — Proyek](01-PROJECT.md) |
| Live readiness, instalasi dasar, boot | [02 — Instalasi](02-INSTALLATION.md) |
| Desktop install, validasi, customization | [03 — Desktop](03-DESKTOP.md) |
| Test suite dan acceptance/release gate | [04 — Testing](04-TESTING.md) |
| Security, recovery, optimasi hardware | [05 — Operations](05-OPERATIONS.md) |
| Status aktual dan prioritas | [06 — Status](06-STATUS.md) |
