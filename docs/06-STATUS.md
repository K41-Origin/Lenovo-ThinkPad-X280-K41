# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan konfirmasi pengguna yang tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer; penerimaan boot fisik dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | **COMPLETED** | Laporan terbaru 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. WARN ditinjau dan risiko residual didokumentasikan. Pengguna mengonfirmasi pairing Bluetooth berhasil. Batas visual/fisik tetap eksplisit di luar gate. |
| 5. Desktop Customization | **IN PROGRESS** | Profil visual Caelestia/Hyprland telah diterapkan. Pengguna mengonfirmasi script konfigurasi boot experience selesai dijalankan tanpa melaporkan error. Hasil reboot, TPM auto-unlock, dan handoff visual ke lock screen belum dikonfirmasi. Quickshell K41 memakai desain ring 12 titik yang disamakan dengan Plymouth; installer mengatur opsi visual Hyprland untuk handoff. Namun pengguna mengonfirmasi tampilan Hyprland masih bocor pada power-on, reboot, dan poweroff. Tema Plymouth K41 serta pemeriksaan unit reboot/poweroff/halt telah diimplementasikan, tetapi konsistensi visual perangkat BELUM TERCAPAI. Investigasi kebocoran ditunda ke sesi berikutnya. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5 dan baseline terukur. |
| 7. Release | PLANNED | Menunggu seluruh acceptance gate, regression, dokumentasi, dan bukti final. |

## Entry point kanonis

| Script | Fungsi | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | Live ISO readiness | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | Basic Arch installation | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | Desktop installation | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Read-only desktop health validation | IMPLEMENTED |
| `scripts/k41-desktop-repair.sh` | Scoped repair and evidence collection | IMPLEMENTED |
| `scripts/k41-enable-caelestia-autologin.sh` + `scripts/k41-lock-caelestia-after-start.sh` | Opt-in tty1 autologin + verified Caelestia lock startup + Hyprlock fallback | IMPLEMENTED — NOT TESTED ON DEVICE |
| `scripts/audit-x280-boot.sh` | Read-only boot/UKI/LUKS/TPM2/Plymouth state collector | IMPLEMENTED — REPORT COLLECTED |
| `scripts/k41-configure-boot-experience.sh` + `scripts/k41-plymouth-quit-after-lock.sh` | Plymouth K41 theme, quiet splash, lock-aware TTY1 handoff, additive TPM2/PCR7 enrollment | IMPLEMENTED — ORIGINAL SCRIPT RUN CONFIRMED |
| `tests/test-boot-experience.sh` | Static syntax and safety-invariant test for boot setup | IMPLEMENTED — NOT RUN IN THIS SESSION |
| `scripts/k41-install-plymouth-theme.sh` + `themes/plymouth/k41/` | Install native K41 theme, verify Arch reboot/poweroff/halt units, rebuild initramfs/UKI | IMPLEMENTED — DEVICE TEST PENDING |
| `tests/test-plymouth-k41-theme.sh` | Static checks for Plymouth theme and installer | IMPLEMENTED — NOT RUN IN THIS SESSION |
| `scripts/k41-install-animated-boot-splash.sh` + `config/quickshell/k41-boot-splash/shell.qml` | Animated K41 Quickshell overlay and Hyprland visual configuration | IMPLEMENTED — KNOWN VISUAL LEAK ON DEVICE |
| `tests/test-animated-boot-splash.sh` | Static syntax and safety-invariant test for animated handoff | IMPLEMENTED — NOT RUN IN THIS SESSION |

## Prioritas saat ini

**CURRENT — Tahap 5: dokumentasi boot experience selesai; perbaikan visual ditunda.**

### Status faktual visual boot

Pengguna mengonfirmasi pada 2026-11-09 bahwa tampilan Hyprland masih terlihat/bocor pada ketiga kondisi:
- **Power-on:** tampilan Hyprland muncul selama transisi startup.
- **Reboot:** tampilan Hyprland muncul selama transisi restart.
- **Poweroff:** tampilan Hyprland masih terlihat selama proses shutdown.

Ini adalah hasil pengujian visual langsung yang dilaporkan pengguna. Karena itu, jangan menyatakan tampilan boot/reboot/shutdown sudah konsisten atau bebas flicker. Pengaturan Hyprland dan overlay Quickshell yang telah ditambahkan baru berstatus IMPLEMENTED; efektivitasnya belum menyelesaikan masalah di perangkat.

### Pekerjaan yang sudah diimplementasikan

