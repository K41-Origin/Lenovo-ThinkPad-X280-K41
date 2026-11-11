# Workstream 01 — Boot Experience

**Status: REOPENED — DESKTOP STARTUP FAILURE UNDER INVESTIGATION.**  
Audit report reviewed: `reports/stage-5-desktop-customization/01-boot-experience/audits/20261111T063301Z/report.txt`.

## Keputusan tetap

- Plymouth adalah satu-satunya renderer boot splash.
- Tidak ada QML, Quickshell, Caelestia, Hyprland, atau compositor dalam jalur visual boot.
- Identitas visual: background hitam, wordmark K41 putih, ring 12 glyph persegi panjang, satu glyph menyala bergantian.
- Plymouth menangani prompt LUKS melalui integrasi initramfs yang tersedia.
- Desktop lock screen dan transisi ke Hyprland adalah lifecycle terpisah dari renderer bootscreen.
- TPM/LUKS, Secure Boot, bootloader, kernel command line, dan autentikasi tidak diubah oleh installer bootscreen.

## Hasil audit perangkat — 11 November 2026

Laporan terbaru menunjukkan konfigurasi aktual berikut:

| Area | Temuan |
|---|---|
| Perangkat | Lenovo ThinkPad X280 |
| Firmware | UEFI 64-bit; Secure Boot dilaporkan disabled |
| Bootloader | systemd-boot 262.1-1-arch; entry aktif `arch-linux.efi` |
| EFI System Partition | `/efi`, vfat, sekitar 1 GiB |
| Root | NVMe partition → LUKS2 → `/dev/mapper/cryptroot` → ext4 |
| Kernel command line | Memuat `rd.luks.name=…=cryptroot`, `root=/dev/mapper/cryptroot`, `quiet splash` |
| Initramfs | mkinitcpio 42.2; HOOKS saat audit: `systemd → plymouth → sd-encrypt` dengan hook lain tetap dipertahankan |
| UKI | Preset `linux.preset` menunjuk ke `/efi/EFI/Linux/arch-linux.efi` |
| Plymouth | Paket 26.134.222-3 dan file tema K41 ditemukan |
| TPM | Device `/dev/tpm0` dan `/dev/tpmrm0` terdeteksi; status token LUKS tidak dapat disimpulkan |
| Desktop | Hyprland session target tercapai setelah boot |

### Batas kualitas laporan

Collector dijalankan sebagai user non-root. Karena itu sebagian pemeriksaan ditolak permission, termasuk pembacaan beberapa file EFI/loader, status device-mapper/LUKS, metadata LUKS, dan isi image initramfs. Laporan tidak membuktikan apakah TPM token terdaftar, apakah K41 merupakan theme default yang aktif, atau apakah isi UKI benar-benar memuat aset tema. Jangan mengubah TPM/LUKS berdasarkan laporan ini.

Laporan juga menunjukkan:
- `k41-plymouth-release.service` aktif/enabled.
- `plymouth-quit.service` memakai drop-in `k41-lock-handoff.conf`.
- `getty@tty1` memiliki override autologin.
- Log mencatat lock handoff tidak mencapai marker dalam 75 detik; helper menghentikan getty tty1 dan melepaskan Plymouth. Ini adalah masalah lifecycle sesi/lock, bukan masalah renderer tema. Tidak disentuh oleh installer tema pada perubahan ini.

## Implementasi repository

### Entry point

`scripts/k41-configure-boot-experience.sh` kini hanya mendelegasikan ke `scripts/k41-install-plymouth-theme.sh`.

Installer tema:
1. Memastikan berjalan sebagai root dan memeriksa UEFI serta mount EFI `/efi`.
2. Memeriksa filesystem EFI, file konfigurasi, preset UKI, dan file sumber tema.
3. Memvalidasi HOOKS aktif dengan urutan `systemd → plymouth → sd-encrypt`; tidak mengedit HOOKS.
4. Memastikan kernel command line sudah memuat `splash`; tidak mengedit command line.
5. Membaca lokasi UKI dari `linux.preset`; tidak mengasumsikan lokasi selain hasil konfigurasi aktif.
6. Membuat backup UKI, initramfs yang ada, konfigurasi Plymouth, dan tema sebelum perubahan.
7. Memasang file tema K41 lalu menjalankan `plymouth-set-default-theme -R k41` untuk memilih tema dan membangun ulang initramfs/UKI.
8. Memverifikasi theme terpilih dan file UKI tetap tersedia.

