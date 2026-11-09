# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan konfirmasi pengguna yang tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer; penerimaan boot fisik dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | **COMPLETED** | Laporan terbaru 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. WARN ditinjau dan risiko residual didokumentasikan. Pengguna mengonfirmasi pairing Bluetooth berhasil. Batas visual/fisik tetap eksplisit di luar gate. |
| 5. Desktop Customization | **IN PROGRESS — WORKSTREAM 2** | Workstream 1 (boot experience) ditutup berdasarkan konfirmasi pengguna. Workstream 2: override QML `Content.qml`, `Center.qml`, `PasswordInput.qml`, dan `LockSurface.qml` serta installer deployment telah **IMPLEMENTED**. Commit layout terakhir: `35d924a` dan `5851a5b`; perubahan sebelumnya mencakup surface luar transparan, password surface terpisah, dan deployment source tree Caelestia lengkap. **Belum TESTED/VERIFIED pada X280**: belum ada bukti runtime QML, path source aktif setelah deployment terbaru, lock/unlock, wake, atau penerimaan visual. Guest Mode **NOT IMPLEMENTED**. Atas instruksi eksplisit pengguna, collector read-only storage/persistence `scripts/k41-guest-storage-audit.sh` telah **IMPLEMENTED** untuk mengumpulkan baseline; ini bukan implementasi Guest Mode. Perubahan konfigurasi, akun, atau workflow Guest Mode tetap menunggu desain dan acceptance terpisah. Perbaikan tahap instalasi sebelumnya tetap dijadwalkan sebelum tahap 7. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5 dan baseline terukur. |
| 7. Release | PLANNED | Menunggu seluruh acceptance gate, regression, dokumentasi, dan bukti final. |

## Keputusan arah proyek: Tahap 5 sebagai pedoman instalasi ulang

Pengguna menetapkan bahwa hasil dan pembelajaran dari **Tahap 5 — Desktop Customization** nantinya tidak hanya dipakai untuk menyelesaikan tampilan desktop. Tahap 5 juga akan menjadi **referensi desain dan pedoman perbaikan** bagi proses instalasi serta kustomisasi sistem secara keseluruhan.

Tujuan akhirnya adalah membuat proses membangun sistem dari kondisi nol menjadi lebih mudah, terstruktur, konsisten, dan dapat diulang. Dengan demikian, keputusan konfigurasi desktop, dependensi, urutan setup, integrasi boot/session, dan kebutuhan pengguna yang ditemukan selama Tahap 5 dapat digunakan untuk mengevaluasi kembali tahapan instalasi sebelumnya.

Keputusan urutan kerja:
1. Lanjutkan dan dokumentasikan Tahap 5 berdasarkan kondisi serta bukti aktual.
2. Setelah pekerjaan Tahap 5 cukup matang, gunakan hasilnya untuk mengidentifikasi perubahan yang diperlukan pada tahapan instalasi sebelumnya.
3. **Lakukan evaluasi dan perbaikan tahapan sebelumnya sebelum memulai Tahap 7 — Release.**
4. Jangan memulai refactoring menyeluruh tahapan sebelumnya sekarang; pekerjaan tersebut secara eksplisit ditunda sampai waktunya sebelum Tahap 7.

Ini merupakan keputusan perencanaan (**PLANNED**), bukan perubahan installer yang sudah diimplementasikan. Tidak ada perubahan pada script instalasi atau konfigurasi sistem sebagai bagian dari keputusan dokumentasi ini.

## Entry point kanonis

