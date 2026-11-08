# Desktop: Hyprland, Caelestia, Quickshell

Setup desktop dijalankan setelah OS boot; entry point `scripts/setup-desktop-x280.sh`. Exit 0 berarti setup selesai, bukan UI diterima. Login manual dari TTY lalu `start-hyprland`; tanpa display manager/autologin. Jangan menambah autostart Caelestia duplikat.

## Functional validation — tahap aktif
Uji pada X280: Hyprland start dan panel; keyboard, touchpad, TrackPoint; Wi-Fi/NetworkManager; audio/PipeWire; XDG portals; lock/logout/TTY recovery; Caelestia panel, launcher, dashboard, notifikasi, indikator, IPC; tidak ada error kritis pada log. Bluetooth dicatat terpisah karena BlueZ belum tersedia pada snapshot sebelumnya. Process/IPC detection bukan acceptance UI.

## Desktop customization — tahap berikutnya
Mulai setelah functional acceptance. Arah visual: minimal, elegan, premium, monochromatic dengan tone serasi, kontras dan hirarki jelas. Konsisten pada panel, launcher, dashboard, widget, notifikasi, wallpaper, typography, icon, border, radius, spacing, animasi. Terbaca pada 1920×1080; hindari efek berat. Backup konfigurasi dan siapkan rollback; utamakan dukungan upstream. Acceptance memerlukan screenshot before/after, review fisik, interaksi berfungsi, tanpa regresi kritis.

Hardware/power/suspend/stability ditunda ke tahap final; software opsional menyusul customization.
