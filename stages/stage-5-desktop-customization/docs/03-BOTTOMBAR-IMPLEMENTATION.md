# Bottombar — Implementation

## Tujuan

Workstream 03 menghasilkan komponen Bottombar bernama `K41Dock.qml`. Komponen ini menjadi pola awal pengembangan komponen K41 yang terpisah dari fitur upstream Caelestia dan dapat dikembangkan bertahap menuju proyek mandiri **k41-dots**.

## Source dan lokasi runtime

| Jenis | Path |
|---|---|
| Source kanonis di repository | `stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml` |
| Source aktif pada laptop | `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml` |
| Entry point Caelestia aktif | `~/.config/quickshell/caelestia/shell.qml` |
| Runtime config Caelestia | `~/.config/caelestia/shell.json` |
| Backup dan log installer | `~/.local/state/k41/backups/caelestia-dock/<timestamp>/` |

Repository menyimpan source yang dapat direview dan direproduksi. Laptop menjalankan salinan runtime di bawah `~/.config/quickshell/`. Jangan menjadikan salinan runtime sebagai satu-satunya tempat penyimpanan source; setelah perubahan diuji, sinkronkan kembali hasil yang disetujui ke repository.

## Perilaku K41Dock

- Menampilkan workspace pada monitor yang sesuai.
- Workspace aktif memiliki indikator lebih menonjol; workspace yang memiliki window diberi penanda berbeda.
- Klik indikator memanggil `Hypr.focusWorkspace()`.
- Trigger hover selebar layar berada di tepi bawah.
- Dock tetap terlihat ketika pointer berada di dock dan disembunyikan setelah pointer meninggalkannya.
- `exclusiveZone: 0`; dock tidak memesan ruang layout workspace.
- Dock disembunyikan ketika monitor memiliki fullscreen toplevel aktif.
- Menggunakan `PanelWindow`, `WlrLayershell`, dan API Hyprland melalui Quickshell.

## Integrasi saat ini

Installer `scripts/k41-install-caelestia-dock.sh`:
1. Memastikan dijalankan sebagai user biasa.
2. Memeriksa source checkout Caelestia dan runtime config.
3. Memvalidasi struktur `shell.qml`, `shell.json`, dan QML sebelum perubahan.
4. Membuat backup `shell.qml`, target `K41Dock.qml` (atau mencatat bahwa target belum ada), dan `shell.json`.
5. Menyalin modul ke `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`.
6. Menambahkan import dan instance K41Dock ke `shell.qml`.
7. Menonaktifkan entry bar upstream pada `shell.json` sambil mempertahankan pengaturan lain.
8. Memeriksa hasil perubahan.

Installer tidak menggunakan sudo, tidak memasang paket, tidak me-restart service, dan tidak me-reload Quickshell secara otomatis.

## Install, check, dan rollback

Dari root repository:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --check
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --install
```

Untuk rollback, gunakan direktori backup persis yang dicetak installer:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --rollback "$HOME/.local/state/k41/backups/caelestia-dock/<timestamp>"
```

Path source dapat dioverride melalui `K41_CAELESTIA_SOURCE=/path/to/caelestia`.

## Pola pengembangan menuju k41-dots

Scope k41-dots dibatasi pada fondasi komponen desktop yang dibutuhkan. Workstream 01 — Boot Experience berada di luar scope karena boot/splash menggunakan Plymouth.

K41Dock menjadi referensi proses, bukan alasan untuk menyalin seluruh source Caelestia. Untuk setiap komponen Stage 5 berikutnya:

1. Audit API, source aktif, config, versi, dan dependensi upstream.
2. Tentukan ownership dan interface komponen.
3. Simpan source K41 di direktori workstream repository yang terpisah.
4. Deploy salinan runtime ke `~/.config/quickshell/` menggunakan installer yang aman dan dapat di-rollback.
5. Uji komponen secara terisolasi dan integrasinya dengan shell aktif.
6. Catat hasil, batasan, dan keputusan penerimaan.
7. Pertahankan pemisahan antara kode K41 dan kode upstream agar komponen dapat diekstrak ke proyek k41-dots.

Jangan membuat struktur runtime mandiri `~/.config/quickshell/k41-dots/` atau mengganti entry point shell aktif sebelum desain bootstrap dan integrasi Quickshell diputuskan. Itu merupakan pekerjaan arsitektur proyek lanjutan, bukan asumsi untuk setiap workstream Stage 5.

## Status

K41Dock telah diserahkan dan pengguna mengonfirmasi hasil workstream berhasil. Status workstream: **COMPLETED / USER CONFIRMED SUCCESS**. Perubahan baru tetap memerlukan audit dan regression check.
