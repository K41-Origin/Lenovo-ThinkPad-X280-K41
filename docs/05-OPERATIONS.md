# Operasional, Keamanan, dan Optimization

## Keamanan operasional

Gunakan dokumentasi/upstream resmi untuk paket dan dependensi yang berubah. Jangan menonaktifkan signature verification atau pipe script remote ke shell. Review AUR recipe dan build sebagai user non-root. Jangan mencatat password, LUKS key, token, cookie, atau credential. Backup konfigurasi sebelum perubahan dan siapkan rollback. BlackArch tetap opt-in dan selektif.

### Autologin dan lock screen

`scripts/k41-enable-caelestia-autologin.sh` adalah opsi Stage 5, bukan default instalasi. Ia mengaktifkan passwordless autologin hanya pada `getty@tty1`, lalu memulai Hyprland dari Bash login dan meminta Caelestia mengunci sesi setelah IPC siap. Autologin menghilangkan autentikasi TTY1; lock screen grafis baru aktif setelah compositor dan shell berjalan. Ini bukan pengganti full-disk encryption. Jangan aktifkan pada perangkat dengan risiko akses fisik tanpa enkripsi disk, dan selalu simpan jalur rollback. TTY selain tty1 tetap memakai login normal.

## Tahap 6 — Desktop & Hardware Optimization

Tahap ini baru dimulai setelah tahap 4 (functional validation) dan tahap 5 (customization) diterima.

### Baseline read-only

- `scripts/audit-x280-hardware.sh`: inventaris hardware.
- `scripts/audit-x280-power-management.sh`: baseline daya.
- `scripts/set-x280-power-profile.sh`: selector power-profiles-daemon; perubahan memerlukan `--apply`.

Collector audit tidak melakukan tuning. Simpan hasil sebelum perubahan dan ukur ulang dalam kondisi workload yang dapat dibandingkan.

### Urutan optimasi

1. Desktop resource use dan startup/background services.
2. CPU: governor/EPP/turbo, idle states, workload, throttling.
3. GPU Intel UHD 620/i915: runtime power management, Mesa/Vulkan, video acceleration, display power.
4. Thermal/fan: suhu idle dan sustained load, fan response, throttling, stabilitas.
5. Battery/power: brightness, runtime PM, USB autosuspend, Wi-Fi, service, discharge rate dan charge thresholds.
6. Suspend/resume; hibernation hanya setelah resume configuration dan swap/offset tervalidasi.
7. Extended stability, regression, dan perbandingan performa/daya.

Ubah satu variabel per iterasi, dokumentasikan alasan, baseline, hasil, risiko, dan rollback. Jangan memaksakan governor performance atau fan control yang tidak didukung. Jangan menjalankan TLP, power-profiles-daemon, tuned, atau pengelola daya lain secara bersamaan tanpa analisis konflik dan alasan yang diuji.

## Recovery

Pertahankan akses TTY untuk pemulihan desktop. Setelah kegagalan operasi disk, inspeksi keadaan perangkat sebelum tindakan berikutnya; jangan rerun membabi buta. Perubahan konfigurasi sistem harus memiliki cara rollback yang jelas.

## Hardware baseline

Baseline historis repository menyebut i5-8250U, UHD 620/i915, RAM 8 GB, WD SN730 NVMe, Intel 8265 Wi-Fi, dan baterai LGC 01AV470. Ini bukan inventaris real-time atau bukti kesehatan baterai saat ini. Verifikasi perangkat aktual dengan collector sebelum optimasi. Fan 0 RPM pada satu snapshot suhu rendah bukan bukti kerusakan.