| Script | Fungsi | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | Live ISO readiness | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | Basic Arch installation | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | Desktop installation | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Read-only desktop health validation | IMPLEMENTED |
| `scripts/k41-desktop-repair.sh` | Scoped repair and evidence collection | IMPLEMENTED |
| `scripts/k41-lockscreen-audit.sh` | Read-only lock-screen inventory and evidence collector | IMPLEMENTED — REPORT COLLECTED; runtime lock path still needs device confirmation |
| `config/quickshell/caelestia/modules/lock/{Content,Center}.qml` | User-level Caelestia QML overrides for Floating Password Card | IMPLEMENTED — NOT TESTED ON DEVICE |
| `scripts/k41-apply-lockscreen-design.sh` | Sudo entry with SUDO_USER privilege drop; install/rollback QML overrides as desktop user | IMPLEMENTED — STATIC TEST NOT RUN; DEVICE NOT TESTED |
| `tests/test-lockscreen-design.sh` | Static override structure and Bash syntax checks | IMPLEMENTED — NOT RUN |
| `scripts/k41-enable-caelestia-autologin.sh` + `scripts/k41-lock-caelestia-after-start.sh` | Opt-in tty1 autologin + verified Caelestia lock startup + Hyprlock fallback | IMPLEMENTED — NOT TESTED ON DEVICE |
| `scripts/audit-x280-boot.sh` | Read-only boot/UKI/LUKS/TPM2/Plymouth state collector | IMPLEMENTED — REPORT COLLECTED |
| `scripts/k41-configure-boot-experience.sh` + `scripts/k41-plymouth-quit-after-lock.sh` | Plymouth K41 theme, quiet splash, lock-aware TTY1 handoff, additive TPM2/PCR7 enrollment | IMPLEMENTED — ORIGINAL SCRIPT RUN CONFIRMED |
| `tests/test-boot-experience.sh` | Static syntax and safety-invariant test for boot setup | IMPLEMENTED — NOT RUN IN THIS SESSION |
| `scripts/k41-install-plymouth-theme.sh` + `themes/plymouth/k41/` | Install native K41 theme, verify Arch reboot/poweroff/halt units, rebuild initramfs/UKI | IMPLEMENTED — DEVICE TEST PENDING |
| `tests/test-plymouth-k41-theme.sh` | Static checks for Plymouth theme and installer | IMPLEMENTED — NOT RUN IN THIS SESSION |
| `scripts/k41-install-animated-boot-splash.sh` + `config/quickshell/k41-boot-splash/shell.qml` | Animated K41 Quickshell overlay and Hyprland visual configuration | IMPLEMENTED — KNOWN VISUAL LEAK ON DEVICE |
| `tests/test-animated-boot-splash.sh` | Static syntax and safety-invariant test for animated handoff | IMPLEMENTED — NOT RUN IN THIS SESSION |

## Prioritas saat ini

**CURRENT — Tahap 5, Workstream 2: lock screen.** Desain C — Floating Password Card telah diimplementasikan melalui empat override QML (`Content.qml`, `Center.qml`, `PasswordInput.qml`, dan `LockSurface.qml`) serta installer deployment source tree Caelestia lengkap dengan backup/rollback. Outer surface transparan, password field mempertahankan surface rounded tersendiri, dan kelompok clock/date/password diposisikan geometris di tengah area konten penuh. Jalur wallpaper/blur dan autentikasi upstream dipertahankan. Statusnya IMPLEMENTED, bukan TESTED/VERIFIED: pengguna perlu menerapkan pada X280, memeriksa source path/runtime QML, menguji lock/unlock dan wake, lalu menilai visual. Workstream 1 (boot experience) telah dinyatakan selesai oleh pengguna. Setelah lock screen diterima, lanjutkan berurutan ke dashboard, taskbar/panel, launcher, sidebar, lalu utilities. Elemen lintas-komponen (design tokens, typography, icons/cursor, wallpaper, notifications/OSD, window appearance, terminal, GTK/Qt) dijaga konsisten saat komponen terkait dikerjakan. Refactoring tahap instalasi sebelumnya berdasarkan hasil Tahap 5 tetap ditunda sampai sebelum Tahap 7.

### Konfirmasi keberhasilan boot sistem

