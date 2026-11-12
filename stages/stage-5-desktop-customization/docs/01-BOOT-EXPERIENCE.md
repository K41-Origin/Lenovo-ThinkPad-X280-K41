# Workstream 01 — Boot Experience

**Status: PAUSED — INVESTIGATION PENDING (2026-11-12).** Implementasi Plymouth/K41 tersedia di repository, tetapi pengguna melaporkan splash tidak terlihat pada boot aktual. Audit menunjukkan service Plymouth berhasil dimulai; hal tersebut belum membuktikan frame splash benar-benar terlihat. Jangan lanjutkan perubahan implementasi sampai penyebabnya diperiksa.

Status ini menggantikan label COMPLETE/USER ACCEPTED yang sebelumnya tercantum di beberapa dokumen. IMPLEMENTED tidak sama dengan runtime VERIFIED atau USER ACCEPTED.

Audit read-only terbaru: reports/stage-5-desktop-customization/01-boot-experience/audits/20261112T051447Z/report.txt (2026-11-12 05:14 UTC). Laporan memuat identitas perangkat, UUID, jalur lokal, dan journal; jangan membagikannya tanpa pemeriksaan/redaksi.

## Keputusan arsitektur yang tetap berlaku

- Plymouth adalah satu-satunya renderer boot splash.
- Tidak menggunakan QML, Quickshell, Caelestia, Hyprland, atau compositor untuk menggambar boot splash.
- Identitas visual K41: background hitam, wordmark K41 putih, ring 12 glyph persegi panjang, satu glyph menyala bergantian.
- Plymouth menangani prompt LUKS melalui integrasi initramfs.
- Desktop lock screen dan transisi ke Hyprland merupakan lifecycle terpisah dari renderer boot splash.
- Jangan mengubah TPM/LUKS, Secure Boot, bootloader, kernel command line, autentikasi, atau unit sistem tanpa bukti dan rencana recovery.

## Status implementasi repository

Artefak implementasi yang tersedia:
- Entry point: workstreams/01-boot-experience/scripts/k41-configure-boot-experience.sh
- Installer tema: workstreams/01-boot-experience/scripts/k41-install-plymouth-theme.sh
- Theme descriptor/script: workstreams/01-boot-experience/themes/plymouth/k41/
- Handoff helper: workstreams/01-boot-experience/scripts/k41-plymouth-quit-after-lock.sh
- Hyprland launcher: workstreams/01-boot-experience/scripts/k41-start-hyprland.sh
- Audit collector: workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh

Installer tema memiliki efek sistem nyata: memeriksa konfigurasi boot, memasang tema, memilih tema, dan membangun ulang initramfs/UKI melalui mekanisme yang dipanggilnya. **Jangan jalankan ulang installer selama status PAUSED.**

Installer tidak dimaksudkan untuk mengubah partisi, metadata/keyslot LUKS, TPM enrollment/PCR policy, Secure Boot, atau autentikasi.

## Temuan audit perangkat — 2026-11-12

Audit terbaru bersifat READ-ONLY. Ringkasan yang relevan:

| Area | Temuan |
|---|---|
| Boot mode | UEFI; Secure Boot disabled |
| Bootloader | systemd-boot; entry aktif berupa UKI arch-linux.efi |
| Kernel command line | Memuat parameter root LUKS dan quiet splash |
| Initramfs | HOOKS memuat systemd, plymouth, dan sd-encrypt dalam urutan tersebut |
| UKI | UKI aktif ditemukan; inventory image menunjukkan binary Plymouth dan komponen terkait |
| Plymouth theme | Theme default dilaporkan k41; file tema ditemukan |
| DRM/framebuffer | simpledrm muncul lebih awal; i915 kemudian menjadi framebuffer utama |
| Plymouth startup | plymouth-start.service berhasil dimulai di initramfs; switch-root service selesai |
| Display handoff | k41-plymouth-release.service menjalankan plymouth quit --retain-splash sekitar detik ke-15 |
| Console | Journal mencatat fbcon mengambil alih console sekitar detik ke-16 |
| Plymouth quit | plymouth-quit.service selesai sekitar detik ke-22 |

### Interpretasi dan batas bukti

