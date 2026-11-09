# Operasional, Keamanan, dan Optimization

## Keamanan operasional

- Gunakan dokumentasi resmi/upstream untuk package dan dependency yang berubah.
- Jangan menonaktifkan signature verification atau pipe script remote ke shell.
- Review AUR recipe dan build sebagai user non-root.
- Jangan mencatat password, LUKS key, token, cookie, atau credential.
- Backup konfigurasi sebelum perubahan; siapkan rollback.
- BlackArch tetap opt-in dan selektif.

## Boot experience

Workstream 1 — Boot Experience telah **COMPLETED / USER ACCEPTED pada 2026-11-10**. Status dan batas keputusan dimiliki [dokumen Workstream 1](08-STAGE-5/01-BOOT-EXPERIENCE.md). Catatan audit lama di bawah snapshot historis bukan backlog aktif dan tidak boleh mengubah status penutupan.

Script boot memiliki efek sistem nyata. Jangan menjalankan ulang installer, mengubah TPM2/LUKS, membangun ulang UKI, atau mengubah unit hanya untuk membaca dokumentasi. Jika pengguna melaporkan masalah boot baru, audit kondisi aktual dan recovery path terlebih dahulu.

Prinsip recovery yang tetap berlaku:
- Pertahankan passphrase LUKS sebagai jalur recovery; jangan menghapus keyslot passphrase.
- TPM2 enrollment bersifat additive, tetapi keberhasilannya harus dibuktikan dari perangkat sebelum diklaim aktif.
- PCR 7 bukan bukti Secure Boot verification bila Secure Boot tidak aktif.
- Jika rebuild UKI gagal, jangan reboot sampai konfigurasi dipulihkan atau artefak boot diperiksa.
- Jangan menambah arbitrary delay atau unit transisi yang bersaing dengan unit upstream.

## Tahap 6 — Desktop & Hardware Optimization

Tahap 6 **PLANNED** dan baru dimulai setelah Stage 5 diterima.

### Baseline read-only

- `scripts/audit-x280-hardware.sh` — inventaris hardware.
- `scripts/audit-x280-power-management.sh` — baseline daya.
- `scripts/set-x280-power-profile.sh` — selector power-profiles-daemon; perubahan memerlukan `--apply`.

Collector audit tidak melakukan tuning. Simpan hasil baseline sebelum perubahan dan ukur ulang pada kondisi workload yang sebanding.

### Urutan optimasi

1. Desktop resource use dan startup/background services.
2. CPU: governor/EPP/turbo, idle states, workload, throttling.
3. GPU Intel UHD 620/i915: runtime power management, Mesa/Vulkan, video acceleration, display power.
4. Thermal/fan: suhu idle dan sustained load, fan response, throttling, stabilitas.
5. Battery/power: brightness, runtime PM, USB autosuspend, Wi-Fi, service, discharge rate, charge thresholds.
6. Suspend/resume; hibernation hanya setelah konfigurasi resume dan swap/offset tervalidasi.
7. Extended stability, regression, dan perbandingan performa/daya.

Ubah satu variabel per iterasi. Catat alasan, baseline, hasil, risiko, dan rollback. Jangan memaksakan governor performance atau fan control yang tidak didukung. Jangan menjalankan TLP, power-profiles-daemon, tuned, atau pengelola daya lain secara bersamaan tanpa analisis konflik.

## Recovery

Pertahankan akses TTY untuk pemulihan desktop. Setelah kegagalan operasi disk, inspeksi keadaan perangkat sebelum tindakan berikutnya; jangan rerun membabi buta. Perubahan konfigurasi sistem harus memiliki rollback yang jelas.

## Hardware baseline historis

Baseline historis repository menyebut i5-8250U, Intel UHD 620/i915, RAM 8 GB, WD SN730 NVMe, Intel 8265 Wi-Fi, dan baterai LGC 01AV470. Ini bukan inventaris real-time atau bukti kesehatan baterai. Verifikasi perangkat aktual dengan collector sebelum optimasi. Fan 0 RPM pada satu snapshot suhu rendah bukan bukti kerusakan.