Pada 2026-11-09 pengguna mengonfirmasi: **booting sudah berhasil** pada ThinkPad X280. Catatan ini berarti sistem berhasil melewati proses startup dan mencapai sistem yang dapat digunakan menurut konfirmasi pengguna. Rincian seperti cold boot berulang, metode unlock root (TPM2 atau passphrase), durasi boot, serta hasil pengamatan visual tidak disimpulkan karena tidak disertakan dalam konfirmasi tersebut.

Keberhasilan boot dasar ini tidak sama dengan penerimaan penuh workstream boot experience. Isu visual K41/Hyprland masih dicatat terpisah, dan keberhasilan reboot serta poweroff belum dikonfirmasi dalam catatan ini.

### Status faktual visual boot

Pengguna mengonfirmasi pada 2026-11-09 bahwa tampilan Hyprland masih terlihat/bocor pada ketiga kondisi:
- **Power-on:** tampilan Hyprland muncul selama transisi startup.
- **Reboot:** tampilan Hyprland muncul selama transisi restart.
- **Poweroff:** tampilan Hyprland masih terlihat selama proses shutdown.

Ini adalah hasil pengujian visual langsung yang dilaporkan pengguna. Karena itu, jangan menyatakan tampilan boot/reboot/shutdown sudah konsisten atau bebas flicker. Pengaturan Hyprland dan overlay Quickshell yang telah ditambahkan baru berstatus IMPLEMENTED; efektivitasnya belum menyelesaikan masalah di perangkat.

### Pekerjaan yang sudah diimplementasikan

- Tema native Plymouth K41: background hitam, wordmark K41, ring 12 glyph dengan sequential glow. Pada boot normal TPM2 diharapkan membuka root tanpa prompt; callback password hanya relevan sebagai jalur recovery jika auto-unlock gagal.
- Quickshell memakai wordmark dan spinner 12 titik dengan gaya yang disamakan ke Plymouth.
- Installer Quickshell mengatur opsi visual Hyprland untuk menonaktifkan logo/splash, wallpaper default, dan memakai background hitam selama handoff.
- Installer Plymouth memeriksa unit transisi reboot, poweroff, dan halt yang disediakan paket Arch.
- Dokumentasi sekarang mencatat keterbatasan aktual dan pekerjaan yang belum selesai.

### Pekerjaan berikutnya — PLANNED, belum dikerjakan

Jalankan konfigurasi boot experience aktual setelah prasyarat perangkat dan recovery diverifikasi, lalu uji terpisah tiga jalur visual tanpa mengasumsikan satu penyebab:
1. **Power-on:** urutan firmware → kernel/KMS → initramfs/Plymouth → systemd → getty/Hyprland → Quickshell → Caelestia.
2. **Reboot:** urutan shutdown target, Plymouth reboot unit, compositor/session exit, dan display handoff.
3. **Poweroff:** urutan shutdown target, Plymouth poweroff unit, compositor/session exit, dan display handoff.

Kumpulkan bukti konfigurasi dan journal sebelum mengubah service, hook, kernel parameter, atau timing. Periksa konfigurasi Hyprland yang benar-benar dimuat, proses Quickshell, layer-shell stacking, unit Plymouth yang aktif/tertaut, serta isi UKI dan kernel command line. Jangan menambahkan delay buatan atau unit kustom yang berkompetisi dengan unit paket tanpa diagnosis.

### Acceptance criteria berikutnya

- Tidak ada wallpaper, logo, desktop, atau frame Hyprland yang terlihat saat power-on, reboot, maupun poweroff.
- Animasi K41 Plymouth digunakan pada fase early boot dan transisi reboot/shutdown sejauh didukung lifecycle systemd.
- Handoff ke Quickshell/Caelestia tidak menampilkan desktop Hyprland.
- Caelestia Lock Screen tetap terverifikasi terkunci sebelum splash Quickshell ditutup.
- TPM2 auto-unlock adalah jalur normal yang ditargetkan; passphrase LUKS tetap dipertahankan sebagai recovery. Script konfigurasi menambahkan token TPM2 secara additive dan tidak menghapus passphrase. Enrollment tetap merupakan perubahan keamanan yang harus diverifikasi.

