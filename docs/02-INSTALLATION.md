# Instalasi Arch Linux

## Workflow
OS installer dijalankan dari Arch ISO dan destruktif terhadap SSD. Desktop setup dijalankan setelah Arch boot. `./installer --preflight` hanya diagnostik read-only.

## Prosedur aman
1. Siapkan backup dan recovery media.
2. Ambil source, catat SHA, review script.
3. Boot Arch ISO pada X280 dalam mode UEFI.
4. Jalankan `bash scripts/k41-live-validation.sh --readiness`.
5. Review readiness dan identitas/topologi disk.
6. Cocokkan SSD internal berdasarkan model, kapasitas, identitas stabil, mount, dan swap.
7. Hanya setelah review dan otorisasi eksplisit, ikuti acknowledgement gate installer.
8. Simpan log ke media persisten sebelum reboot.

Jangan menebak device path. Identifikasi ulang target setiap sesi.

## Desain dan batas
Desain terdokumentasi: UEFI/GPT, ESP, LUKS2, ext4, swapfile, systemd-boot UKI. Ikuti rencana runtime aktual. Target adalah penggantian penuh SSD internal; dual boot/partisi Windows tidak dipertahankan. Safety gate fail-closed mengurangi risiko, bukan bukti semua race mustahil.

Tidak ada wipe/partition/format/LUKS/disk write tanpa persetujuan eksplisit. Setelah kegagalan operasi disk, inspeksi keadaan aktual; jangan rerun membabi buta. UKI terbentuk bukan bukti firmware boot. Instalasi penuh tidak diuji di VM; acceptance dilakukan pada X280 fisik setelah gate dan otorisasi.

## First Boot
Setelah boot dan login user, jalankan `sudo /usr/local/sbin/x280-first-boot-check`. Collector read-only membuat laporan bertimestamp. Review data sensitif sebelum share. First Boot PASS bukan acceptance desktop/Bluetooth/suspend/stability.
