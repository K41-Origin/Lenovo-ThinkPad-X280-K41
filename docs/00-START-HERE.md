# Panduan Awal

## Urutan membaca
1. [AGENTS.md](../AGENTS.md) — aturan keselamatan dan workflow.
2. [01 Proyek](01-PROJECT.md) — tujuan dan keputusan.
3. Pilih topik: [Instalasi](02-INSTALLATION.md), [Desktop](03-DESKTOP.md), [Pengujian](04-TESTING.md), [Operasional](05-OPERATIONS.md).
4. Periksa [Status](06-STATUS.md) sebelum bekerja.

## Sumber kebenaran
Kode branch aktif adalah implementasi; test runner/test aktual adalah sumber hasil test; `reports/` adalah bukti untuk commit dan lingkungan yang tercatat. Dokumen aktif menjelaskan prosedur. `docs/archive/` adalah histori, bukan instruksi terkini.

## Aturan AI
Inspeksi sebelum mengubah; pertahankan pekerjaan tak terkait; satu topik satu dokumen pemilik; baca kode dan test untuk perubahan implementasi; gunakan upstream resmi untuk klaim versi; jangan melakukan operasi disk destruktif atau perubahan sistem fisik tanpa otorisasi; laporkan hanya test yang benar-benar dijalankan.

## Pemilik topik
| Topik | Dokumen |
|---|---|
| Tujuan, keputusan, tahap, arsitektur | [01](01-PROJECT.md) |
| Bootstrap, installer, disk, boot | [02](02-INSTALLATION.md) |
| Hyprland, Caelestia, desktop acceptance | [03](03-DESKTOP.md) |
| Test suite dan acceptance | [04](04-TESTING.md) |
| Security, recovery, software, hardware | [05](05-OPERATIONS.md) |
| Status dan prioritas | [06](06-STATUS.md) |
