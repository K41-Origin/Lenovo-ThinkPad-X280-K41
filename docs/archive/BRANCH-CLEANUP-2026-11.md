# Catatan Audit Pembersihan Branch — 2026-11-09

Dokumen ini menyimpan hanya keputusan dan pelajaran historis yang masih berguna. Ini bukan dokumentasi prosedur aktif; ikuti `docs/00-START-HERE.md` dan dokumen topik aktif.

## Hasil

Audit membandingkan 15 branch non-`main` terhadap `main`. Tidak ditemukan perubahan implementasi lama yang perlu diambil sebagai patch terpisah setelah membandingkan kelompok installer/EFI, first-boot, desktop/Caelestia, dan portal dengan implementasi aktif.

- `diagnostics/efi-mount-evidence`: collector `scripts/x280-first-boot-check.sh` memiliki blob SHA yang sama dengan `main`; tidak perlu disalin.
- `fix/secure-efi-mount-permissions`: `lib/base-system.sh`, `scripts/install-arch-x280.sh`, dan test installer/fstab yang diperiksa memiliki blob SHA yang sama dengan `main`; tidak perlu cherry-pick.
- `fix/first-boot-efi-permission-audit`: perubahan lama pada collector, test, dan panduan first-boot telah digantikan versi di `main`. Pelajaran yang masih relevan: collector yang disalin ke `/usr/local/sbin` adalah snapshot saat instalasi; gunakan salinan repository setelah source diperbarui. Penjelasan ini dipindahkan ke `docs/02-INSTALLATION.md`.
- `feature/x280-desktop-environment`, `fix/caelestia-aur-build-dependencies`, `fix/caelestia-materialyoucolor3`, `fix/caelestia-python-materialyoucolor`, `fix/desktop-setup-logging`, dan `fix/x280-desktop-portal-routing-pr`: iterasi implementasi desktop, dependensi AUR, logging, dan portal yang lebih lama. Implementasi aktif di `main` menjadi acuan; jangan memulihkan versi branch lama tanpa kebutuhan dan audit ulang.
- Branch dokumentasi `docs/*` berisi revisi panduan/status/changelog lama. Struktur dokumen aktif yang disederhanakan di `docs/00-START-HERE.md` sampai `docs/06-STATUS.md` menjadi acuan.
- `docs/reconcile-trial-policy-and-evidence` dan `fix/x280-desktop-portal-routing` sudah sepenuhnya tertinggal dari `main` pada saat audit.

## Keputusan

1. Tidak melakukan merge atau cherry-pick dari branch non-`main` berdasarkan audit ini.
2. Tidak membuat salinan branch atau arsip source code duplikat.
3. Simpan hanya catatan audit ini dan koreksi operasional first-boot di dokumen instalasi.
4. Setelah pemilik repository meninjau hasil ini, branch non-`main` dapat dihapus. Branch tidak dihapus oleh proses ini.

## Batas audit

Perbandingan branch mengidentifikasi commit dan file yang berbeda; pemeriksaan isi dilakukan pada file implementasi yang relevan untuk menentukan apakah perubahan telah digantikan. Catatan ini bukan jaminan bahwa setiap baris dari seluruh histori branch telah dipertahankan. Jika kelak diperlukan pemulihan detail historis, lakukan pemeriksaan ulang terhadap commit yang masih dapat diakses sebelum mengambil keputusan.