Status target visual keseluruhan: **NOT VERIFIED / KNOWN ISSUE**. Pengujian nyata pada ThinkPad X280 adalah langkah aktif berikutnya. Static test dan inspeksi repository hanya pemeriksaan pendukung, bukan pengganti cold boot, reboot, dan poweroff.

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

## Status lock screen dan Guest Mode — 2026-11-09

### Lock screen

- **IMPLEMENTED (repository):** override QML dan script `scripts/k41-apply-lockscreen-design.sh` tersedia di `main`. Installer men-deploy source tree Caelestia yang dipin ke versi/revision upstream, dengan backup dan rollback.
- **Perubahan desain yang tercatat:** surface luar lock screen dibuat transparan agar wallpaper/blur tetap menjadi latar; kartu/field password mempertahankan surface rounded tersendiri; `Content.qml` mengisi area yang tersedia; `Center.qml` menempatkan kelompok clock/date/password melalui `anchors.centerIn` pada parent berukuran penuh.
- **Komponen terkait:** `config/quickshell/caelestia/modules/lock/LockSurface.qml`, `Content.qml`, `Center.qml`, `center/PasswordInput.qml`, dan `scripts/k41-apply-lockscreen-design.sh`.
- **Commit layout terbaru:** `35d924ad2de25c858389961c8eac3b255d13ed46` (full available content area) dan `5851a5b5ef90621f460e5541aecd44ad2fc96e7b` (geometric centering). Perubahan lock-screen lain ada pada histori commit sebelumnya di `main`.
- **NOT TESTED / NOT VERIFIED pada perangkat:** tidak ada hasil yang membuktikan QML runtime berhasil memuat override terbaru, lock/unlock berfungsi, wake/resume aman, atau posisi visual benar-benar berada di tengah. Keberhasilan commit atau installer bukan bukti penerimaan tampilan.
- **Acceptance berikutnya:** tarik `main`, jalankan installer sesuai panduan lock screen, restart Quickshell dari sesi Hyprland aktif, pastikan report menunjuk ke source tree lokal `~/.config/quickshell/caelestia/shell.qml`, lalu uji lock/unlock, password salah/benar, wake, dan review visual langsung di X280. Jangan mengubah PAM atau autentikasi untuk memperbaiki tampilan.

### Guest Mode

**DESAIN KONSEPTUAL DISETUJUI — IMPLEMENTASI BELUM DIMULAI.** Pada 2026-11-09 pengguna menyetujui arah arsitektur Guest Mode dan meminta keputusan dicatat. Persetujuan ini hanya mencakup spesifikasi konseptual; bukan izin untuk mengubah akun, konfigurasi, service, mount, swap, atau storage perangkat.

Dokumen spesifikasi: [Guest Mode — Ephemeral Session](08-STAGE-5/03-GUEST-MODE.md).

