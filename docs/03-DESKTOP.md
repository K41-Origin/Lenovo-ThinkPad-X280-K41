# Desktop Environment — Hyprland, Quickshell, Caelestia

## Tahap 3 — Instalasi

Jalankan dari TTY Basic Arch Linux sebagai user biasa:

```bash
sudo bash scripts/k41-install-desktop.sh
```

Entry point ini mendelegasikan ke `scripts/setup-desktop-x280.sh`. Setup memasang stack Wayland/Hyprland, audio, portal, utilitas, dan opsi Caelestia sesuai pilihan operator. Login desktop tetap manual dari TTY; tidak ada display manager/autologin. Jangan menambahkan autostart Caelestia duplikat.

Exit code 0 bukan acceptance desktop. Lanjutkan ke tahap 4.

## Tahap 4 — Desktop Environment Begin: functional validation (TAHAP AKTIF)

Validasi otomatis dan checklist fisik dijalankan melalui satu entry point, dari terminal di sesi Hyprland sebagai user biasa (tanpa sudo):

```bash
bash scripts/k41-desktop-validation.sh
```

Script menjalankan dua collector yang sudah ada, lalu meminta konfirmasi sebelum me-restart Caelestia untuk memeriksa cache dan log runtime yang baru. Restart hanya menyentuh instance Caelestia/Quickshell, bukan Hyprland. Simpan pekerjaan sebelum menyetujui restart. Jawab `y` untuk melakukan restart atau Enter/`n` untuk melewatinya.

Semua bukti untuk satu kali eksekusi disatukan dalam satu direktori `reports/desktop-validation/<timestamp>/`:
- `summary.md`: metadata dan hasil collector.
- `validation.log`: output collector, hasil restart, cache ownership, log Caelestia, dan user journal.
- `desktop/` dan `caelestia/`: detail diagnostik masing-masing.
- `manual-checklist.md`: checklist fisik gabungan.

Selesaikan checklist, lalu tinjau dan redaksi informasi host, perangkat, jaringan, dan log sebelum membagikan laporan. Script tidak melakukan instalasi paket, perubahan konfigurasi, atau perintah privileged. Collector lama tetap dapat dijalankan sendiri untuk diagnosis terarah.

| Area | Kriteria penerimaan |
|---|---|
| Sesi Hyprland | Start, stabil, konfigurasi tanpa error kritis |
| Display | Resolusi, scaling, refresh, brightness, monitor eksternal bila tersedia |
| Input | Keyboard/function keys, TrackPoint, touchpad, klik, tap, scroll |
| Audio | Output, volume/mute, microphone, PipeWire/WirePlumber |
| Jaringan | Wi-Fi connect/disconnect/reconnect; NetworkManager |
| Bluetooth | Uji bila diperlukan; laporkan terpisah, jangan menyamakan tidak dipasang dengan lulus |
| Desktop utilities | Terminal, file manager, launcher, clipboard, screenshot |
| Portals | Screenshot dan screen sharing bila dibutuhkan |
| Caelestia/Quickshell | Panel, launcher, dashboard, widget, notifikasi, indikator, IPC dan interaksi UI |
| Session recovery | Lock/unlock, logout ke TTY, login ulang |
| Logs/stability | Tidak ada error kritis berulang atau crash selama penggunaan normal |

Setiap item berstatus PASS, FAIL, atau NOT TESTED dengan catatan. Collector otomatis hanya bukti pendukung; proses terdeteksi atau IPC merespons tidak membuktikan UI dan interaksi diterima.

**Gate tahap 4:** seluruh fungsi wajib lulus, kegagalan memiliki penyelesaian/pengecualian yang disetujui, checklist direview, dan bukti aman dibagikan disimpan. Sampai gate ini disetujui, tahap 5 tetap PLANNED.

## Tahap 5 — Desktop Environment Customization

Arah desain: minimalis, monoton/monochromatic, elegan, dan premium. Jaga kontras, hirarki visual, keterbacaan, konsistensi, dan responsivitas. Cakupan: panel, launcher, dashboard, widget, notifikasi, wallpaper, typography, icon, border, radius, spacing, dan animasi.

Kustomisasi dilakukan bertahap dengan backup dan rollback. Hindari efek berat pada UHD 620. Acceptance memerlukan screenshot before/after, review visual pada perangkat, interaksi tetap berfungsi, dan tidak ada regresi fungsional tahap 4.

## Tahap 6 — Optimization

Optimasi perangkat dan sistem dilakukan setelah tampilan diterima. Rencana dan batasnya ada di [05 — Operations](05-OPERATIONS.md). Jangan melakukan tuning agresif sebelum baseline terukur.
