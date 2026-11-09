# Panduan Awal

## Urutan kerja proyek

1. **Live readiness:** dari Arch Linux Live ISO jalankan `bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. Lihat [peta Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md).
2. **Basic Arch installation:** setelah readiness PASS dan rencana/target direview, jalankan `bash scripts/k41-install-basic-arch.sh`. Operasi ini destruktif. Lihat [peta Stage 2 — Basic Arch Installation](../stages/stage-2-basic-arch-install/README.md).
3. **Desktop installation:** setelah boot ke Arch terpasang dan login TTY sebagai user biasa, jalankan `sudo bash scripts/k41-install-desktop.sh`. Lihat [peta Stage 3 — Desktop Installation](../stages/stage-3-desktop-install/README.md).
4. **Desktop validation:** dari sesi Hyprland sebagai user biasa jalankan `bash scripts/k41-desktop-validation.sh`. Stage 4 telah diterima; bukti ringkas dan batasnya tercatat di [Status](06-STATUS.md).
5. **Desktop customization:** Stage 5 aktif. Workstream 1 — Boot Experience **COMPLETED / USER ACCEPTED**. Workstream 2 — Lock Screen sedang dikerjakan. Ikuti [indeks Stage 5](08-STAGE-5/README.md).
6. **Desktop & hardware optimization:** PLANNED setelah customization diterima; lihat [Operations](05-OPERATIONS.md).
7. **Release:** PLANNED setelah seluruh gate dan regression lulus.

Tidak ada perpindahan otomatis antar tahap.

## Entry point kanonis

| Entry point | Fungsi |
|---|---|
| `stages/stage-1-live-readiness/scripts/k41-live-validation.sh` | Readiness Arch ISO |
| `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh` | Entry point instalasi dasar Arch |
| `scripts/k41-install-desktop.sh` | Instalasi desktop; delegasi ke `setup-desktop-x280.sh` |
| `scripts/k41-desktop-validation.sh` | Validasi fungsional desktop |
| `scripts/k41-desktop-repair.sh` | Repair terbatas berbasis hasil validasi |

Gunakan wrapper kanonis, bukan wrapper dan implementasi internal sekaligus.

## Sumber kebenaran

- Implementasi: branch `main`.
- Status proyek: [06 — Status](06-STATUS.md).
- Prosedur dan batas tahap: dokumen pemilik yang tercantum di bawah.
- Test aktual: `tests/run.sh` dan hasil eksekusi yang benar-benar tersedia.
- Bukti historis: snapshot commit `02f6194ed04c8f13ea64eda35b7afb94f7006504`; lihat [indeks arsip](../reports/archive/2026-11/README.md).
- `docs/archive/` hanya histori; bukan instruksi operasional aktif.

Laporan runtime baru disimpan lokal di `reports/<category>/<timestamp>/` dan tidak dikomit otomatis.

## Dokumen pemilik

| Topik | Dokumen |
|---|---|
| Tujuan, tahapan, arsitektur | [01 — Proyek](01-PROJECT.md) |
| Tahap 1–3: prosedur instalasi | [02 — Instalasi](02-INSTALLATION.md) |
| Stage 1: peta entry point, call graph, modul, laporan, dan test | [Stage 1 — Live Readiness](../stages/stage-1-live-readiness/README.md) |
| Stage 2: peta installer, storage plan, layout, recovery, dan test | [Stage 2 — Basic Arch Installation](../stages/stage-2-basic-arch-install/README.md) |\n| Stage 3: peta desktop installer, AUR resolver, side effects, dan test | [Stage 3 — Desktop Installation](../stages/stage-3-desktop-install/README.md) |
| Desktop tahap 3–5 | [03 — Desktop](03-DESKTOP.md) |
| Automated tests dan acceptance | [04 — Testing](04-TESTING.md) |
| Security, recovery, tahap 6 | [05 — Operations](05-OPERATIONS.md) |
| Status dan prioritas terkini | [06 — Status](06-STATUS.md) |
| Design System | [07 — Design System](07-DESKTOP-DESIGN-SYSTEM.md) |
| Stage 5 workstreams | [08 — Stage 5](08-STAGE-5/README.md) |

Untuk perubahan, baca status dan dokumen pemilik terlebih dahulu. Jangan memulai refactoring atau konsolidasi besar sebelum audit implementasi dan dependensinya selesai.
