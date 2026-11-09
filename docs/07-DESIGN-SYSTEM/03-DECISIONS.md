# Decisions — K41 Desktop Design System

## Disetujui

| Area | Keputusan |
|---|---|
| Nama desain | **K41 Obsidian Minimalism** |
| Palet | **Graphite Monochrome** |
| Karakter | Modern, minimalis, monochromatic, elegan, premium |
| Shell utama | Caelestia |
| Runtime shell | Quickshell |
| Compositor | Hyprland |
| Wallpaper | Abstract monochrome |
| Launcher | Fuzzel sebagai launcher utama |
| Dashboard | On-demand, bukan selalu memenuhi desktop |
| Motion | Subtle dan fungsional |
| Transparency | Selektif |
| Blur | Minimal |
| Performance | Prioritas tinggi; hindari efek/polling/dependency yang tidak perlu |
| Hardware tuning | Di luar Stage 5; masuk Stage 6 |
| Visual acceptance | Review langsung oleh pengguna pada X280; tanpa screenshot |

## Batas yang tidak boleh dilanggar tanpa keputusan baru

- Jangan mengubah autentikasi/PAM atau recovery hanya untuk tampilan.
- Jangan menghapus passphrase/keyslot LUKS.
- Jangan mengganti arsitektur Caelestia/Quickshell/Hyprland.
- Jangan menambah daemon atau komponen duplikat tanpa alasan.
- Jangan mengorbankan keterbacaan untuk monochrome.
- Jangan mengubah identitas visual inti boot tanpa persetujuan pengguna.

## Masih perlu diputuskan atau diverifikasi

- Nilai final spacing, radius, ukuran panel, opacity, dan durasi animasi.
- Icon theme/cursor final lintas aplikasi.
- Implementasi token tunggal yang benar-benar dikonsumsi semua generator/config.
- Kebutuhan final paket font/theme berdasarkan audit runtime.
- Strategi integrasi GTK/Qt dan aplikasi yang tetap maintainable.
- Dampak performa visual pada kondisi workload yang dapat dibandingkan.

## Change control

Perubahan pada arah desain, token global, atau keputusan shell harus dicatat di dokumen ini sebelum implementasi luas. Detail status runtime tidak disimpan di sini; perbarui [Status proyek](../06-STATUS.md) dan dokumen workstream pemilik.
