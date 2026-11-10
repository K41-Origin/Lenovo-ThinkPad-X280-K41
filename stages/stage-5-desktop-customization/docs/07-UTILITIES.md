# Workstream 7 — Utilities

## Tujuan

Menyediakan kontrol cepat untuk fungsi perangkat yang relevan, dengan status yang akurat, tindakan aman, dan feedback yang jelas.

## Batas

Kandidat mencakup jaringan, Bluetooth, audio, microphone, brightness, media, Do Not Disturb, dan settings. Hanya kontrol yang didukung oleh hardware, service, dan API yang benar-benar tersedia yang boleh ditampilkan.

Tidak termasuk optimasi daya/thermal tahap 6, penggantian NetworkManager/audio stack, penambahan daemon duplikat, atau perubahan kebijakan sistem luas.

## Prosedur

1. Audit perangkat dan service aktual: NetworkManager, BlueZ, PipeWire/WirePlumber, brightness interface, media controls, DND/notification service, serta API Caelestia/Quickshell.
2. Untuk setiap kontrol, dokumentasikan sumber status, command/API aksi, kebutuhan privilege, efek samping, dan cara mendeteksi kegagalan.
3. Pilih subset kontrol yang berguna. Jangan menampilkan toggle yang hanya dekoratif atau tidak didukung.
4. Bedakan status aktif/nonaktif/tidak diketahui; jangan menampilkan status optimistis jika backend gagal.
5. Backup konfigurasi dan implementasikan satu kontrol pada satu waktu.
6. Uji toggle dan verifikasi state dari backend, bukan hanya perubahan ikon/warna.
7. Uji error permission, service tidak aktif, perangkat tidak tersedia, jaringan putus, dan aksi yang gagal.
8. Pastikan kontrol berisiko tidak menjalankan tindakan destruktif tanpa konfirmasi. Jangan mengubah policy/service global sebagai jalan pintas UI.

## Acceptance criteria

- Setiap kontrol yang ditampilkan didukung dan terhubung ke backend aktual.
- State UI sesuai state backend setelah aksi dan setelah refresh.
- Kegagalan ditampilkan dengan jelas; UI tidak mengklaim aksi berhasil bila backend menolak.
- Kontrol jaringan, Bluetooth, audio, microphone, dan brightness diuji pada hardware yang relevan.
- Tidak ada service/daemon duplikat atau perubahan tahap 6 yang terselip.
- Pengguna menerima interaksi langsung pada X280.

## Rollback dan bukti

Backup konfigurasi utilities. Catat backend/API, privilege, test tiap kontrol, hasil backend, error handling, resource impact, dan konfirmasi pengguna. Redaksi SSID, alamat, device identifiers, serta informasi personal dari laporan.

## Gate keluar

Workstream 7 ditutup hanya setelah setiap kontrol diterima atau dikeluarkan dengan alasan. Setelah itu, buat rencana terpisah untuk fase **global appearance** dan konsistensi lintas-komponen; jangan mulai fase tersebut secara otomatis tanpa audit dan persetujuan.