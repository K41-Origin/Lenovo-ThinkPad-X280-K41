# Workstream 1 — Boot Experience

**Cakupan:** power-on, reboot, dan poweroff pada ThinkPad X280.

## Tujuan

Mewujudkan pengalaman visual K41 yang konsisten pada cold boot/power-on, reboot, dan poweroff. Tampilan normal yang diinginkan adalah splash K41 monokrom tanpa prompt password, logo/wallpaper/frame Hyprland, atau tampilan desktop yang bocor selama transisi.

Pada jalur normal, root LUKS dibuka otomatis melalui TPM2. Passphrase LUKS tetap dipertahankan sebagai jalur recovery apabila TPM2 auto-unlock gagal atau kebijakan PCR tidak cocok. Prompt recovery bukan bagian dari desain visual normal dan tidak boleh dihapus dengan mengorbankan keamanan atau kemampuan pemulihan.

## Arsitektur dan tanggung jawab

| Komponen | Tanggung jawab |
|---|---|
| UEFI firmware, systemd-boot, UKI | Memulai sistem dan memuat kernel/initramfs |
| TPM2 + systemd-cryptenroll | Membuka root LUKS secara otomatis pada kondisi PCR yang cocok |
| Plymouth K41 | Splash early boot serta transisi reboot/poweroff sejauh didukung lifecycle systemd |
| systemd | Mengatur urutan startup, shutdown, reboot, dan unit transisi |
| TTY1, Hyprland, Quickshell/Caelestia | Handoff dari splash boot ke sesi grafis dan lock screen |
| K41 Hyprland launcher | Menjalankan `start-hyprland` dengan stdin/TTY tetap terhubung, tetapi mengalihkan stdout/stderr ke log privat agar teks startup tidak tercetak pada TTY1 |
| Quickshell K41 | Menjaga tampilan K41 selama handoff grafis sampai lock screen siap |

Plymouth dan Quickshell adalah renderer berbeda. Keduanya mengikuti spesifikasi visual yang sama, tetapi kesamaan piksel tidak dijamin.

## Batas

Termasuk firmware-to-userspace splash, kernel/KMS/initramfs/Plymouth, systemd transition, TPM2 auto-unlock, TTY/session startup, lock-screen handoff, serta jalur reboot dan poweroff.

Tidak termasuk redesign lock screen, perubahan autentikasi/PAM, penghapusan passphrase/keyslot LUKS, penghapusan token TPM tanpa rencana recovery, Secure Boot redesign, atau optimasi daya tahap 6.

## Prosedur kerja dan pengujian nyata

Pengujian utama dilakukan pada ThinkPad X280 fisik. Static test dan inspeksi konfigurasi adalah pemeriksaan pendukung, bukan pengganti boot/reboot/poweroff nyata.

1. **Audit repository:** baca script konfigurasi boot, installer Plymouth, theme, Quickshell splash, unit terkait, tests, dan laporan terbaru. Jangan mengasumsikan riwayat percakapan menggambarkan state repository terkini.
2. **Audit perangkat sebelum perubahan:** catat bootloader/UKI, kernel command line, mkinitcpio hooks, mount `/efi`, tema Plymouth, unit transition, status LUKS2/TPM2, status Secure Boot, TTY1/autologin, konfigurasi sesi, dan jalur recovery yang tersedia.
3. **Siapkan recovery:** pastikan passphrase LUKS yang sekarang masih valid dan tersedia secara offline; pastikan dapat mengakses firmware/systemd-boot recovery atau Arch ISO bila boot gagal. Jangan menghapus atau mengganti keyslot passphrase.
4. **Jalankan konfigurasi aktual:** setelah prasyarat dan backup ditinjau, jalankan `sudo bash scripts/k41-configure-boot-experience.sh` pada sistem target. Script ini bukan preview: script menginstal Plymouth, memilih tema K41, mengubah hook mkinitcpio dan kernel command line, membangun ulang initramfs/UKI, memasang konfigurasi handoff TTY1/Plymouth, lalu menawarkan enrollment TPM2 PCR 7 secara interaktif.
5. **Perlakukan enrollment TPM2 sebagai perubahan keamanan:** script meminta persetujuan terpisah sebelum menjalankan `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7`. Enrollment menambahkan metode unlock; tidak menghapus passphrase. Pastikan token TPM2 tercatat di metadata LUKS setelah enrollment. PCR 7 tidak boleh dianggap sebagai Secure Boot verification ketika Secure Boot disabled.
6. **Jangan reboot bila rebuild UKI gagal atau status enrollment tidak jelas.** Simpan lokasi backup konfigurasi yang dicetak script dan periksa artefak UKI yang dihasilkan.
7. **Uji cold boot/power-on secara fisik:** amati apakah K41 muncul, apakah TPM2 membuka root tanpa prompt, apakah ada frame/logo/wallpaper yang bocor, dan apakah transisi menuju Caelestia lock screen benar.
8. **Uji reboot secara terpisah:** amati urutan shutdown, Plymouth reboot transition, tidak adanya frame Hyprland, dan keberhasilan boot berikutnya.
9. **Uji poweroff secara terpisah:** amati Plymouth poweroff transition dan pastikan sistem benar-benar mati tanpa tampilan desktop yang tidak diinginkan.
10. **Uji recovery secara terkendali bila diperlukan:** jika TPM2 tidak dapat membuka root, passphrase LUKS harus tetap dapat digunakan. Jangan sengaja mengubah PCR, firmware, Secure Boot, atau keyslot hanya untuk memancing kegagalan tanpa rencana recovery yang disetujui.
11. **Kumpulkan bukti:** catat hasil visual yang dikonfirmasi pengguna, boot entry/kernel, status token TPM2 tanpa membocorkan rahasia, unit gagal, journal boot/shutdown, serta hasil test statis.

