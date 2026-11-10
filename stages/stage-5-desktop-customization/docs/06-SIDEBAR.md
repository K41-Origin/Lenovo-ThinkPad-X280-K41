# Workstream 07 — Sidebar

## Tujuan

Menyediakan panel samping untuk navigasi atau quick access yang benar-benar dibutuhkan, dengan perilaku tampil/sembunyi yang jelas dan tidak menghalangi pekerjaan.

## Batas

Termasuk keberadaan/ketiadaan sidebar, konten, layout, ukuran, posisi, trigger, focus, keyboard/mouse interaction, dan integrasi upstream.

Tidak termasuk mengulang fungsi Bottombar, Topbar, launcher, atau utilities. Sidebar tidak wajib dibuat bila kebutuhan sudah dipenuhi komponen lain.

## Prosedur

1. Audit apakah sidebar sudah tersedia dalam Caelestia/Quickshell atau komponen aktif lain; verifikasi versi dan dokumentasi upstream.
2. Tentukan kebutuhan nyata sebelum membuat panel baru; keputusan yang valid dapat berupa tidak membuat Sidebar.
3. Tentukan interface, ownership source, runtime path di bawah `~/.config/quickshell/`, deployment, backup, dan rollback.
4. Implementasikan hanya fungsi yang disetujui, dengan API upstream terverifikasi.
5. Uji trigger, visibility, focus, keyboard/mouse, fullscreen, multi-window, dan shell restart.
6. Pastikan tidak ada duplikasi fungsi dan tidak ada error runtime kritis.

## Acceptance criteria

- Sidebar hanya dibuat bila memiliki fungsi yang tidak dipenuhi komponen lain.
- Konten dan interaksi sesuai keputusan pengguna.
- Tidak mengganggu fokus, fullscreen, atau area kerja.
- Source K41 terpisah dan dapat dipelihara sebagai kandidat komponen k41-dots.
- Pengguna menerima hasil langsung pada X280.

## Status

PLANNED.
