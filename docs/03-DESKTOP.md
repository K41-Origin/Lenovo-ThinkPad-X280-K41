# Desktop Environment — Hyprland, Quickshell, Caelestia

## Tahap 3 — Instalasi

Jalankan dari TTY Basic Arch Linux sebagai user biasa:

```bash
sudo bash scripts/k41-install-desktop.sh
```

Entry point ini mendelegasikan ke `scripts/setup-desktop-x280.sh`. Setup memasang stack Wayland/Hyprland, audio, portal, utilitas, dan opsi Caelestia sesuai pilihan operator. Login desktop tetap manual dari TTY; tidak ada display manager/autologin. Jangan menambahkan autostart Caelestia duplikat.

Exit code 0 bukan acceptance desktop. Lanjutkan ke tahap 4.

## Tahap 4 — Desktop Environment: automated functional health validation (TAHAP AKTIF)

Tahap ini menggunakan validasi otomatis berbasis kondisi sistem, proses, konfigurasi, service, IPC, dan log. Pemeriksaan visual/fisik tidak menjadi bagian dari gate tahap ini sesuai keputusan proyek. Jalankan dari terminal sesi Hyprland sebagai user biasa, tanpa sudo:

```bash
bash scripts/k41-desktop-validation.sh
```

Script bersifat read-only terhadap sistem: tidak memasang paket, mengubah konfigurasi, mengaktifkan/menonaktifkan service, me-restart desktop, atau men-start Caelestia jika prosesnya tidak berjalan. Jika Caelestia tidak aktif, pemeriksaan IPC/log dan collector terkait di-SKIP agar validator tidak mengubah kondisi yang sedang diuji. Script hanya membuat laporan privat. Cakupan otomatis:
- Platform/session: Arch Linux, arsitektur, Wayland, executable Hyprland/Quickshell/Caelestia.
- Paket wajib dan paket opsional yang relevan.
- Hyprland: konfigurasi, monitor, input device, dan proses.
- Caelestia: proses, IPC target, runtime log, QML/load-error pattern.
- Service user: PipeWire, WirePlumber, portal; service NetworkManager.
- Audio graph, status konektivitas NetworkManager, dan radio block state.
- Driver GPU Intel i915, backlight telemetry, kapasitas filesystem, RAM, telemetry baterai/estimasi health, dan temperatur thermal zones.
- Status failed system/user units, penggunaan RAM, serta journal user/system/kernel dengan triage pola error kritis.
- Collector diagnostik desktop dan Caelestia yang sudah ada.

Jika hasil menunjukkan WARN/FAIL, jalankan remediation audit otomatis dari terminal sesi yang sama:

```bash
bash scripts/k41-desktop-repair.sh
```

Script repair menerapkan tindakan terbatas secara otomatis berdasarkan kondisi yang terdeteksi; tidak ada opsi `--apply` atau `--no-validate`. Script dapat menginisialisasi scheme default Caelestia, memasang hanya paket yang memang diperlukan dan belum tersedia (`bluez`, `bluez-utils`, `wireless-regdb`, `rtkit`), serta mengaktifkan `bluetooth.service` jika controller dan paket BlueZ terdeteksi. Autentikasi sudo hanya diminta bila tindakan sistem diperlukan. Tidak ada upgrade sistem menyeluruh.

PAM tidak pernah ditulis ulang. Repair selalu menyimpan hasil `pacman -Qkk pambase`, versi paket, dan pemilik `/etc/pam.d/other` pada laporan privat untuk diagnosis. Jika integritas atau kepemilikan tidak dapat dipastikan, hasilnya WARN dan kebijakan PAM tetap tidak disentuh. Foto profil `.face` tidak dibuat otomatis. Kernel parameters/SMT, firmware controller, dan konfigurasi desktop tidak diubah. Error HCI tidak dianggap dapat diselesaikan dengan restart service. Setelah tindakan, validator dijalankan ulang otomatis.

Satu run menghasilkan `reports/desktop-validation/<timestamp>/`:
- `summary.md`: hasil agregat PASS/WARN/FAIL/SKIP dan batas interpretasi.
- `checks.tsv`: hasil setiap pemeriksaan yang dapat diproses.
- `validation.log`: command dan output diagnostik.
- `environment.txt`: metadata sistem/sesi.
- `desktop/` dan `caelestia/`: laporan collector tambahan.
- `*-journal*.txt`: snapshot journal yang dapat diakses user.

**Interpretasi hasil:**
- PASS: semua pemeriksaan yang dijalankan memenuhi aturan otomatis dan tidak ada WARN/FAIL.
- PASS_WITH_WARNINGS: tidak ada FAIL, tetapi satu atau lebih WARN harus ditinjau sebelum gate diterima.
- WARN: kondisi belum tentu rusak, tetapi perlu ditinjau (misalnya service on-demand, jaringan tidak tersambung, atau telemetry opsional).
- FAIL: prasyarat/health check yang ditetapkan tidak terpenuhi; jangan lanjut ke tahap berikutnya sebelum dianalisis.
- SKIP: pemeriksaan tidak dijalankan; bukan PASS.

Validasi log tidak dapat membuktikan bahwa panel terlihat, launcher menerima input, speaker menghasilkan suara, microphone merekam, tombol fisik bekerja, atau interaksi lain berhasil. Script tidak akan mengklaim hal tersebut. Hasil PASS berarti hanya tidak ada kondisi FAIL yang dideteksi oleh pemeriksaan otomatis yang tersedia; bukan jaminan semua fungsi hardware/UI berjalan.

Laporan dapat memuat username, hostname, identitas perangkat, status jaringan, path, dan log. Review/redaksi sebelum push. Jangan menganggap log journal sebagai bukti lengkap jika akses journal dibatasi.

**Gate tahap 4:** script selesai dengan exit 0, tidak ada FAIL, seluruh WARN (jika ada) ditinjau dan diberi alasan/keputusan, dan laporan direview. Ringkasan dapat berstatus PASS atau PASS_WITH_WARNINGS. Tahap 5 dapat dimulai setelah gate berbasis bukti log ini disetujui. Penerimaan visual/interaksi tetap berada di luar cakupan gate ini dan tidak boleh diklaim VERIFIED.

## Tahap 5 — Desktop Environment Customization

Arah desain: minimalis, monoton/monochromatic, elegan, dan premium. Jaga kontras, hirarki visual, keterbacaan, konsistensi, dan responsivitas. Cakupan: panel, launcher, dashboard, widget, notifikasi, wallpaper, typography, icon, border, radius, spacing, dan animasi.

Kustomisasi dilakukan bertahap dengan backup dan rollback. Hindari efek berat pada UHD 620. Acceptance memerlukan screenshot before/after, review visual pada perangkat, interaksi tetap berfungsi, dan tidak ada regresi fungsional tahap 4.

## Tahap 6 — Optimization

Optimasi perangkat dan sistem dilakukan setelah tampilan diterima. Rencana dan batasnya ada di [05 — Operations](05-OPERATIONS.md). Jangan melakukan tuning agresif sebelum baseline terukur.