Installer tidak:
- Mengubah partisi, filesystem, bootloader entry, Secure Boot, kernel command line, atau HOOKS.
- Menjalankan pacman atau mengubah paket.
- Mengubah LUKS metadata/keyslot, mendaftarkan TPM, atau mengubah PCR policy.
- Membuat/mengubah unit systemd, getty, autologin, PAM, lock screen, atau konfigurasi desktop.
- Menggunakan QML/Quickshell.

### Artefak kanonis

- Installer entry point: `workstreams/01-boot-experience/scripts/k41-configure-boot-experience.sh`
- Installer tema: `workstreams/01-boot-experience/scripts/k41-install-plymouth-theme.sh`
- Theme descriptor: `workstreams/01-boot-experience/themes/plymouth/k41/k41.plymouth`
- Theme script: `workstreams/01-boot-experience/themes/plymouth/k41/k41.script`
- Tests: `test-boot-experience.sh`, `test-plymouth-k41-theme.sh`, `test-plymouth-only-boot.sh`

## Reopened: laporan kegagalan startup setelah instalasi tema

Pengguna melaporkan telah menjalankan ulang `k41-install-plymouth-theme.sh`. Pada boot berikutnya sistem masuk ke TTY 2, bukan desktop; menjalankan `start-hyprland` secara manual dari TTY juga mengalami stuck loading. Belum ada report runtime terbaru yang membuktikan komponen penyebabnya.

Petunjuk yang perlu diuji bersama Workstream 02:
- `k41-plymouth-quit-after-lock.sh` memiliki timeout 75 detik dan pada timeout menghentikan `getty@tty1.service`, melepaskan Plymouth, lalu menjalankan `chvt 2`.
- `k41-lock-caelestia-after-start.sh` menunggu Caelestia lock IPC hingga 45 percobaan, kemudian mencoba Hyprlock fallback.
- `k41-start-hyprland.sh` menjalankan upstream `start-hyprland` dan mengalihkan stdout/stderr ke `~/.local/state/k41/hyprland-startup.log`.
- Bash profile hanya memanggil wrapper dari tty1. Percobaan manual dari tty2 tidak identik dengan jalur autologin tersebut.

Ini adalah hipotesis jalur eksekusi berdasarkan source yang ada, bukan root cause yang telah dibuktikan. Jangan mengubah Plymouth, getty, autologin, systemd units, Hyprland, PAM, TPM/LUKS, atau konfigurasi boot sebelum report startup terbaru dianalisis. Script audit Workstream 02 mengumpulkan journal boot saat ini/sebelumnya, state tty1/tty2, unit systemd, startup log, dan metadata sesi tanpa mengubah sistem.

## Validasi dan acceptance

- Static tests memeriksa kontrak Plymouth-only dan memastikan installer tidak mengubah TPM/LUKS, bootloader, systemd lifecycle, atau autologin.
- CI memvalidasi sintaks dan kontrak statis; CI bukan bukti boot fisik.
- Installer belum dijalankan pada ThinkPad X280 setelah refactor ini.
- Status runtime theme aktif, UKI contents, prompt LUKS, dan tampilan saat reboot tetap **NOT VERIFIED** sampai pengujian perangkat dilakukan.

## Referensi upstream

- ArchWiki Plymouth: https://wiki.archlinux.org/title/Plymouth
- Arch manual `plymouth-set-default-theme`: https://man.archlinux.org/man/plymouth-set-default-theme.1.en
- Arch manual `mkinitcpio`: https://man.archlinux.org/man/mkinitcpio.8

