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

### Native K41 Plymouth early-boot theme

Tema native Plymouth sekarang tersedia di `themes/plymouth/k41/`. Tema memakai background hitam, wordmark K41 di tengah, dan ring 12 titik yang dianimasikan oleh callback refresh Plymouth. Callback password mempertahankan prompt dan indikator bullet untuk fallback passphrase LUKS. Plymouth script themes memang menyediakan refresh, password-display, dan normal-display callbacks; tema dimasukkan ke initramfs/UKI saat preset dibangun ulang. Referensi: [ArchWiki Plymouth](https://wiki.archlinux.org/title/Plymouth) dan contoh API script theme upstream.

Untuk mengaktifkan tema pada perangkat yang sudah menjalankan konfigurasi boot-experience sebelumnya, gunakan installer khusus ini (tidak menjalankan TPM enrollment ulang):

```bash
git pull --ff-only
bash -n scripts/k41-install-plymouth-theme.sh
sudo bash scripts/k41-install-plymouth-theme.sh
bash tests/test-plymouth-k41-theme.sh
bash tests/test-boot-experience.sh
```

Installer memeriksa hook `systemd -> plymouth -> sd-encrypt`, parameter `quiet splash`, mount `/efi`, dan preset kernel. Ia membuat backup tema/config sebelumnya, memasang tema `k41`, memilihnya sebagai default, lalu menjalankan `mkinitcpio -P` untuk membangun ulang initramfs dan UKI. Installer ini tidak mengubah keyslot, token TPM2, atau konfigurasi LUKS. Jika build gagal, jangan reboot; backup konfigurasi tema ada di `/var/lib/k41/boot-experience/theme-backups/`.

**Batas:** Plymouth baru dapat menggambar setelah firmware menyerahkan display ke kernel/initramfs dan framebuffer/KMS siap. Karena itu, tema tidak dapat menggantikan logo firmware Lenovo sebelum handoff tersebut. Jika sepersekian detik output TTY masih muncul, itu perlu ditelusuri terpisah melalui urutan KMS/Plymouth dan parameter kernel; tema custom sendiri tidak membuktikan flicker sudah hilang.

### Animated K41 handoff splash (Quickshell)

Setelah konfigurasi Plymouth/TPM2 yang sudah ada, jalankan dari checkout terbaru:

```bash
git pull --ff-only
bash -n scripts/k41-install-animated-boot-splash.sh
sudo bash scripts/k41-install-animated-boot-splash.sh
bash tests/test-animated-boot-splash.sh
```

Installer menyalin konfigurasi Quickshell ke `~/.config/quickshell/k41-boot-splash/`, memasang helper lock terbaru, lalu menambahkan pemanggilan overlay pada callback Hyprland-start yang sudah ada. Overlay hitam dengan teks K41 dan spinner ringan diminta sebelum Caelestia mulai; helper menutup proses Quickshell hanya setelah status lock Caelestia terverifikasi. Installer ini tidak mengubah LUKS, TPM, UKI, mkinitcpio, atau bootloader. Untuk membatalkan, hapus blok bertanda `K41 ANIMATED BOOT SPLASH START/END` dari `~/.config/hypr/hyprland.lua` dan direktori `~/.config/quickshell/k41-boot-splash`; helper lock dapat dipulihkan dari backup autologin jika diperlukan.

**Batas implementasi saat ini:** animasi Quickshell hanya mencakup handoff sejak Hyprland mulai mengambil alih display. Plymouth early-boot menggunakan tema K41 custom setelah installer `k41-install-plymouth-theme.sh` dijalankan dan UKI dibangun ulang. Quickshell overlay menangani tahap handoff Hyprland. Layer-shell stacking terhadap lockscreen Caelestia dan transisi tanpa flicker wajib diuji langsung di X280; jangan menganggap hasil visual telah VERIFIED sebelum reboot fisik.

### Plymouth splash + TPM2 auto-unlock

Jalankan dari checkout terbaru setelah membaca script:

```bash
git pull --ff-only
bash -n scripts/k41-configure-boot-experience.sh
sudo bash scripts/k41-configure-boot-experience.sh
```

**Catatan pelaksanaan (2026-11-09):** Pengguna mengonfirmasi bahwa `scripts/k41-configure-boot-experience.sh` berhasil dijalankan. Ini mencatat keberhasilan eksekusi script saja; reboot fisik dan acceptance splash, TPM2 auto-unlock, serta lock-screen handoff belum dikonfirmasi. Jangan tandai fitur boot sebagai VERIFIED sebelum pemeriksaan pascareboot selesai.

Script akan:

1. Memastikan root aktif adalah `/dev/mapper/cryptroot`, volume LUKS2 dapat diidentifikasi, UKI berada di `/efi`, dan TPM2 terdeteksi.
2. Membuat backup otomatis untuk file konfigurasi boot di `/var/lib/k41/boot-experience/backups/`. Script tidak meminta lokasi backup header LUKS. Backup header LUKS dilewati agar proses lebih sederhana; karena itu, jangan menghapus/mengubah keyslot passphrase dan pastikan passphrase lama tetap tersimpan aman.
3. Memasang paket resmi `plymouth` melalui pacman, memasang dan memilih tema K41 custom, menambahkan hook `plymouth` setelah `systemd` dan sebelum `sd-encrypt`, lalu menambahkan `quiet splash` ke command line UKI.
4. Membangun ulang UKI melalui `mkinitcpio -P`.
5. Mengubah TTY1 autologin menjadi mode senyap (`--noissue --nohostname`), menjalankan `plymouth quit --retain-splash` sebelum Hyprland agar DRM dilepas tetapi frame terakhir splash tetap tertahan, dan menahan unit `plymouth-quit.service` sampai helper Caelestia memverifikasi status lock. Compositor kemudian menggambar lock screen sebagai tampilan pertama yang terlihat. Animasi splash dapat berhenti pada frame terakhir selama handoff.
6. Jika Caelestia tidak dapat dikunci, helper mencoba Hyprlock. Jika tidak ada marker lock yang valid dalam 75 detik, helper root menghentikan `getty@tty1.service` dan berpindah ke TTY2; ini mencegah autologin TTY dibiarkan terbuka.
7. Meminta konfirmasi terpisah sebelum menambahkan TPM2 token menggunakan PCR 7. Saat diminta, masukkan passphrase LUKS yang sekarang.

TPM2 enrollment bersifat **additive**: script tidak menghapus passphrase/keyslot yang ada. Backup konfigurasi lokal bukan backup LUKS header; jika header rusak, pemulihan lebih terbatas tanpa header backup eksternal. Jika TPM tidak dapat membuka volume, passphrase lama tetap menjadi recovery path dan Plymouth seharusnya menampilkan prompt unlock. Jangan menghapus keyslot passphrase setelah enrollment.

**Batas keamanan penting:** PCR 7 mengikat TPM token pada kebijakan Secure Boot saat ini, tetapi audit menunjukkan Secure Boot sedang disabled. Ini tidak membuktikan bahwa UKI/kernel telah diverifikasi oleh Secure Boot. Perubahan firmware atau Secure Boot dapat membuat TPM gagal membuka volume; passphrase tetap diperlukan sebagai fallback. Jangan menganggap TPM auto-unlock berhasil sebelum reboot fisik membuktikannya.

Setelah menjalankan script, periksa metadata token tanpa menampilkan secret:

```bash
sudo cryptsetup luksDump --dump-json-metadata /dev/nvme0n1p2 | python3 -c 'import json,sys; d=json.load(sys.stdin); print([t.get("type") for t in d.get("tokens",{}).values()])'
sudo bootctl status
```

Kemudian reboot dan verifikasi: splash muncul sejak early boot, tidak ada prompt passphrase ketika TPM unlock sukses, tidak ada banner/login TTY atau desktop Hyprland yang terlihat sebelum lock, Caelestia lock screen menjadi layar pertama setelah boot, dan passphrase recovery masih dapat digunakan jika TPM unlock gagal. Jika Caelestia gagal, pastikan Hyprlock fallback bekerja; jika keduanya gagal, pastikan TTY1 autologin dihentikan setelah timeout. Pengujian tersebut harus dilakukan secara fisik pada X280; script belum mengklaim hasil reboot terverifikasi.

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
