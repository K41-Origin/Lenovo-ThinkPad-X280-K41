# Operasional, Keamanan, Hardware

## Security
Gunakan upstream resmi untuk paket/dependensi yang berubah. Jangan disable signature verification atau pipe remote script ke shell. Review AUR recipe dan build non-root. Jangan log password, LUKS key, token, cookie, credential. Backup konfigurasi dan siapkan rollback. BlackArch opt-in dan selektif.

## Layanan dan daya
NetworkManager digunakan. Snapshot sebelumnya menemukan `power-profiles-daemon` aktif; jangan menambah TLP/tuned/pengelola daya pesaing tanpa alasan dan pengujian.

- `scripts/audit-x280-hardware.sh`: inventaris read-only.
- `scripts/audit-x280-power-management.sh`: baseline daya read-only.
- `scripts/set-x280-power-profile.sh`: selector PPD; perubahan memerlukan `--apply`.

Collector tidak melakukan tuning. Eksperimen daya bukan prioritas; tuning ditunda ke tahap final.

## Recovery
Pertahankan log bertimestamp. Kegagalan sebelum disk operation berbeda dari setelah operasi dimulai. Setelah kegagalan disk, inspeksi keadaan perangkat. Pertahankan akses TTY untuk recovery desktop. Tidak ada tindakan destruktif tanpa otorisasi dan identifikasi target.

## Hardware dan tahap final
Baseline historis: i5-8250U, UHD 620/i915, RAM 8 GB, WD SN730 NVMe, Intel 8265 Wi-Fi, baterai LGC 01AV470. Ini bukan snapshot terkini atau tes kesehatan baterai. Jalankan collector. Fan 0 RPM tunggal bukan bukti kerusakan.

Setelah desktop dan optional software diterima, lakukan CPU/GPU performance, thermal/fan, power/battery, suspend/hibernate/resume, extended stability/regression. Ubah satu variabel per iterasi; catat baseline, hasil, dan rollback.
