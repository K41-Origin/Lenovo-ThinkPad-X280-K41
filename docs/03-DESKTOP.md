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

## Tahap 5 — Desktop Environment Customization (DESIGN APPROVED)

Arah desain **K41 Obsidian Minimalism / Graphite Monochrome** telah disetujui. Spesifikasi dan design tokens tercatat di [07 — Desktop Design System](07-DESKTOP-DESIGN-SYSTEM.md).

Implementasi dilakukan bertahap melalui script repository. Operator tidak perlu mengambil atau mengunggah screenshot; penilaian visual dilakukan langsung pada display ThinkPad X280 oleh pengguna.

### Fondasi tampilan — SUDAH DITERAPKAN

Script `scripts/k41-apply-desktop-customization.sh` menerapkan overlay appearance Hyprland, mengalihkan launcher `SUPER + R` ke Fuzzel, dan memasang konfigurasi Fuzzel Graphite. Script dijalankan sebagai user biasa, tanpa sudo:

```bash
bash scripts/k41-apply-desktop-customization.sh
```

Bukti run pengguna:
- Laporan: `reports/desktop-customization/20261109T090739Z/`.
- Status script: `SUCCESS`; backup privat dibuat dan konfigurasi diperbarui.
- Pengguna mengonfirmasi `SUPER + R` berhasil dijalankan.
- Hasil ini memverifikasi jalur launcher secara manual, bukan seluruh tampilan Stage 5. Pemeriksaan visual tetap dilakukan pengguna langsung pada perangkat.

Setiap run menghasilkan `run.log` dan `summary.txt`. Backup disimpan privat di `~/.local/state/k41/desktop-customization/backups/`. Rollback:

```bash
bash scripts/k41-apply-desktop-customization.sh --rollback /path/ke/direktori-backup
```

### Audit Caelestia sebelum integrasi

Sebelum mengubah shell, lakukan audit read-only terhadap versi runtime, package versions, font resolution, konfigurasi aktif, skema warna, dan proses:

```bash
bash scripts/k41-audit-caelestia.sh
```

Jalankan sebagai user biasa dari root repository, tanpa sudo. Script tidak mengubah konfigurasi, paket, service, wallpaper, maupun proses shell. Laporan berada di `reports/caelestia-audit/<timestamp>/`:
- `run.log`: versi, hasil CLI, font resolution, file konfigurasi, dan proses.
- `summary.txt`: status dan daftar artefak.
- `config-snapshot.json`: bagian konfigurasi Caelestia yang relevan; path personal dan lokasi cuaca disamarkan.

Review `config-snapshot.json` sebelum push. Push direktori laporan tersebut ke GitHub agar konfigurasi aktual dapat diaudit tanpa mengetik atau menyalin log manual.

### Hasil audit perangkat — 2026-11-09

Laporan pengguna: `reports/caelestia-audit/20261109T091310Z/`.
- Caelestia Shell 2.5.0-1, CLI 1.1.3-1, Quickshell 0.3.2 aktif.
- `shell.json` valid; konfigurasi pengguna saat ini hanya memiliki bagian `bar` dan `dashboard`.
- `shell-tokens.json` tidak ada; tidak perlu membuat override token internal.
- Font Rubik, CaskaydiaCove Nerd Font, dan Material Symbols Rounded tersedia.
- Skema aktif `caelestia/dark/tonalspot` masih menggunakan aksen teal.
- CLI terpasang menyediakan variant `monochrome`; skema custom tidak diasumsikan tersedia sebagai nama CLI. Tidak ada perubahan pada perangkat selama audit.

### Profil Caelestia Graphite — batch pertama diterapkan

Profil `config/desktop-customization/caelestia-shell.json` hanya mengatur tipografi menggunakan font yang telah terdeteksi tersedia:
- UI: Rubik.
- Monospace: CaskaydiaCove NF.

Script `scripts/k41-apply-caelestia-profile.sh` menggabungkan profil secara recursive ke `shell.json` sehingga pengaturan bar/dashboard lain tetap dipertahankan, lalu meminta CLI upstream mengatur scheme `caelestia/dark/monochrome`. Sebelum perubahan, script membuat backup privat untuk `shell.json` dan `scheme.json`; bila apply gagal, file dipulihkan. Tidak ada perubahan shell tokens, wallpaper, paket, service, atau file paket upstream.

Jalankan setelah pull sebagai user biasa, tanpa sudo:

```bash
bash scripts/k41-apply-caelestia-profile.sh
```

Setujui prompt apply. Setelah konfigurasi dan scheme diverifikasi, script menawarkan restart Caelestia. Pilih **Y** (default). Restart menggunakan `caelestia shell -r -d` dengan batas 10 detik agar shell diluncurkan detached dan script tidak membunuh proses foreground yang harus tetap hidup. Pola `-r -d` digunakan upstream pada proses post-update Caelestia. Setelah itu script mengambil runtime log melalui `caelestia shell -l` dan mencari entri `Configuration Loaded`. Jika perintah restart gagal, pengambilan log gagal, atau konfigurasi tidak terkonfirmasi, status dilaporkan sebagai warning.

