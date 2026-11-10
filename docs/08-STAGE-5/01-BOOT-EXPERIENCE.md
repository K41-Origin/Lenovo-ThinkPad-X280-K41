# Workstream 1 — Boot Experience

**Status: COMPLETED / USER ACCEPTED — 2026-11-10**

Pengguna secara eksplisit menyatakan Workstream 1 selesai. Keputusan ini adalah acceptance dan penutupan workstream. Status ini menjadi acuan aktif; catatan lama yang menyebut visual boot belum selesai merupakan histori sebelum keputusan penutupan.

Jangan membuka kembali pekerjaan ini hanya dengan mengutip laporan atau catatan historis. Jika pengguna melaporkan masalah baru, lakukan audit baru sebagai pekerjaan terpisah dan perbarui status setelah ada bukti.

## Cakupan

Pengalaman boot dan transisi sistem pada ThinkPad X280:
- Power-on/cold boot.
- Handoff dari firmware/kernel/initramfs ke sesi grafis.
- Reboot dan poweroff.
- Plymouth K41 dan Quickshell handoff.
- Transisi menuju Caelestia lock screen.

## Arsitektur yang digunakan

| Komponen | Tanggung jawab |
|---|---|
| UEFI, systemd-boot, UKI | Memulai sistem dan memuat kernel/initramfs |
| LUKS2 + passphrase | Enkripsi root dan jalur recovery |
| TPM2/systemd-cryptenroll | Metode unlock tambahan bila dikonfigurasi dan sesuai PCR |
| Plymouth K41 | Splash early boot dan transisi shutdown/reboot yang didukung |
| systemd | Lifecycle startup/shutdown dan unit transisi |
| TTY1/Hyprland | Memulai sesi grafis |
| K41 launcher | Menjaga TTY/stdin dan mengalihkan output startup ke log privat |
| Quickshell/Caelestia | Handoff shell dan lock screen |

Plymouth dan Quickshell adalah renderer berbeda. Keduanya mengikuti bahasa visual yang sama, bukan jaminan piksel identik.

## Design baseline yang disetujui

- Background hitam.
- Wordmark putih `K41`.
- Ring rapat berisi 12 glyph persegi panjang kecil.
- Satu glyph terang bergantian; glyph lain redup.
- Tidak mengubah bentuk, jumlah glyph, proporsi, atau pola sequential glow tanpa persetujuan pengguna.

Sumber desain:
- Plymouth: `stages/stage-5-desktop-customization/workstreams/01-boot-experience/themes/plymouth/k41/k41.script`.
- Quickshell: `stages/stage-5-desktop-customization/workstreams/01-boot-experience/config/quickshell/k41-boot-splash/shell.qml`.

Detail identitas visual lintas-komponen berada di [Design System](../07-DESKTOP-DESIGN-SYSTEM.md).

## Implementasi terkait

- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-configure-boot-experience.sh`
- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-install-plymouth-theme.sh`
- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-install-animated-boot-splash.sh`
- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-enable-caelestia-autologin.sh` (opt-in; bukan default instalasi)
- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-lock-caelestia-after-start.sh`
- `stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-start-hyprland.sh`
- `tests/test-boot-experience.sh`
- `tests/test-plymouth-k41-theme.sh`
- `tests/test-animated-boot-splash.sh`

Daftar ini menunjukkan pemetaan implementasi repository, bukan instruksi untuk menjalankan ulang installer. Periksa script dan kondisi perangkat sebelum tindakan operasional.

## Batas keamanan dan recovery

- Jangan menghapus passphrase/keyslot LUKS.
- TPM2 enrollment bersifat additive; jangan mengklaim auto-unlock aktif tanpa verifikasi pada perangkat.
- PCR 7 bukan bukti Secure Boot verification jika Secure Boot tidak aktif.
- Pastikan passphrase dan recovery path tetap tersedia sebelum perubahan boot.
- Jika rebuild UKI gagal, jangan reboot sampai konfigurasi dan artefak boot dipulihkan/diperiksa.
- Jangan menambah arbitrary delay atau unit yang bersaing dengan lifecycle upstream.

## Catatan status

**COMPLETED / USER ACCEPTED** adalah keputusan proyek dari pengguna. Status ini tidak boleh diperluas menjadi klaim bahwa setiap parameter firmware, TPM2 token, Secure Boot, atau kondisi recovery telah diukur ulang pada tanggal penutupan. Catatan teknis yang lebih lama dipertahankan dalam Git history dan arsip; bukan backlog aktif.

Tidak ada screenshot yang digunakan atau diperlukan untuk acceptance.
