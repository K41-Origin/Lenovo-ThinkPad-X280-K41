# Operasional, Keamanan, dan Optimization

## Keamanan operasional

Gunakan dokumentasi/upstream resmi untuk paket dan dependensi yang berubah. Jangan menonaktifkan signature verification atau pipe script remote ke shell. Review AUR recipe dan build sebagai user non-root. Jangan mencatat password, LUKS key, token, cookie, atau credential. Backup konfigurasi sebelum perubahan dan siapkan rollback. BlackArch tetap opt-in dan selektif.

### Autologin dan lock screen

`scripts/k41-enable-caelestia-autologin.sh` adalah opsi Stage 5, bukan default instalasi. Ia mengaktifkan passwordless autologin hanya pada `getty@tty1`, lalu memulai Hyprland dari Bash login dan meminta Caelestia mengunci sesi setelah IPC siap. Helper memeriksa target IPC `lock`, meminta penguncian, lalu memverifikasi `lock isLocked` bernilai `true`; exit code perintah saja tidak dianggap bukti layar sudah terkunci. Jika IPC tidak siap atau status terkunci tidak terverifikasi dalam batas waktu, helper menjalankan Hyprlock sebagai fallback. Autologin menghilangkan autentikasi TTY1; lock screen grafis baru aktif setelah compositor dan shell berjalan. Ini bukan pengganti full-disk encryption. Jangan aktifkan pada perangkat dengan risiko akses fisik tanpa enkripsi disk, dan selalu simpan jalur rollback. TTY selain tty1 tetap memakai login normal.

### Audit kondisi boot aktual

Collector read-only `scripts/audit-x280-boot.sh` menghasilkan snapshot UEFI, UKI, LUKS2, TPM2, Plymouth, dan journal. Audit perangkat yang telah direview tersimpan di `reports/boot-audit/20261109T103304Z/boot-audit.txt`.

Temuan penting dari snapshot tersebut:

- UEFI melaporkan TPM2 tersedia dan perangkat `/dev/tpmrm0` terdeteksi.
- Root adalah LUKS2 pada `/dev/nvme0n1p2`, dengan satu passphrase keyslot (slot 0) dan belum ada token TPM2.
- Secure Boot disabled.
- Sistem memakai systemd-boot + UKI dan mkinitcpio `systemd` + `sd-encrypt`.
- Plymouth belum terpasang.

Report adalah snapshot saat audit, bukan jaminan kondisi perangkat saat ini.

### Plymouth splash + TPM2 auto-unlock

Jalankan dari checkout terbaru setelah membaca script:

```bash
git pull --ff-only
bash -n scripts/k41-configure-boot-experience.sh
sudo bash scripts/k41-configure-boot-experience.sh
```

Script akan:

1. Memastikan root aktif adalah `/dev/mapper/cryptroot`, volume LUKS2 dapat diidentifikasi, UKI berada di `/efi`, dan TPM2 terdeteksi.
2. Meminta path backup header LUKS pada filesystem di disk fisik lain. Jangan simpan satu-satunya backup pada SSD yang sama.
3. Memasang paket resmi `plymouth` melalui pacman, memilih tema BGRT, menambahkan hook `plymouth` setelah `systemd` dan sebelum `sd-encrypt`, lalu menambahkan `quiet splash` ke command line UKI.
4. Membangun ulang UKI melalui `mkinitcpio -P`.
5. Meminta konfirmasi terpisah sebelum menambahkan TPM2 token menggunakan PCR 7. Saat diminta, masukkan passphrase LUKS yang sekarang.

TPM2 enrollment bersifat **additive**: script tidak menghapus passphrase/keyslot yang ada. Jika TPM tidak dapat membuka volume, passphrase lama tetap menjadi recovery path dan Plymouth seharusnya menampilkan prompt unlock. Jangan menghapus keyslot passphrase setelah enrollment.

**Batas keamanan penting:** PCR 7 mengikat TPM token pada kebijakan Secure Boot saat ini, tetapi audit menunjukkan Secure Boot sedang disabled. Ini tidak membuktikan bahwa UKI/kernel telah diverifikasi oleh Secure Boot. Perubahan firmware atau Secure Boot dapat membuat TPM gagal membuka volume; passphrase tetap diperlukan sebagai fallback. Jangan menganggap TPM auto-unlock berhasil sebelum reboot fisik membuktikannya.

Setelah menjalankan script, periksa metadata token tanpa menampilkan secret:

```bash
sudo cryptsetup luksDump --dump-json-metadata /dev/nvme0n1p2 | python3 -c 'import json,sys; d=json.load(sys.stdin); print([t.get("type") for t in d.get("tokens",{}).values()])'
sudo bootctl status
```

Kemudian reboot dan verifikasi: splash muncul sejak early boot, tidak ada prompt passphrase ketika TPM unlock sukses, Caelestia lock screen menjadi layar pertama setelah boot, dan passphrase recovery masih dapat digunakan jika TPM unlock gagal. Pengujian tersebut harus dilakukan secara fisik pada X280; script belum mengklaim hasil reboot terverifikasi.

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