Output command ditangkap sekali melalui `run.log`. Ringkasan menghapus ANSI color sequences dan hanya menghitung WARN/WARNING, ERROR, dan FATAL yang berada di awal baris sebagai level log; kata-kata tersebut di dalam pesan INFO script tidak ikut dihitung. Jumlah proses Quickshell juga dicatat sebagai informasi diagnostik, bukan satu-satunya bukti keberhasilan.

Laporan `reports/caelestia-customization/<timestamp>/` memuat:
- `run.log`: output apply, restart, dan runtime log.
- `summary.txt`: status apply/restart/log collector, jumlah WARN/WARNING, ERROR, FATAL, entri configuration-loaded, dan proses Quickshell.
- Backup privat tetap disimpan di `~/.local/state/k41/caelestia/backups/`.

Jika memilih skip atau log collector gagal, pengumpulan log dapat dicoba manual:

```bash
caelestia shell -l
```

Rollback menggunakan path backup yang dicatat oleh script:

```bash
bash scripts/k41-apply-caelestia-profile.sh --rollback /path/ke/direktori-backup
caelestia shell -r
```

### Hasil runtime sebelumnya — masalah diagnosis (sudah diperbaiki)

Laporan pengguna: `reports/caelestia-customization/20261109T092153Z/`.
- Profile typography dan scheme berhasil diverifikasi.
- Log memuat `Configuration Loaded` dua kali dan tidak memuat baris ERROR/FATAL.
- Warning `~/.face` tidak ditemukan berulang kali; ini memengaruhi gambar profil pengguna, bukan bukti kegagalan shell.
- Pesan `Object or context destroyed during incubation` pada StyledProgressBar dan Media tercatat sebagai INFO, bukan ERROR.
- Script lama menjalankan `caelestia shell -r` (foreground) di dalam `timeout 30s`. Exit 124 menghentikan proses foreground; ini merupakan kesalahan implementasi diagnostik dan dapat menjelaskan mengapa pemeriksaan proses Quickshell berikutnya menghasilkan 0. Restart diperbaiki ke pola detached upstream `caelestia shell -r -d`.
- Penghitung lama mencari kata WARN/ERROR/FATAL di seluruh pesan, sehingga turut menghitung teks INFO script sendiri. Pada laporan ini, angka WARN 8 terlalu tinggi; angka ERROR 1 dan FATAL 1 adalah false positive dari baris INFO "Review WARN/WARNING/ERROR/FATAL counts". Parser baru hanya menghitung level log di awal baris. Log runtime sebenarnya menunjukkan 6 baris WARN (5 terkait `~/.face`, 1 terkait QML CachingImage), 0 ERROR, dan 0 FATAL.

Hasil visual tetap dinilai langsung oleh pengguna pada perangkat. Perbaikan diagnostik telah dijalankan dan diaudit melalui laporan `reports/caelestia-customization/20261109T093038Z/`. Hasil terbaru: **SUCCESS**, restart `CONFIRMED`, runtime log `OK`, 3 entri `Configuration Loaded`, 1 proses Quickshell teramati, dan 0 WARN/ERROR/FATAL. Ini memverifikasi apply, restart detached, dan collector log; belum menggantikan review visual pengguna. Review isi laporan sebelum push karena runtime log dapat memuat path atau detail lingkungan.

## Tahap 6 — Optimization

Optimasi perangkat dan sistem dilakukan setelah tampilan diterima. Rencana dan batasnya ada di [05 — Operations](05-OPERATIONS.md). Jangan melakukan tuning agresif sebelum baseline terukur.

## Tahap 5 — Full Graphite implementation (IMPLEMENTED IN REPOSITORY; DEVICE APPLY PENDING)

Batch pertama Caelestia sebelumnya hanya mengganti font dan scheme; itu **bukan** redesign komponen. Implementasi repository berikut memperluas profil ke seluruh konfigurasi komponen Caelestia yang tersedia pada Shell **v2.5.0** dan menambahkan integrasi aplikasi desktop.

### Cakupan profil Caelestia

config/desktop-customization/caelestia-shell.json sekarang mengatur:
- Appearance scale, spacing, padding, rounding, typography, dan animasi yang lebih hemat.
- Bar/taskbar: urutan elemen, workspace indicator, active-window compact, tray, clock/date, status icons; logo dekoratif dihilangkan.
- Dashboard: media dan resource monitor; interval polling diperlonggar untuk mengurangi aktivitas periodik.
- Launcher: jumlah hasil lebih banyak dan fuzzy search untuk aplikasi/actions; dangerous actions tetap disabled.
- Lock screen: menggunakan wallpaper Obsidian, menyembunyikan notifikasi saat terkunci. Pengaturan autentikasi fingerprint/Howdy yang sebelumnya aktif dipertahankan; tidak ada perubahan PAM.
- Sidebar, notification grouping, OSD, utilities quick toggles, dan paths wallpaper.
- Scheme caelestia/dark/monochrome; smart dynamic scheme dimatikan agar wallpaper tidak mengubah identitas monochrome.