Ringkasan keputusan:
- Gunakan akun Linux terpisah dengan username default **`guest`**.
- Gunakan desktop environment/session yang sudah tersedia: Hyprland + Caelestia. Jangan memasang atau menjalankan desktop environment kedua khusus Guest.
- Gunakan aplikasi sistem yang sama jika aman; pisahkan home, konfigurasi, runtime, dan data aplikasi Guest dari akun utama.
- Tidak ada pembagian atau reservasi RAM statis. Mekanisme volatile seperti tmpfs boleh menggunakan RAM secara dinamis sesuai kebutuhan, dengan batas dan dampak memory pressure yang harus diuji.
- Browser Guest harus diluncurkan otomatis dalam mode Incognito/Private dan memakai profile Guest terpisah; jangan pernah memakai profile akun utama. Incognito bukan pengganti isolasi penyimpanan.
- Guest tidak memperoleh hak administrator dan tidak boleh membaca atau mengubah data pribadi akun utama maupun konfigurasi sistem yang dilindungi.
- Semua data lokal yang dapat ditulis selama sesi Guest harus ephemeral dan tidak boleh bertahan setelah reboot atau poweroff. Akun utama dan data persistent miliknya tetap berada di luar cakupan cleanup Guest.
- Session ID dan metadata/log sesi digunakan untuk tracking dan lifecycle management, bukan sebagai satu-satunya daftar sumber data yang harus dihapus.
- Penyimpanan sesi harus diisolasi sejak awal. Saat logout, sesi dapat dihancurkan; setelah setiap boot/reboot, sistem wajib memeriksa bahwa storage Guest bersih, membersihkan residu yang ditemukan, lalu memverifikasi ulang.
- Jika pemeriksaan atau cleanup gagal, Guest login harus ditolak (fail closed), bukan meneruskan sesi di atas storage yang belum terbukti bersih.
- Swapfile persistent aktif pada baseline X280 adalah blocker yang harus diselesaikan dalam desain; LUKS encryption sendiri tidak menjadikan swap ephemeral.

Batas dan status:
- Arsitektur storage final (mis. selective ephemeral storage vs full-session OverlayFS) **belum dipilih**. Pilihan harus didasarkan pada audit write paths, kompatibilitas aplikasi, RAM 8 GB, serta pengujian.
- Belum ada jaminan bahwa semua data lokal Guest sudah dapat dihapus; klaim tersebut baru boleh dibuat setelah acceptance tests membuktikan jalur penyimpanan, swap, crash, forced poweroff, dan reboot.
- Penghapusan tidak dapat mencakup data yang sudah dikirim ke server, router, DNS resolver, perangkat eksternal, atau media lain di luar kontrol lokal sistem.
- Audit storage read-only sebelumnya tetap menjadi baseline; tidak ada konfigurasi perangkat yang diubah sebagai bagian dari keputusan desain ini.
- Gate urutan proyek yang sudah berlaku tetap dihormati: implementasi Guest Mode tidak dimulai sebelum custom lock screen diterima pengguna. Dokumentasi keputusan konseptual ini tidak menutup gate tersebut.

## Keputusan dan batas

- Pairing Bluetooth menggunakan jendela Pairable/Discoverable sementara 180 detik; jangan menjadikannya always-discoverable.
- Repair tidak melakukan full system upgrade dan tidak mengubah PAM/kernel/SMT/firmware.
- Laporan dapat memuat username, hostname, path, identitas perangkat, status jaringan, dan journal. Review/redaksi sebelum push.
- Tahap 5 berfokus pada tema minimalis monochromatic, elegan/premium, dengan kontras dan keterbacaan terjaga serta beban animasi ringan untuk Intel UHD 620.

**Pembaruan 2026-11-10 — arah akses Guest Mode:** Pengguna menginginkan pilihan Guest Mode langsung dari **Caelestia Lock Screen**, tanpa reboot untuk berpindah sesi. Target alur: dari lock screen, akhiri sesi akun utama dengan aman, siapkan storage ephemeral, lalu jalankan sesi Hyprland + Caelestia sebagai akun `guest`; setelah Guest logout, hancurkan storage dan kembali ke greeter. Mekanisme teknis pergantian sesi belum dipilih atau diverifikasi. Threat model dibatasi pada kebutuhan praktis penggunaan keluarga. Catatan pengguna (teks persis): “guest mode direalisasikan nanti kalo ga mager, ingetin gua tahun 2027”. Fitur ini berprioritas rendah dan ditunda. Detail dan batas keputusan: [Guest Mode — Ephemeral Session](08-STAGE-5/03-GUEST-MODE.md).

