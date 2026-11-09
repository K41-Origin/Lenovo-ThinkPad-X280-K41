# Instalasi Arch Linux

Dokumen ini mengatur tahap 1–3. Ikuti entry point kanonis; jangan menjalankan script implementasi lama secara terpisah jika sudah menggunakan wrapper.

## Tahap 1 — Arch Linux Live ISO: readiness

Boot ISO resmi Arch Linux pada ThinkPad X280 dalam mode UEFI, siapkan koneksi jaringan dan checkout repository pada filesystem live. Jalankan:

```bash
bash scripts/k41-live-validation.sh
```

Tanpa argumen, script menjalankan mode `--readiness`. Ini satu-satunya entry point yang perlu dijalankan untuk validasi kesiapan instalasi dasar. Baca laporan di `reports/live-readiness/` dan `reports/live-validation/`. PASS hanya menyatakan snapshot kesiapan pada checkout/host tersebut; bukan izin otomatis menghapus disk.

`scripts/bootstrap-archiso.sh` adalah orkestrator opsional yang melakukan review source, readiness, lalu meminta otorisasi untuk meluncurkan installer. Script ini bukan bagian dari urutan standar tujuh tahap. Jika mengikuti tahap 1 dan 2 secara manual seperti di atas, jangan jalankan bootstrap karena readiness akan diperiksa lagi dan installer dapat diluncurkan dari dalamnya.

## Tahap 2 — Arch Linux Live ISO: basic installation

Setelah readiness PASS dan laporan direview, jalankan:

```bash
bash scripts/k41-install-basic-arch.sh
```

Wrapper meneruskan ke implementasi `scripts/install-arch-x280.sh`. Proses ini destruktif dan mengganti isi SSD internal target. Sebelum konfirmasi:
- pastikan backup dan recovery media tersedia;
- identifikasi SSD berdasarkan model, kapasitas, identitas stabil, transport, mount, dan swap;
- review rencana partisi/enkripsi yang ditampilkan installer;
- pastikan target benar-benar SSD yang boleh dihapus.

Jangan menebak device path atau mengulang installer secara membabi buta setelah kegagalan operasi disk. Safety gate mengurangi risiko, bukan menghilangkan semua kemungkinan race.

Desain saat ini: UEFI/GPT, ESP, LUKS2, ext4, swapfile, systemd-boot dengan UKI. Ikuti rencana aktual yang ditampilkan oleh implementasi.

## Tahap 3 — Basic Arch Linux: desktop installation

Setelah installer selesai, reboot dan masuk ke TTY sistem Arch Linux yang baru terpasang. Login sebagai user biasa yang berada di grup `wheel`, lalu jalankan:

```bash
sudo bash scripts/k41-install-desktop.sh
```

Wrapper meneruskan ke `scripts/setup-desktop-x280.sh`. Script harus dijalankan dari TTY, bukan dari Arch ISO, chroot, atau sesi grafis. Ikuti prompt instalasi dan review AUR recipe saat diminta.

**Tidak ada first-boot validation wajib di antara tahap 2 dan 3.** First-boot collector `scripts/x280-first-boot-check.sh` tetap tersedia sebagai alat diagnosis read-only bila diperlukan, tetapi bukan prasyarat workflow dan bukan gerbang untuk menjalankan desktop installer.

Exit 0 dari desktop installer hanya berarti proses setup selesai; bukan bukti desktop berfungsi. Tahap berikutnya adalah tahap 4 pada [dokumen desktop](03-DESKTOP.md).

## Batas keselamatan

Tidak ada operasi wipe/partition/format/LUKS/disk write tanpa persetujuan eksplisit dan identifikasi target yang terverifikasi. Jangan menonaktifkan verifikasi tanda tangan paket. Jangan pipe script remote langsung ke shell. Review log sebelum dibagikan; laporan dapat memuat detail lingkungan.
