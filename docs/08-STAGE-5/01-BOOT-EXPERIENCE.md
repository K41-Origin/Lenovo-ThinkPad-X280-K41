# Workstream 1 — Boot Experience

**Cakupan:** power-on, reboot, dan poweroff pada ThinkPad X280.

## Tujuan

Membuat transisi visual yang konsisten dan terkendali pada tiga jalur boot/shutdown tanpa merusak bootability, autentikasi, enkripsi, atau recovery. Tujuan visual saat ini termasuk menghilangkan frame/logo/wallpaper Hyprland yang tidak diinginkan dan menggunakan identitas K41/Plymouth sejauh didukung lifecycle sistem.

## Batas

Termasuk firmware-to-userspace splash, kernel/KMS/initramfs/Plymouth, systemd transition, TTY/session startup dan shutdown handoff yang relevan.

Tidak termasuk perubahan desain global, redesign lock screen, perubahan autentikasi/PAM, pengubahan LUKS keyslot, penghapusan passphrase, enrollment TPM baru tanpa persetujuan, Secure Boot redesign, atau optimasi daya tahap 6.

## Kondisi dan risiko yang telah diketahui

Pada laporan pengguna 2026-11-09, visual Hyprland masih terlihat saat power-on, reboot, dan poweroff. Implementasi Plymouth K41 dan Quickshell overlay sudah ada, tetapi konsistensi visual perangkat belum tercapai. Temuan tersebut adalah baseline historis; audit ulang kondisi terkini sebelum tindakan.

## Prosedur

1. **Audit repository:** baca script boot, theme Plymouth, Quickshell splash, Hyprland config, test, dan laporan sebelumnya. Jangan menimpa implementasi yang sudah ada.
2. **Audit perangkat read-only:** kumpulkan bootloader/UKI/kernel command line, initramfs hooks, Plymouth theme dan unit, systemd unit links, session manager/TTY, proses Quickshell/Caelestia/Hyprland, journal boot dan shutdown, serta konfigurasi Hyprland yang benar-benar dimuat.
3. **Pisahkan tiga jalur:** buat timeline power-on, reboot, dan poweroff. Jangan menganggap satu penyebab menjelaskan semuanya.
4. **Bentuk hipotesis:** setiap hipotesis harus didukung artefak (unit ordering, journal timestamp, process lifetime, config aktif, atau reproduksi visual).
5. **Rencanakan perubahan:** satu perubahan kecil per iterasi. Sebelum mengubah boot parameters, initramfs, systemd units, atau UKI, jelaskan dampak, cara recovery, dan rollback.
6. **Implementasikan:** utamakan unit/hook resmi Arch/Plymouth dan mekanisme upstream. Hindari arbitrary sleep, competing custom units, dan perubahan yang hanya menyembunyikan gejala.
7. **Uji terpisah:** cold boot/power-on, reboot, dan poweroff. Lakukan beberapa iterasi bila perubahan menyangkut timing/transisi.
8. **Verifikasi recovery:** pastikan boot normal, passphrase LUKS tetap berfungsi sebagai recovery path, dan tidak ada perubahan autentikasi/keyslot yang tidak disetujui.

## Acceptance criteria

- Ketiga jalur diuji secara terpisah pada perangkat fisik.
- Tidak terlihat frame/logo/wallpaper Hyprland yang tidak diinginkan pada fase yang telah disepakati.
- Plymouth K41 tampil pada fase yang memang didukung dan dikonfigurasi.
- Handoff ke sesi/lock screen tidak memperlihatkan desktop yang seharusnya tersembunyi.
- Boot normal dan recovery LUKS tetap tersedia.
- Tidak ada unit gagal baru, loop boot, timeout, atau regression shutdown.
- Bukti mencatat perangkat, kernel/boot entry, konfigurasi, test, dan konfirmasi visual pengguna.

## Rollback dan keselamatan

Sebelum perubahan, simpan salinan konfigurasi, unit override, kernel command line, dan artefak boot yang relevan. Pastikan tersedia jalur masuk TTY/recovery. Jangan menghapus keyslot, mengubah TPM enrollment, atau menonaktifkan verifikasi signature untuk mengatasi masalah visual. Perubahan boot yang berisiko memerlukan persetujuan eksplisit setelah target dan prosedur recovery dijelaskan.

## Gate keluar

Workstream berstatus VERIFIED hanya setelah tiga jalur berhasil diuji dan bukti visual dikonfirmasi pengguna. Setelah diterima, lanjutkan ke [Workstream 2 — Lock Screen](02-LOCK-SCREEN.md).