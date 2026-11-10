# Workstream 3 — Dashboard (Retired)

## Keputusan

**CANCELLED / REMOVED FROM SCOPE — 2026-11-11.**

Pengguna memutuskan bahwa dashboard tidak lagi diperlukan. Workstream ini dihentikan sebelum implementasi desain dashboard baru. Jangan melanjutkan layout, widget, keybind, atau acceptance dashboard.

## Rencana cleanup

Pembersihan konfigurasi Caelestia akan ditangani oleh script:

`stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

Script tersebut **PLANNED** dan belum tersedia. Implementasinya harus didahului audit aktual, membuat backup yang dapat dipulihkan, membatasi perubahan pada konfigurasi/override K41 yang teridentifikasi, serta menyediakan mode pemeriksaan tanpa perubahan. Jangan menghapus source checkout upstream Caelestia atau file yang kepemilikannya belum dipastikan hanya untuk meniadakan dashboard.

## Status

Tidak ada dashboard baru yang akan dibuat. Dokumen ini dipertahankan sebagai catatan keputusan agar scope lama tidak diaktifkan kembali secara tidak sengaja.