1. Data mendukung bahwa Plymouth dimuat dan service lifecycle berjalan. Ini belum membuktikan frame tema K41 terlihat pada panel.
2. Urutan release service, fbcon takeover, dan startup desktop membuat display handoff relevan untuk diperiksa. Belum terbukti bahwa salah satunya penyebab splash tidak terlihat.
3. Keberadaan file tema dan binary dalam UKI tidak membuktikan script tema berhasil dieksekusi atau renderer berhasil menggambar frame.
4. Belum ada bukti bahwa k41-repair-caelestia-modules.sh mengubah atau merusak Plymouth.
5. Audit 11 November mencatat lock-readiness timeout 75 detik. Temuan historis itu tidak boleh dianggap otomatis menjelaskan boot terbaru tanpa pencocokan journal dan helper aktual.

## Hipotesis yang masih harus diuji

- Renderer/theme K41 gagal menggambar frame meskipun daemon berjalan.
- Display ownership atau VT/framebuffer handoff menyebabkan frame tertutup atau diganti.
- Theme asset atau konfigurasi runtime di UKI berbeda dari asumsi.
- Interaksi release helper, getty, launcher Hyprland, atau startup desktop mengubah tampilan terlalu dini.
- Repair script Caelestia berdampak tidak langsung pada jalur boot (belum ada bukti).

Semua poin di atas adalah HIPOTESIS, bukan akar masalah yang telah diverifikasi.

## Batas ownership Workstream 01 dan 02

- Workstream 01 memiliki Plymouth renderer, theme assets, installer tema, audit boot, serta kontrak handoff ke sesi desktop.
- Workstream 02 memiliki visual Lock Screen, Caelestia/Quickshell IPC, lock invocation, dan penerbitan readiness marker.
- Ketergantungan handoff terhadap readiness marker tidak memindahkan ownership implementasi Lock Screen ke Workstream 01.
- Jangan menghidupkan kembali Quickshell boot splash legacy. Plymouth tetap satu-satunya renderer boot splash.

## Aturan selama PAUSED

- Jangan jalankan installer Workstream 01.
- Jangan rebuild initramfs/UKI atau mengubah kernel command line, mkinitcpio hooks, systemd units, getty, autologin, TPM, LUKS, atau bootloader untuk eksperimen.
- Jangan mengubah repair script Caelestia atau desktop startup sebagai workaround Plymouth tanpa bukti.
- Pemeriksaan berikutnya harus read-only: telaah source helper dan unit aktual, status service, journal boot saat ini/sebelumnya, isi UKI/theme relevan, dan error renderer.
- Pertahankan passphrase LUKS dan recovery path. Jangan reboot setelah perubahan boot yang belum diverifikasi.
- Jika perubahan diperlukan, tetapkan hipotesis terukur, backup, rollback, dan acceptance criteria; minta persetujuan sebelum tindakan sistem berisiko.

## Rencana untuk membuka kembali Workstream 01

1. Review implementasi aktual k41-plymouth-release.service, k41-plymouth-quit-after-lock.sh, k41-start-hyprland.sh, dan unit terkait.
2. Petakan urutan Plymouth → framebuffer/VT → getty/Hyprland berdasarkan bukti aktual.
3. Periksa error theme/renderer dan isi UKI tanpa mengubah sistem.
4. Nyatakan akar masalah atau batas ketidakpastian secara eksplisit.
5. Ajukan perubahan minimum dengan backup/rollback, tes, dan persetujuan sebelum diterapkan.
6. Uji runtime visual pada ThinkPad X280 dan minta konfirmasi pengguna.

## Validasi dan acceptance

- Static tests historis hanya membuktikan kontrak/sintaks sesuai cakupannya; bukan bukti visual saat boot.
- Audit perangkat 2026-11-12 adalah read-only dan tidak mengubah konfigurasi boot.
- Runtime acceptance tema/UKI dan tampilan boot: **NOT VERIFIED**.
- Status Workstream 01: **PAUSED — INVESTIGATION PENDING**.

## Referensi upstream

- ArchWiki Plymouth: https://wiki.archlinux.org/title/Plymouth
- Arch manual plymouth-set-default-theme: https://man.archlinux.org/man/plymouth-set-default-theme.1.en
- Arch manual mkinitcpio: https://man.archlinux.org/man/mkinitcpio.8