### Wallpaper

Aset desain vector assets/wallpapers/k41-obsidian-1920x1080.svg disimpan sebagai sumber editable. Untuk penerapan, assets/wallpapers/k41-obsidian-1280x720.jpg.base64 berisi JPEG 1280x720; script mendekodekannya ke ~/Pictures/Wallpapers/ lalu menjalankan caelestia wallpaper -f. JPEG termasuk format yang diterima oleh upstream Caelestia CLI. Resolusi 1280x720 akan di-scale ke panel 1920x1080; visual quality tetap perlu diterima saat uji perangkat.

### GTK, Thunar, Foot, Qt, icon dan cursor

Konfigurasi proyek:
- gtk-settings.ini: Adwaita-dark, icon/cursor Adwaita, Rubik, prefer-dark.
- gtk3.css dan gtk4.css: token Graphite untuk surface, text, selection, dan sidebar.
- thunar.css: mempertahankan struktur layout Thunar yang diaudit, menghapus teal dan animasi entrance, serta menjaga focus indication.
- foot.ini: CaskaydiaCove NF, palette Graphite, cursor beam non-blinking, dan padding terminal.
- caelestia-cli.json: meminta generator upstream mengaktifkan tema GTK dan Qt serta icon theme Adwaita. Tema Hyprland, Fuzzel, dan Foot tidak didelegasikan ke generator agar tidak bertabrakan dengan konfigurasi proyek yang dikelola terpisah.

Script integrasi:
scripts/k41-apply-desktop-integration.sh

### Urutan penerapan pada laptop

Setelah commit tersedia di branch lokal, dari root repository jalankan sebagai user biasa, tanpa sudo:

~~~bash
bash scripts/k41-apply-desktop-customization.sh
bash scripts/k41-apply-full-desktop-profile.sh
bash scripts/k41-apply-desktop-integration.sh
hyprctl reload
~~~

Setujui prompt masing-masing script. Jalankan desktop-customization lebih dahulu untuk memperbarui overlay Hyprland secara idempotent, shortcut Fuzzel, dan XCURSOR_THEME. Full profile melakukan merge recursive ke shell.json, menerapkan monochrome, mendekode dan mengaktifkan wallpaper JPEG, restart Caelestia detached, lalu mengumpulkan runtime log. Script integrasi membuat backup, merge cli.json, menjalankan generator theme upstream, memasang GTK/Thunar/Foot, dan restart Caelestia. Jalankan hyprctl reload, lalu tutup dan buka kembali aplikasi GTK/Foot agar konfigurasi barunya terbaca.

### Backup dan rollback

- Hyprland/Fuzzel/cursor: backup ~/.local/state/k41/desktop-customization/backups/; rollback memakai scripts/k41-apply-desktop-customization.sh --rollback BACKUP_DIRECTORY.
- Full Caelestia: backup ~/.local/state/k41/desktop-profile/backups/; rollback memakai scripts/k41-apply-full-desktop-profile.sh --rollback BACKUP_DIRECTORY.
- GTK/Thunar/Foot/CLI: backup ~/.local/state/k41/desktop-integration/backups/; rollback memakai scripts/k41-apply-desktop-integration.sh --rollback BACKUP_DIRECTORY.
- Rollback full profile mengembalikan shell.json dan scheme.json; pemilihan wallpaper sebelumnya perlu dipulihkan manual melalui >wallpaper.
- Rollback integrasi mengembalikan file yang memang sudah ada sebelum penerapan. File baru yang sebelumnya tidak ada dibiarkan dan perlu dihapus manual bila pengguna ingin kembali ke kondisi tanpa file tersebut.
- Kedua script berjalan sebagai user biasa dan tidak memasang paket, mengubah service sistem, atau mengedit shell-tokens.json.

### Status validasi

- **IMPLEMENTED:** profil, wallpaper SVG, GTK3/GTK4, Thunar, Foot, CLI theme preferences, dan dua script apply/rollback telah dikomit ke main.
- **STATIC REVIEW:** JSON profile dibangun dan diparse sebagai JSON sebelum commit; field Caelestia dipilih dari dokumentasi upstream tag v2.5.0.
- **NOT TESTED:** bash -n, ShellCheck, eksekusi script, parsing CSS/Foot pada versi lokal, dukungan SVG oleh wallpaper CLI, dan runtime/visual behavior belum dijalankan di laptop.
- **DEVICE APPLY PENDING:** pengguna perlu pull commit, menjalankan dua script, lalu menguji komponen secara langsung. Jangan tandai Stage 5 selesai sebelum uji fungsi dan visual diterima.
