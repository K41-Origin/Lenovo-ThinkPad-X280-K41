# Desktop Environment — Hyprland, Quickshell, Caelestia

## Tahap 3 — Instalasi

Jalankan dari TTY Basic Arch Linux sebagai user biasa:

```bash
sudo bash scripts/k41-install-desktop.sh
```

Entry point ini mendelegasikan ke `scripts/setup-desktop-x280.sh`. Setup memasang stack Wayland/Hyprland, audio, portal, utilitas, dan opsi Caelestia sesuai pilihan operator. Login desktop tetap manual dari TTY; tidak ada display manager/autologin. Jangan menambahkan autostart Caelestia duplikat.

Exit code 0 bukan acceptance desktop. Lanjutkan ke tahap 4.

## Tahap 4 — Desktop Functional Validation (SELESAI)

Gate tahap 4 adalah validasi otomatis berbasis kondisi sistem, proses, konfigurasi, service, IPC, dan log. Pemeriksaan visual/fisik tidak termasuk gate ini sesuai keputusan proyek.

Jalankan dari terminal sesi Hyprland sebagai user biasa, tanpa sudo:

```bash
bash scripts/k41-desktop-validation.sh
```

Validator bersifat read-only terhadap sistem: tidak memasang paket, mengubah konfigurasi, mengaktifkan/menonaktifkan service, me-restart desktop, atau men-start Caelestia jika prosesnya tidak berjalan. Jika Caelestia tidak aktif, pemeriksaan IPC/log dan collector terkait di-SKIP agar validator tidak mengubah kondisi yang diuji. Laporan disimpan secara privat.

Cakupan otomatis meliputi:
- Platform/session, executable dan paket Hyprland/Quickshell/Caelestia.
- Konfigurasi, monitor, input device, proses dan IPC.
- Caelestia runtime log dan pola QML/load-error.
- PipeWire, WirePlumber, portal, NetworkManager, audio graph dan konektivitas.
- Driver Intel i915, backlight, RAM, filesystem, baterai dan thermal zones.
- Failed system/user units dan triage journal.
- Diagnostik tambahan desktop, Caelestia, Bluetooth, PAM dan CPU.

Jika hasil menunjukkan WARN/FAIL, jalankan remediation audit terbatas dari terminal sesi yang sama:

```bash
bash scripts/k41-desktop-repair.sh
```

Repair dapat memasang paket prasyarat yang memang belum tersedia, mengaktifkan Bluetooth bila prasyarat terpenuhi, dan membuka pairing window sementara. Untuk Bluetooth, Pairable dan Discoverable disetel selama 180 detik; tidak ada konfigurasi permanen always-discoverable. Repair tidak mengubah PAM, kernel parameters, SMT policy, firmware controller, atau konfigurasi desktop. Tidak ada full system upgrade. Setelah tindakan, validator dijalankan ulang otomatis.

Satu run menghasilkan `reports/desktop-validation/<timestamp>/` berisi ringkasan, hasil pemeriksaan, log, metadata lingkungan, dan collector tambahan. Repair menghasilkan laporan di `reports/desktop-repair/<timestamp>/`. Review dan redaksi laporan sebelum push karena dapat memuat username, hostname, identitas perangkat, status jaringan, path, dan log.

### Bukti penerimaan terakhir

- Validasi otomatis: `reports/desktop-validation/20261109T081724Z/`.
- Hasil: **PASS_WITH_WARNINGS — 54 PASS, 3 WARN, 0 FAIL, 0 SKIP**, exit code 0.
- Repair: `reports/desktop-repair/20261109T081723Z/`; 8 PASS, 4 WARN, 0 FAIL, 5 SKIP.
- BlueZ melaporkan `Pairable=yes`, `Discoverable=yes`, masing-masing dengan timeout 180 detik. Firmware Intel termuat dan RFKill tidak memblokir adapter.
- Pengguna mengonfirmasi pairing Bluetooth berhasil setelah repair. Konfirmasi ini dicatat sebagai uji manual pengguna; laporan otomatis sendiri hanya memeriksa readiness dan tidak menjalankan transaksi pairing.
- Caelestia lock screen sebelumnya dikonfirmasi dapat dibuka dengan password.
- Tiga WARN journal tetap tercatat. Temuan HCI Bluetooth masih muncul pada log kernel meskipun pairing berhasil. Status SMT vulnerable pada sebagian mitigasi CPU merupakan risiko residual yang secara eksplisit diterima pengguna dengan mempertahankan SMT aktif. Tidak ada perubahan PAM/SMT/kernel/firmware untuk menghilangkan warning.
- Catatan uji manual: `reports/desktop-validation/20261109T081724Z/manual-acceptance.md`.

### Batas interpretasi

PASS atau PASS_WITH_WARNINGS hanya mencerminkan pemeriksaan otomatis yang tersedia. Hasil tersebut tidak membuktikan panel, launcher, tombol fisik, speaker, microphone, suspend/resume, atau seluruh interaksi UI. Tidak ada klaim visual/fisik yang dibuat.

**Keputusan gate:** tahap 4 diterima dan ditutup berdasarkan exit code 0, nol FAIL, seluruh WARN ditinjau dan risiko residualnya dicatat, serta konfirmasi manual pairing dari pengguna. Pemeriksaan visual/fisik yang berada di luar cakupan tahap 4 tidak menghalangi dimulainya tahap 5.

## Tahap 5 — Desktop Environment Customization (SIAP DIMULAI)

Arah desain: minimalis, monochromatic, elegan, dan premium. Jaga kontras, hirarki visual, keterbacaan, konsistensi, dan responsivitas. Cakupan: panel, launcher, dashboard, widget, notifikasi, wallpaper, typography, icon, border, radius, spacing, dan animasi.

Kustomisasi dilakukan bertahap dengan backup dan rollback. Hindari efek berat pada Intel UHD 620. Acceptance tahap 5 memerlukan screenshot before/after, review visual pada perangkat, interaksi tetap berfungsi, dan tidak ada regresi fungsional tahap 4.

## Tahap 6 — Optimization

Optimasi perangkat dan sistem dilakukan setelah tampilan diterima. Rencana dan batasnya ada di [05 — Operations](05-OPERATIONS.md). Jangan melakukan tuning agresif sebelum baseline terukur.
