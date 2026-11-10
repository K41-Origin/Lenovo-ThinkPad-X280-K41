# Workstream 04 — Bottombar (K41Dock)

**Status: COMPLETED / USER CONFIRMED SUCCESS.**

Implementasi yang menjadi hasil workstream ini adalah `K41Dock.qml`, yaitu dock horizontal minimal di tepi bawah untuk indikator workspace Hyprland. Nama lama Taskbar/Panel dipertahankan pada sebagian path repository demi kompatibilitas; nama komponen Stage 5 adalah **Bottombar**.

## Hasil implementasi

Source kanonis:
`workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`

Runtime pada laptop:
`~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`

Installer:
`scripts/k41-install-caelestia-dock.sh`

K41Dock:
- Menampilkan workspace pada monitor terkait.
- Menandai workspace aktif dan workspace yang memiliki window.
- Mengganti workspace ketika indikator diklik.
- Muncul melalui trigger hover di tepi bawah dan tetap tampil ketika dock di-hover.
- Tidak memakai exclusive zone.
- Disembunyikan ketika workspace aktif memiliki fullscreen toplevel.
- Dibangun sebagai modul QML milik K41 dengan namespace `modules/k41dock`, bukan dengan mengubah file package-owned.

## Batas dan ownership

Bottombar hanya menangani navigasi workspace. Clock, system tray, status sistem, launcher, dashboard, dan utilities bukan bagian dari komponen ini.

Repository adalah sumber kanonis untuk source, installer, dokumentasi, dan test. Salinan yang berjalan pada laptop berada di bawah `~/.config/quickshell/caelestia/`, yaitu source checkout Caelestia aktif. Integrasi saat ini menambahkan import dan instance K41Dock ke `shell.qml`, serta menonaktifkan entry bar upstream melalui `~/.config/caelestia/shell.json`.

Setiap komponen K41 berikutnya harus memiliki direktori source terpisah di `workstreams/<id>/config/quickshell/...` dan dideploy ke area runtime `~/.config/quickshell/` melalui installer yang memiliki preflight, backup, verifikasi pascaperubahan, dan rollback. Jangan menaruh kode K41 ke direktori internal upstream yang tidak dimiliki proyek tanpa alasan dan audit yang jelas.

## Acceptance dan batas klaim

Pengguna telah mengonfirmasi workstream K41Dock berhasil. Konfirmasi tersebut menutup workstream Bottombar pada scope implementasi yang diserahkan. Itu tidak otomatis membuktikan semua versi Quickshell, multi-monitor, seluruh edge-case fullscreen, atau konsumsi resource telah diuji secara terukur. Catat bukti tambahan hanya jika test tersebut benar-benar dijalankan.

## Pemeliharaan

- Perubahan Bottombar berikutnya harus mempertahankan interface dan perilaku yang sudah diterima, kecuali ada permintaan perubahan atau laporan regresi.
- Jangan menduplikasi workspace dock pada Topbar atau komponen lain.
- Simpan perubahan source di repository terlebih dahulu, lalu deploy ke laptop menggunakan installer.
- Backup dan rollback mengikuti [dokumen implementasi](04-TASKBAR-PANEL-IMPLEMENTATION.md).
