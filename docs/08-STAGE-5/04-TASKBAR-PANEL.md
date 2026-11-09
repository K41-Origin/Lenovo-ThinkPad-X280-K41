# Workstream 4 — Taskbar dan Panel

## Tujuan

Menyusun panel utama yang ringkas dan dapat dipindai, dengan status sesi dan akses fungsi yang relevan tanpa redundansi.

## Batas

Termasuk posisi/ukuran panel, workspace indicator, active window bila diperlukan, tray, clock/date, indikator status, serta interaksi panel.

Tidak termasuk redesign global compositor, global icon/cursor, notifications/OSD, utilities panel terpisah, atau aplikasi GTK/Qt.

## Prosedur

1. Audit panel aktif, konfigurasi Caelestia/Quickshell, versi/API upstream, output monitor, scaling/resolusi, tray host, widget, keybind, dan proses.
2. Petakan elemen yang sudah tersedia dan fungsi yang tumpang tindih dengan dashboard/utilities.
3. Tentukan informasi minimum yang harus selalu terlihat; pindahkan informasi sekunder ke komponen yang tepat.
4. Backup konfigurasi dan terapkan satu perubahan layout/fungsi per iterasi.
5. Uji workspace switching, active workspace, tray menu, clock/date, indikator, multi-window, dan perubahan fokus.
6. Uji perilaku pada resolusi/scaling aktual serta aplikasi fullscreen/floating.
7. Periksa runtime error dan resource; jangan menambah tray host atau panel kedua tanpa kebutuhan.

## Acceptance criteria

- Panel stabil, tidak menutupi area kerja secara tidak wajar, dan tetap terbaca.
- Workspace dan indikator status mencerminkan keadaan aktual.
- Tray/menu dan interaksi yang ditampilkan bekerja.
- Tidak ada fungsi duplikat dengan dashboard atau utilities yang membingungkan.
- Panel tidak mengganggu fullscreen, window focus, atau keybind.
- Pengguna menyetujui visual dan interaksi pada perangkat.

## Rollback dan bukti

Backup konfigurasi panel dan catat elemen aktif, posisi, ukuran, scaling, test interaksi, log, dan review pengguna. Hapus data sensitif dari bukti.

## Gate keluar

Status VERIFIED memerlukan uji fungsi panel dan regression workspace/window. Setelah diterima, lanjutkan ke [Workstream 5 — Launcher](05-LAUNCHER.md).