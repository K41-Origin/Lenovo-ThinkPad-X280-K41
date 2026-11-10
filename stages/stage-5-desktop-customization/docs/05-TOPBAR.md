# Workstream 4 — Topbar

## Tujuan

Membuat panel horizontal di tepi atas layar sebagai area informasi/status desktop yang ringkas. Topbar melengkapi Bottombar tanpa menduplikasi indikator workspace atau mengambil terlalu banyak ruang vertikal.

## Keputusan desain awal

Yang sudah diputuskan:
- Posisi di tepi atas layar.
- Orientasi horizontal.
- Menjadi komponen terpisah dari Bottombar.
- Mengikuti Design System K41 dan mempertahankan area kerja tetap luas.

Yang **belum diputuskan** dan harus ditentukan sebelum implementasi:
- Elemen yang ditampilkan (misalnya waktu/tanggal, system tray, indikator status, atau informasi sesi).
- Alignment kiri/tengah/kanan dan urutan elemen.
- Tinggi, margin, transparansi, radius, dan perilaku auto-hide/persistent.
- Apakah topbar menggunakan native Caelestia bar atau custom Quickshell QML.
- Interaksi, menu, dan keybind yang diperlukan.

Jangan menambahkan elemen hanya karena tersedia di upstream. Setiap elemen harus memiliki fungsi yang jelas dan sumber status yang dapat diverifikasi.

## Batas

Termasuk layout topbar, elemen informasi/status yang disepakati, integrasi tray bila diperlukan, interaksi, visibility, dan perilaku terhadap fullscreen/fokus.

Tidak termasuk workspace dock (Bottombar), launcher, dashboard (sudah dihentikan), sidebar, utilities panel terpisah, atau optimasi hardware Stage 6.

## Prosedur

1. Audit source/config Caelestia aktif, versi Quickshell, monitor/scaling, tray host, status provider, dan panel yang sudah berjalan.
2. Finalisasi daftar elemen dan hierarki sebelum mengubah konfigurasi.
3. Pastikan tiap elemen memiliki sumber data/backend yang benar; hindari indikator dekoratif atau status yang ditebak.
4. Backup konfigurasi/source yang akan disentuh dan siapkan rollback.
5. Implementasikan satu iterasi minimal dengan API upstream yang terverifikasi.
6. Uji alignment, ukuran pada resolusi aktual, interaksi tray/menu, fullscreen, fokus, multi-window, dan shell restart.
7. Periksa error runtime serta konsumsi resource.

## Acceptance criteria

- Topbar berada di tepi atas dan hanya memuat elemen yang disetujui.
- Status yang ditampilkan sesuai backend aktual; unavailable/error ditangani dengan jelas.
- Tidak menduplikasi fungsi Bottombar atau komponen lain.
- Tidak menghalangi input, fokus window, atau aplikasi fullscreen.
- Ukuran dan keterbacaan sesuai display X280.
- Tidak ada error runtime kritis atau konsumsi resource yang tidak wajar.
- Pengguna menerima tampilan dan interaksi langsung pada X280.

## Rollback dan bukti

Backup file konfigurasi dan source custom. Catat versi, elemen beserta sumber datanya, perilaku visibility, skenario uji, log, dan review pengguna.

## Gate keluar

Jangan mulai implementasi sebelum daftar elemen, layout, dan perilaku visibility disetujui. Workstream berikutnya adalah [Launcher](05-LAUNCHER.md).
