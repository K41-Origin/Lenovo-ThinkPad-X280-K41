# Workstream 5 — Launcher

## Tujuan

Menetapkan satu launcher utama yang cepat, keyboard-first, mudah diprediksi, dan tidak menduplikasi fungsi pencarian atau menu lain.

## Batas

Termasuk launcher utama, keybind, pencarian aplikasi, hasil, kategori/action yang benar-benar didukung, navigasi keyboard, command execution safety, dan fallback.

Tidak termasuk redesign global typography/iconography atau penambahan launcher kedua untuk fungsi yang sama.

## Prosedur

1. Audit executable dan package launcher yang terpasang, versi, konfigurasi aktif, keybind Hyprland, desktop entries, environment/session, dan launcher lain yang berjalan.
2. Pastikan launcher yang dipilih kompatibel dengan sesi Wayland dan konfigurasi aktif. Jangan mengandalkan nama executable yang belum diverifikasi.
3. Tentukan satu launcher utama dan satu fallback yang jelas bila dibutuhkan; dokumentasikan alasan pemilihan.
4. Audit konfigurasi dan desktop entries sebelum perubahan. Backup semua file yang akan diubah.
5. Terapkan keybind dan konfigurasi minimal tanpa menimpa konfigurasi pengguna secara membabi buta.
6. Uji pembukaan launcher, pencarian aplikasi, hasil kosong, keyboard navigation, cancel/close, launch aplikasi, dan perilaku ketika executable tidak tersedia.
7. Periksa bahwa keybind tidak bertabrakan dengan keybind dashboard, panel, atau aplikasi.

## Acceptance criteria

- Satu launcher utama dapat dibuka dengan keybind yang ditetapkan.
- Pencarian dan peluncuran aplikasi bekerja dengan desktop entries aktual.
- Navigasi keyboard, hasil kosong, dan penutupan bekerja.
- Tidak ada command berbahaya atau aksi destruktif yang dipicu hanya dengan pencarian/enter tanpa konfirmasi yang sesuai.
- Tidak ada konflik keybind atau launcher duplikat yang membingungkan.
- Fallback terdokumentasi dan dapat digunakan bila launcher utama gagal.

## Rollback dan bukti

Backup konfigurasi launcher dan Hyprland keybind. Catat executable/version, keybind, hasil skenario uji, konflik yang ditemukan, serta log yang relevan.

## Gate keluar

Status VERIFIED memerlukan uji peluncuran aplikasi nyata dan konfirmasi pengguna. Setelah diterima, lanjutkan ke [Workstream 6 — Sidebar](06-SIDEBAR.md).