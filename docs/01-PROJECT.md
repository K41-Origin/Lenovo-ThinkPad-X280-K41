# Proyek dan Arsitektur

## Tujuan

Membangun instalasi Arch Linux yang modular, aman, reproducible, dan testable untuk ThinkPad X280. Desktop menggunakan Hyprland, Quickshell, dan Caelestia Shell sesuai dependensi upstream. Integrasi BlackArch bersifat opsional dan selektif; bukan tahap wajib.

## Alur resmi — tujuh tahap

1. **Arch Linux Live ISO — Readiness Validation.** Satu script memeriksa apakah ISO, mode boot, perangkat X280, dependensi, repository, test suite, dan storage memenuhi prasyarat instalasi dasar.
2. **Arch Linux Live ISO — Basic Arch Installation.** Satu script menjalankan instalasi dasar Arch Linux pada SSD internal setelah pemeriksaan dan konfirmasi target.
3. **Basic Arch Linux — Desktop Installation.** Dari TTY sistem Arch yang sudah terpasang, jalankan desktop installer. First-boot diagnostic bukan gerbang wajib.
4. **Desktop Environment — Automated Functional Health Validation.** Kumpulkan bukti otomatis atas sesi, konfigurasi, proses, IPC, service, audio graph, jaringan, driver, baterai, thermal, dan journal. Gate ini tidak mengklaim penerimaan visual atau pengujian fisik perangkat.
5. **Desktop Environment Customization.** Setelah tahap 4 diterima, bentuk tampilan minimal, monoton/monochromatic, elegan, dan premium dengan keterbacaan serta performa terjaga.

Tahap 5 dikerjakan berurutan dalam tujuh workstream: (1) boot experience — power-on, reboot, dan poweroff; (2) lock screen; (3) dashboard; (4) taskbar/panel; (5) launcher; (6) sidebar; dan (7) utilities. Setiap workstream memerlukan audit kondisi aktif, implementasi bertahap, pemeriksaan fungsi/regresi, review visual langsung pada X280, serta bukti dan rollback. Cakupan lintas-komponen yang juga harus konsisten dijelaskan pada dokumen Desktop dan Design System.
6. **Desktop Environment Optimization.** Setelah customization diterima, optimalkan desktop dan perangkat: CPU, GPU, termal/fan, daya/baterai, suspend/hibernate/resume, dan stabilitas.
7. **Release.** Tandai rilis hanya setelah acceptance seluruh tahap, regression test, dokumentasi, dan bukti rilis lengkap.

Tidak ada perpindahan otomatis antar tahap. Hasil otomatis, klasifikasi WARN/FAIL, dan review bukti menjadi gate. Tahap 4 hanya menilai kondisi yang dapat diamati otomatis; visual dan interaksi fisik tidak termasuk dan tidak boleh diklaim VERIFIED. **Tahap 4 telah diterima dan ditutup** berdasarkan bukti pada `reports/desktop-validation/20261109T081724Z/`; Tahap 5 adalah tahap aktif.

### Status fitur lock screen dan Guest Mode

Workstream 2 (lock screen) memiliki override QML dan installer deployment yang telah **IMPLEMENTED** di branch `main`. Perubahan terbaru mencakup transparansi surface luar, pemeliharaan surface/kartu password terpisah, dan penataan kelompok jam/tanggal/password menggunakan parent area penuh serta `anchors.centerIn`. Implementasi tersebut belum boleh disebut **TESTED** atau **VERIFIED** pada ThinkPad X280: runtime QML, path source aktif setelah deployment, lock/unlock, wake, dan penerimaan visual masih harus dibuktikan. Rincian commit, file, perintah, serta batas validasi berada di [Workstream 2 — Lock Screen](08-STAGE-5/02-LOCK-SCREEN.md) dan [status proyek](06-STATUS.md).

**Guest Mode: NOT IMPLEMENTED.** Fitur ini belum memiliki implementasi. Pengerjaan maupun desain Guest Mode ditunda sampai pengguna secara eksplisit menerima custom lock screen. Penundaan ini bukan indikasi bahwa fitur sudah tersedia.

## Entry point kanonis

- `scripts/k41-live-validation.sh`
- `scripts/k41-install-basic-arch.sh` → delegasi ke `scripts/install-arch-x280.sh`
- `scripts/k41-install-desktop.sh` → delegasi ke `scripts/setup-desktop-x280.sh`
- `scripts/k41-desktop-validation.sh` → entry point validasi fungsional desktop tahap 4 (user biasa di sesi Hyprland)

Implementasi lama tetap dipertahankan sampai migrasi internal dilakukan secara terpisah. Jangan menggandakan logika di wrapper.

## Keputusan sistem

- Tahap instalasi desktop mempertahankan login manual dari TTY tanpa display manager/autologin. Setelah tahap 5 diterima, pengguna dapat secara eksplisit mengaktifkan TTY1 autologin + Caelestia lock screen melalui script terpisah; ini bukan default instalasi.
- NetworkManager untuk jaringan.
- Hindari power manager yang saling bersaing; audit service aktif sebelum perubahan.
- Review AUR recipe dan build sebagai user non-root.
- Jangan menganggap script exit 0, proses berjalan, atau file konfigurasi hadir sebagai bukti acceptance fungsional.

## Struktur

`scripts/` entry point dan workflow; `lib/` modul; `config/` konfigurasi target; `tests/` automated checks; `reports/` bukti; `docs/` panduan aktif dan arsip.

## Status

**PLANNED** belum dibuat; **IMPLEMENTED** tersedia; **TESTED** test dijalankan; **VERIFIED** perilaku dibuktikan sesuai gate; **RELEASED** masuk rilis; **NOT TESTED** belum diuji. Status berlaku hanya pada commit, lingkungan, dan bukti yang disebut.
