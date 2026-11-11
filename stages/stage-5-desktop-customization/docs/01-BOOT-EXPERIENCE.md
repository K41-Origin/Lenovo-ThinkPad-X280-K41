# Workstream 01 — Boot Experience

**Status: REOPENED — AUDIT REQUIRED (2026-11-11).**

Status sebelumnya **COMPLETED / USER ACCEPTED (2026-11-10)** dicatat sebagai histori penerimaan desain/pekerjaan terdahulu. Status tersebut tidak lagi berarti implementasi boot saat ini memenuhi kebutuhan baru. Workstream dibuka kembali karena fokus sekarang adalah memperbaiki jalur boot dan menetapkan **Plymouth sebagai satu-satunya renderer splash/animasi boot — 100% tanpa QML/Quickshell**.

Status runtime ThinkPad X280 belum diverifikasi oleh audit terbaru. Jangan menganggap konfigurasi pada laporan lama masih aktif.

## Keputusan arsitektur

### Keputusan wajib

1. **Plymouth adalah satu-satunya renderer visual selama boot.**
2. Tidak ada QML, Quickshell, qs, Caelestia, Hyprland, atau compositor yang digunakan untuk menggambar boot splash.
3. Tidak ada Quickshell boot splash, overlay transisi, atau fallback visual.
4. Tema K41 diimplementasikan sebagai tema Plymouth (script plugin) dan menjadi sumber visual boot tunggal.
5. Plymouth menangani tampilan prompt passphrase LUKS bila integrasi initramfs/systemd dan paket yang terpasang mendukungnya.
6. Setelah boot mencapai sesi grafis, Plymouth dihentikan melalui mekanisme systemd/Plymouth yang diverifikasi; desktop lock screen adalah komponen terpisah, bukan bagian dari boot splash.
7. Reboot/shutdown memakai lifecycle Plymouth/systemd upstream. Jangan membuat unit tandingan tanpa bukti kebutuhan dan verifikasi ordering.

### Model alur yang dituju

UEFI → bootloader/UKI (jika terpasang) → kernel + initramfs → Plymouth K41 → systemd/userspace → TTY/login → Hyprland/Caelestia

Alur ini adalah model target, bukan pernyataan bahwa laptop saat ini menggunakan setiap komponen tersebut. Bootloader, UKI, filesystem EFI, initramfs generator, LUKS mapping, dan TPM2 harus dibuktikan oleh laporan audit sebelum prosedur implementasi dipilih.

### Pemisahan tanggung jawab

| Komponen | Tanggung jawab | Bukan tanggung jawab |
|---|---|---|
| Firmware + bootloader | Menemukan dan memuat entry boot | Menggambar UI QML |
| Kernel + initramfs | Menginisialisasi sistem awal dan membuka root terenkripsi | Menjalankan desktop shell |
| Plymouth K41 | Satu-satunya boot splash, animasi, pesan/prompt yang didukung | Menjalankan Quickshell |
| systemd | Mengatur lifecycle service/target dan transisi Plymouth | Menggambar overlay K41 tambahan |
| TTY/login + Hyprland | Memulai sesi grafis setelah boot userspace | Menjadi bagian dari boot splash |
| Caelestia lock screen | Mengunci sesi desktop sesuai konfigurasi terpisah | Mengendalikan renderer boot |

## Identitas visual Plymouth K41

Baseline visual yang dipertahankan:
- Background hitam.
- Wordmark putih K41.
- Ring ringkas berisi 12 glyph persegi panjang kecil.
- Satu glyph menyala bergantian, glyph lain redup.
- Tidak mengubah bentuk, jumlah, proporsi, atau pola animasi tanpa keputusan desain baru.

Source visual kanonis:
- workstreams/01-boot-experience/themes/plymouth/k41/k41.plymouth
- workstreams/01-boot-experience/themes/plymouth/k41/k41.script

**Tidak ada source QML untuk boot splash dalam arsitektur target.** File QML dan installer Quickshell lama yang ditemukan dalam audit diperlakukan sebagai legacy/conflicting implementation; keduanya tidak boleh menjadi dependency, dipanggil oleh installer, atau dimasukkan ke alur boot target. Artefak QML/installer boot splash legacy telah dihapus dari branch aktif setelah referensi installer dan test dimigrasikan; Git history tetap menyimpan histori.

## Hasil audit repository (11 November 2026)

Audit statis awal pada branch main menemukan:
- Installer k41-configure-boot-experience.sh memanggil k41-install-animated-boot-splash.sh, mensyaratkan qs, dan menyiapkan QML overlay. Ini bertentangan dengan keputusan Plymouth-only.
- Terdapat QML config/quickshell/k41-boot-splash/shell.qml dan installer Quickshell boot splash.
- Helper lock masih mengelola PID splash Quickshell.
- Test test-animated-boot-splash.sh dan test-plymouth-k41-theme.sh secara eksplisit mewajibkan QML/Quickshell.
- Installer konfigurasi boot juga mengubah mkinitcpio hooks, kernel cmdline, theme, UKI, systemd units, getty autologin, dan menawarkan TPM2 enrollment. Ini terlalu banyak side effect dalam satu alur dan berisiko untuk dijalankan sebelum audit kondisi perangkat.
- Installer tema Plymouth mensyaratkan path /efi, preset linux.preset, dan UKI /efi/EFI/Linux/arch-linux.efi; asumsi ini harus dicocokkan dengan hasil audit aktual.
- Test yang ada dominan static string assertions; test tersebut tidak membuktikan firmware boot, prompt LUKS, timing Plymouth, TPM unlock, atau transisi desktop.
- Status implementasi aktual di laptop **BELUM DIVERIFIKASI**.