- Tema native Plymouth K41: background hitam, wordmark K41, spinner 12 titik, dan callback prompt password.
- Quickshell memakai wordmark dan spinner 12 titik dengan gaya yang disamakan ke Plymouth.
- Installer Quickshell mengatur opsi visual Hyprland untuk menonaktifkan logo/splash, wallpaper default, dan memakai background hitam selama handoff.
- Installer Plymouth memeriksa unit transisi reboot, poweroff, dan halt yang disediakan paket Arch.
- Dokumentasi sekarang mencatat keterbatasan aktual dan pekerjaan yang belum selesai.

### Pekerjaan berikutnya — PLANNED, belum dikerjakan

Lakukan audit terpisah untuk tiga jalur visual, tanpa mengasumsikan satu penyebab:
1. **Power-on:** urutan firmware → kernel/KMS → initramfs/Plymouth → systemd → getty/Hyprland → Quickshell → Caelestia.
2. **Reboot:** urutan shutdown target, Plymouth reboot unit, compositor/session exit, dan display handoff.
3. **Poweroff:** urutan shutdown target, Plymouth poweroff unit, compositor/session exit, dan display handoff.

Kumpulkan bukti konfigurasi dan journal sebelum mengubah service, hook, kernel parameter, atau timing. Periksa konfigurasi Hyprland yang benar-benar dimuat, proses Quickshell, layer-shell stacking, unit Plymouth yang aktif/tertaut, serta isi UKI dan kernel command line. Jangan menambahkan delay buatan atau unit kustom yang berkompetisi dengan unit paket tanpa diagnosis.

### Acceptance criteria berikutnya

- Tidak ada wallpaper, logo, desktop, atau frame Hyprland yang terlihat saat power-on, reboot, maupun poweroff.
- Animasi K41 Plymouth digunakan pada fase early boot dan transisi reboot/shutdown sejauh didukung lifecycle systemd.
- Handoff ke Quickshell/Caelestia tidak menampilkan desktop Hyprland.
- Caelestia Lock Screen tetap terverifikasi terkunci sebelum splash Quickshell ditutup.
- Passphrase LUKS tetap menjadi recovery path; tidak ada perubahan keyslot/TPM tanpa kebutuhan dan persetujuan eksplisit.

Status target visual keseluruhan: **NOT VERIFIED / KNOWN ISSUE**. Pekerjaan perbaikan ditunda sesuai keputusan pengguna dan akan dilanjutkan pada sesi berikutnya.

Jangan menghapus keyslot passphrase. Secure Boot masih disabled pada snapshot audit; PCR 7 saja bukan bukti verifikasi boot penuh. Jangan mencampur pekerjaan tahap 5 dengan optimasi daya/termal tahap 6.

## Bukti tahap 4

- Validasi: `reports/desktop-validation/20261109T081724Z/` — 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; `PASS_WITH_WARNINGS`; exit code 0.
- Repair: `reports/desktop-repair/20261109T081723Z/` — 8 PASS, 4 WARN, 0 FAIL, 5 SKIP.
- BlueZ D-Bus/controller snapshot menunjukkan Powered, Pairable, dan Discoverable aktif; Pairable/Discoverable timeout 180 detik. RFKill tidak memblokir adapter dan firmware Intel berhasil dimuat.
- Pengguna mengonfirmasi pairing Bluetooth berhasil. Ini adalah uji manual yang dikonfirmasi pengguna, bukan hasil pairing otomatis dari validator.
- Caelestia lock screen sebelumnya dikonfirmasi berhasil dibuka dengan password.
- Tiga WARN journal masih ada pada validasi otomatis. HCI feature/debug messages masih tercatat di kernel log; pairing tetap berhasil setelah perbaikan readiness. CPU SMT vulnerability warnings adalah risiko residual yang secara eksplisit diterima pengguna dengan SMT tetap aktif. Tidak ada perubahan PAM, kernel parameters, SMT, atau firmware.
- Rincian konfirmasi manual: `reports/desktop-validation/20261109T081724Z/manual-acceptance.md`.
- Tahap 4 tidak mengklaim uji visual/fisik. Interaksi fisik/UI yang tidak tercakup tetap dapat diuji selama tahap 5 sebagai regression/acceptance tambahan.

## Keputusan dan batas

- Pairing Bluetooth menggunakan jendela Pairable/Discoverable sementara 180 detik; jangan menjadikannya always-discoverable.
- Repair tidak melakukan full system upgrade dan tidak mengubah PAM/kernel/SMT/firmware.
- Laporan dapat memuat username, hostname, path, identitas perangkat, status jaringan, dan journal. Review/redaksi sebelum push.
- Tahap 5 berfokus pada tema minimalis monochromatic, elegan/premium, dengan kontras dan keterbacaan terjaga serta beban animasi ringan untuk Intel UHD 620.