## Kontrak script konfigurasi aktual

`scripts/k41-configure-boot-experience.sh` memiliki efek sistem yang nyata:

- Memerlukan UEFI, root `/dev/mapper/cryptroot`, volume LUKS2, TPM2 `/dev/tpmrm0`, mount `/efi`, konfigurasi mkinitcpio/UKI, dan sesi akun desktop yang sesuai.
- Menginstal paket Plymouth dari repository Arch yang terverifikasi oleh pacman.
- Menyalin theme K41 dan memilihnya sebagai tema default.
- Menambahkan hook Plymouth dengan urutan `systemd < plymouth < sd-encrypt`.
- Menambahkan kernel arguments `quiet splash`.
- Menjalankan `mkinitcpio -P` untuk membangun ulang preset/initramfs/UKI.
- Menjalankan `k41-install-animated-boot-splash.sh` untuk memasang Quickshell handoff, helper lock Caelestia, dan pengaturan suppress visual Hyprland. Konfigurasi `hyprland.lua` ikut dicadangkan sebelum installer dijalankan.
- Memasang helper handoff lock-aware, mengubah konfigurasi getty TTY1 dan drop-in Plymouth, lalu menjalankan `systemctl daemon-reload`, verifikasi unit, dan enable unit K41.
- Autologin menjalankan `~/.local/bin/k41-start-hyprland`, yang mempertahankan stdin/TTY tetapi mengalihkan stdout dan stderr `start-hyprland` ke `~/.local/state/k41/hyprland-startup.log` (direktori privat). Ini menekan teks startup yang terlihat di TTY tanpa membuang diagnostik. Log diputar saat mencapai 1 MiB.
- Menawarkan enrollment TPM2 PCR 7 setelah konfigurasi Plymouth selesai.
- Membuat backup konfigurasi lokal di `/var/lib/k41/boot-experience/backups/<timestamp>`.

**Batas backup:** script saat ini secara eksplisit tidak membuat backup LUKS header. Karena itu, sebelum menjalankannya, pastikan passphrase LUKS yang ada diketahui dan tervalidasi serta tersedia media/jalur recovery. Jangan menganggap backup konfigurasi sebagai backup LUKS header.

## Penanganan output terminal Hyprland

`start-hyprland` sebelumnya dijalankan langsung dari `.bash_profile`, sehingga output stdout/stderr dapat tertinggal pada buffer TTY1 dan terlihat kembali saat transisi compositor/shutdown. K41 launcher mengalihkan kedua stream ke file log privat, tanpa memutus stdin atau mengganti TTY. Ini menargetkan teks startup terminal; bukan pengganti pengaturan `misc.disable_hyprland_logo` atau `misc.disable_splash_rendering`, yang merupakan kontrol visual compositor terpisah.

Lokasi log: `~/.local/state/k41/hyprland-startup.log`. Log diputar menjadi `.1` ketika file aktif telah mencapai 1 MiB. Kegagalan launcher atau executable upstream dilaporkan ke stderr wrapper. Untuk instalasi autologin lama, migrasikan managed profile dengan `sudo bash scripts/k41-install-hyprland-launcher.sh`; script membuat backup `.bash_profile` dan launcher sebelumnya sebelum mengubahnya. Instalasi autologin baru memasang launcher secara otomatis melalui `k41-enable-caelestia-autologin.sh`.

## Hipotesis dan diagnosis visual

Pisahkan tiga timeline: power-on, reboot, dan poweroff. Untuk setiap kebocoran visual, cari bukti dari journal timestamp, unit ordering, proses Quickshell/Hyprland, konfigurasi yang benar-benar dimuat, dan perilaku display handoff. Jangan menganggap satu penyebab menjelaskan ketiganya.

Utamakan mekanisme upstream Arch/Plymouth/systemd. Hindari arbitrary sleep, unit kustom yang berkompetisi dengan unit paket, atau perubahan yang sekadar menyembunyikan gejala.

## Acceptance criteria