Temuan ini adalah audit source repository, bukan hasil pemeriksaan laptop.

## Audit perangkat

Jalankan collector read-only dari checkout repository pada ThinkPad X280:

    bash stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh

Output lokal:
reports/stage-5-desktop-customization/01-boot-experience/audits/<UTC timestamp>/

Collector menginventarisasi firmware/UEFI, Secure Boot status yang dapat dibaca, bootloader/entry, mount EFI, disk/filesystem, root mapping, ringkasan metadata LUKS tanpa key material, kernel cmdline (field sensitif disamarkan), mkinitcpio/preset, isi initramfs yang relevan, versi paket, tema Plymouth, unit systemd, TPM device discovery, file konfigurasi boot, serta journal boot terfilter.

Collector read-only terhadap konfigurasi sistem. Output tetap perlu ditinjau dan disamarkan sebelum dibagikan karena dapat memuat identifier perangkat, UUID, label disk, firmware detail, path, dan log. Jangan pernah membagikan passphrase, recovery key, LUKS key material, token, atau credential.

## Perubahan repository yang sudah dilakukan\n\n- Installer konfigurasi boot tidak lagi mensyaratkan Quickshell atau memanggil installer QML splash.\n- Helper lock tidak lagi mengelola PID Quickshell overlay; marker lock menjadi handoff untuk lifecycle Plymouth/systemd.\n- Source QML dan installer boot splash Quickshell legacy dihapus dari branch aktif.\n- Test Plymouth-only baru ditambahkan ke manifest global, bersama test static safety untuk audit collector.\n- Perubahan ini adalah IMPLEMENTED di repository; belum membuktikan kondisi boot pada laptop.\n\n## Urutan kerja yang disepakati

1. **Audit repository (read-only):** seluruh script, theme, tests, docs, CI, dan referensi silang Workstream 01.
2. **Audit perangkat (read-only):** kumpulkan laporan menggunakan audit script; tidak mengubah konfigurasi.
3. **Review hasil audit:** cocokkan arsitektur aktual dengan keputusan Plymouth-only dan tentukan perubahan spesifik.
4. **Rencana implementasi:** pecah perubahan menjadi theme/initramfs integration, boot config, systemd lifecycle, login/desktop handoff, recovery, dan test. Pisahkan TPM/LUKS dari pekerjaan visual.
5. **Implementasi bertahap:** perubahan kecil, backup, preflight, rollback, dan privileged action minimal. Jangan menjalankan installer gabungan yang belum direfaktor.
6. **Verifikasi:** Bash syntax, ShellCheck, unit/config verification, initramfs/UKI inspection, static tests, lalu pengujian boot fisik dan recovery pada X280.
7. **Acceptance:** hanya setelah hasil aktual direview dan diterima pengguna. Runtime VERIFIED memerlukan bukti perangkat; pull/push Git saja tidak menjalankan script atau membuktikan perilaku boot.

Pengguna hanya melakukan sinkronisasi git pull dan git push sesuai alur kolaborasi. Jangan meminta edit manual atau menjalankan perintah ad hoc di luar proses yang disepakati. Jika pengumpulan laporan tidak dapat dieksekusi melalui jalur yang disetujui, status harus dinyatakan BLOCKED/NOT VERIFIED, bukan diasumsikan berhasil.

## Batas keamanan

- Jangan mengubah partisi, filesystem, firmware, boot entry, LUKS header/keyslot, TPM enrollment, Secure Boot, atau PCR policy tanpa audit dan persetujuan eksplisit untuk tindakan tersebut.
- Jangan menghapus atau mengganti passphrase LUKS yang sudah ada.
- Jangan menganggap TPM2 token ada/berfungsi hanya dari source script.
- Jangan menjalankan mkinitcpio -P sebelum memastikan konfigurasi aktif, target EFI ter-mount, preset/UKI yang benar, dan recovery path.
- Jangan membuat perubahan systemd/getty autologin sebagai bagian dari audit.
- Jangan melakukan reboot sebagai test otomatis.
- Jangan mengklaim boot/recovery verified dari syntax check atau fixture.
- Plymouth-only adalah keputusan renderer boot; tidak mengubah pilihan desktop lock screen atau autentikasi setelah boot.

## Artefak pemilik

- Audit collector: workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh
- Plymouth theme: workstreams/01-boot-experience/themes/plymouth/k41/
- Installer lama yang wajib direview sebelum refactor: workstreams/01-boot-experience/scripts/
- Test pemilik: stages/stage-5-desktop-customization/tests/test-boot-experience.sh dan test-plymouth-k41-theme.sh
- Status tunggal: [docs/06-STATUS.md](../../../docs/06-STATUS.md)
