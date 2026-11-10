# Components — Desktop Scope and Behavior

Dokumen ini mendefinisikan tujuan desain komponen. Urutan pengerjaan dan status aktual berada di [Stage 5](../../stages/stage-5-desktop-customization/docs/README.md) dan [Status](../06-STATUS.md).

| Komponen | Tujuan dan perilaku | Batas utama |
|---|---|---|
| Boot experience | Identitas K41 konsisten pada power-on, reboot, poweroff, dan handoff session | Jangan mengorbankan recovery boot atau keamanan LUKS |
| Lock screen | Wallpaper/blur sebagai latar, jam/tanggal terbaca, prompt sederhana | Pertahankan autentikasi upstream; jangan ubah PAM untuk kosmetik |
| Dashboard | Informasi terkurasi, dibuka saat diminta | Tidak memenuhi desktop terus-menerus |
| Taskbar/panel | Workspace, tray, clock, indikator status yang mudah dipindai | Ringkas dan tidak menduplikasi dashboard/utilities |
| Launcher | Satu launcher utama, keyboard-first | Hindari launcher ganda dan aksi berbahaya |
| Sidebar | Navigasi dan quick access sesuai kebutuhan | Muncul saat diminta, tidak menutupi konten |
| Utilities | Quick toggles/kontrol perangkat relevan | Status aktual jelas; tindakan aman dan dapat diprediksi |
| Notifications/OSD | Hierarki jelas, ukuran/durasi terkendali | Tidak mengganggu secara berlebihan |
| Clock/calendar | Tipografi bersih dan informasi secukupnya | Mudah dipindai |
| System widgets | CPU/RAM/baterai/jaringan bila berguna | Polling hemat dan tidak redundan |
| Audio/brightness/media | Kontrol sederhana dan konsisten | Gunakan integrasi yang sudah tersedia |
| Wallpaper | Abstract monochrome sesuai panel/scaling | Mendukung konten, bukan bersaing |
| Typography/icons/cursor | Keluarga visual konsisten dan terbaca | Hindari campuran theme tanpa alasan |
| Window/compositor | Border, focus, gaps, radius, opacity, workspace/floating | Tidak merusak keybind, input, monitor, atau window rules |
| Terminal | Graphite, teks kontras, monospace | Pertahankan Foot |
| GTK/Qt/file manager | Mendekati design tokens dengan metode maintainable | Hindari patch rapuh dan theme generator yang berkompetisi |

## Shell architecture

- Hyprland adalah compositor.
- Quickshell adalah runtime framework.
- Caelestia adalah shell utama yang berjalan di atas Quickshell.

Prioritaskan konfigurasi/theming resmi upstream. Jangan mengganti Caelestia dengan shell buatan sendiri atau membuat ulang fitur upstream tanpa alasan teknis yang kuat.

## Cross-component consistency

Design tokens, typography, iconography, wallpaper, notifications/OSD, window appearance, terminal, GTK/Qt harus mengikuti Foundations. Integrasi lintas-komponen dikerjakan secara terencana; jangan membuka pekerjaan paralel yang tidak diperlukan oleh workstream aktif.