- Pada boot normal, TPM2 membuka root LUKS tanpa prompt passphrase ketika PCR state cocok.
- Passphrase LUKS tetap tersedia sebagai recovery bila TPM2 auto-unlock gagal.
- Desain K41 tampil pada fase early boot dan transisi reboot/shutdown yang didukung serta dikonfigurasi.
- Tidak ada wallpaper, logo, desktop, atau frame Hyprland yang terlihat pada fase yang telah disepakati.
- Handoff ke sesi grafis tidak menampilkan desktop sebelum Caelestia lock screen siap.
- Cold boot/power-on, reboot, dan poweroff diuji terpisah pada perangkat fisik.
- Tidak ada unit gagal baru, loop boot, timeout, boot regression, atau regression shutdown.
- Bukti mencatat perangkat, kernel/boot entry, konfigurasi, hasil test, dan konfirmasi visual pengguna.

## Catatan hasil perangkat — 2026-11-09

**BOOTING BERHASIL — dikonfirmasi pengguna.** Pengguna menyatakan bahwa ThinkPad X280 sudah berhasil boot.

Ruang lingkup konfirmasi ini sengaja dibatasi pada keberhasilan sistem melakukan startup. Tidak ada klaim tambahan bahwa TPM2 auto-unlock telah terverifikasi, tampilan splash K41 sudah sesuai desain, visual Hyprland tidak lagi bocor, atau reboot dan poweroff telah lulus. Keempat hal tersebut tetap memerlukan konfirmasi/pengujian terpisah. Isu desain visual yang belum sesuai tetap terbuka dan tidak dianggap selesai hanya karena sistem berhasil boot.

## Rollback dan keselamatan

Sebelum perubahan, simpan konfigurasi mkinitcpio, kernel command line, Plymouth config/theme, unit/drop-in, dan artefak boot yang relevan. Pastikan `/efi` benar-benar ter-mount. Simpan passphrase LUKS dan media recovery yang dapat diakses.

Jangan menghapus keyslot passphrase, menghapus token TPM, mengubah PCR policy, mengubah Secure Boot, atau mengubah firmware sebagai eksperimen tanpa rencana dan persetujuan eksplisit. Jika rebuild UKI gagal, jangan reboot sampai konfigurasi diperbaiki atau dipulihkan. Jika TPM2 enrollment gagal atau hasilnya tidak pasti, jangan menganggap auto-unlock telah aktif.

## Gate keluar

Workstream berstatus **VERIFIED** hanya setelah cold boot/power-on, reboot, dan poweroff berhasil diuji secara terpisah pada ThinkPad X280, normal TPM2 unlock dan recovery path dipahami, serta bukti visual dikonfirmasi pengguna. Setelah diterima, lanjutkan ke [Workstream 2 — Lock Screen](02-LOCK-SCREEN.md).

## Design baseline — K41 compact rectangle ring (approved 2026-11-09)

Desain visual yang disetujui adalah wordmark K41 putih minimalis di atas ring rapat berisi 12 glyph persegi panjang kecil, dengan satu glyph terang bergantian dan sebelas lainnya redup.

### Canonical Plymouth source

- **Referensi visual kanonis:** `themes/plymouth/k41/k41.script`.
- Background hitam.
- Wordmark `K41` terpusat, putih melalui `Image.Text("K41", 0.8, 0.8, 0.8)`.
- Dua belas glyph melalui `Image.Text("▯", 0.9, 0.9, 0.9)`.
- Ring radius `9`; offset vertikal ring `+10` relatif terhadap `center_y`.
- Posisi wordmark vertikal `center_y - 17 - logo_image.GetHeight()`.
- Opacity awal glyph `0.18`; glyph aktif `1.0`.
- Satu glyph aktif maju setiap refresh; sebelas lainnya tetap redup.

### Quickshell handoff counterpart

`config/quickshell/k41-boot-splash/shell.qml` mengikuti bahasa visual yang sama: background hitam, wordmark K41, ring 12 persegi panjang outline, dan satu elemen terang yang bergantian. Implementasi QML menggunakan rectangle dan rotasi native; Plymouth memakai glyph teks. Kesamaan piksel tidak dijanjikan.

### Change control

Jangan mengubah wordmark, geometri ring, jumlah rectangle, jarak relatif, palet monokrom, atau pola sequential glow tanpa persetujuan pengguna. Perubahan visual harus memperbarui Plymouth, Quickshell, dokumen ini, dan test terkait dalam satu rangkaian perubahan.

### Validation status

- **APPROVED DESIGN:** disetujui pengguna pada 2026-11-09.
- **IMPLEMENTED:** sumber desain Plymouth dan Quickshell tersedia di repository.
- **NOT VERIFIED:** rendering runtime, cold boot fisik, TPM2 auto-unlock pada boot aktual, reboot, poweroff, dan handoff lock-screen belum dinyatakan lulus berdasarkan bukti yang tersedia.
- **TESTING POLICY:** pengujian nyata pada perangkat fisik tetap menjadi acceptance utama; test statis tidak menggantikannya.