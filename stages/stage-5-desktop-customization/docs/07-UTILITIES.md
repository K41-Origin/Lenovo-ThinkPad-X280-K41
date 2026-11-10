# Workstream 08 — Utilities

## Tujuan

Menyediakan kontrol cepat untuk fungsi perangkat yang relevan, dengan status yang akurat, tindakan aman, dan feedback yang jelas.

## Batas

Kandidat mencakup jaringan, Bluetooth, audio, microphone, brightness, media, Do Not Disturb, dan settings. Hanya kontrol yang didukung oleh hardware, service, dan API yang benar-benar tersedia yang boleh ditampilkan.

Tidak termasuk optimasi daya/thermal tahap 6, penggantian NetworkManager/audio stack, penambahan daemon duplikat, atau perubahan kebijakan sistem luas.

## Prosedur

1. Audit perangkat dan service aktual: NetworkManager, BlueZ, PipeWire/WirePlumber, brightness interface, dan provider lain yang relevan.
2. Tentukan kontrol yang benar-benar diperlukan; jangan menduplikasi panel Caelestia yang tetap dipakai.
3. Tentukan interface, ownership source, runtime path di bawah `~/.config/quickshell/`, deployment, backup, dan rollback.
4. Verifikasi API dan izin operasi sebelum menghubungkan UI dengan tindakan sistem.
5. Implementasikan kontrol satu per satu; setiap aksi harus memiliki feedback sukses/gagal yang jelas.
6. Uji status aktual, perubahan state, kegagalan backend, permission, fullscreen/focus, dan shell restart.
7. Periksa error runtime serta konsumsi resource.

## Acceptance criteria

- Hanya kontrol yang disetujui dan didukung backend aktual yang ditampilkan.
- Status tidak ditebak dan error ditangani dengan jelas.
- Aksi tidak memerlukan privilege berlebih dan tidak merusak konfigurasi sistem.
- Tidak menduplikasi fungsi yang sudah dimiliki Caelestia atau komponen K41 lain.
- Source K41 terpisah dan dapat dipelihara sebagai kandidat komponen k41-shell.
- Pengguna menerima hasil langsung pada X280.

## Status

PLANNED.
