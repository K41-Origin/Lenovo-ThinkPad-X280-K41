# Workstream 2 — Lock Screen

## Tujuan

Menyempurnakan lock screen agar minimal, konsisten dengan K41 Obsidian Minimalism — Graphite Monochrome, mudah dibaca, aman, dan dapat dipulihkan.

## Keputusan desain yang disetujui

Desain **C — Floating Password Card** dipilih pengguna sebagai arah visual:

1. Hanya tampilkan jam, tanggal, hari dalam minggu, dan field password.
2. Hilangkan widget lain dari lock screen (termasuk media, notifikasi, status sistem, dan elemen dekoratif yang tidak diperlukan).
3. Gunakan wallpaper desktop yang sama dengan wallpaper aktif; jangan membuat wallpaper lock screen terpisah sebagai default.
4. Tampilkan wallpaper sebagai latar penuh layar dengan blur.
5. Tempatkan jam/tanggal/hari di atas kartu password.
6. Kartu password berukuran ringkas dan mengambang, terpisah secara visual dari clock/date.
7. Gunakan Graphite Monochrome, kontras yang cukup, tipografi terbaca, dan animasi halus.
8. Prioritaskan dukungan upstream Caelestia/Quickshell sebelum membuat override QML. Jangan menganggap `shell.json` mendukung layout/blur sebelum schema dan implementasi versi terpasang diperiksa.

Persetujuan desain C adalah persetujuan arah desain, **bukan** persetujuan implementasi final. Visual final harus diperiksa langsung oleh pengguna pada ThinkPad X280.

## Batas

Termasuk layout, jam/tanggal/hari, wallpaper aktif dan blur, password prompt, indikator autentikasi yang memang dibutuhkan, keyboard/focus behavior, notifikasi saat terkunci, serta transisi lock/unlock.

Tidak termasuk perubahan PAM atau kebijakan autentikasi, perubahan password, LUKS, TPM, penggantian arsitektur shell, atau Guest Mode. **Guest Mode ditunda dan tidak boleh dirancang/diimplementasikan sampai pengguna secara eksplisit menyatakan custom lock screen berhasil diterima.**

Fingerprint dan Howdy yang sudah terpasang boleh tetap tersedia hanya jika jalur autentikasi aktif saat ini membuktikan dukungannya. Jangan mengaktifkan, menonaktifkan, atau mengubah autentikasi hanya demi tampilan.

## Model kolaborasi dan siklus kerja

Pengerjaan mengikuti pola AI-assisted development; perangkat fisik tetap menjadi sumber bukti runtime:

1. **AUDIT** — asisten memeriksa repository dan menyiapkan collector read-only.
2. **EXECUTE** — pengguna melakukan pull dan menjalankan script di ThinkPad X280.
3. **REPORT** — pengguna mengirimkan output audit yang telah ditinjau/redaksi.
4. **ANALYZE** — asisten menganalisis kondisi aktual dan menetapkan perubahan terkecil.
5. **IMPLEMENT** — asisten menyiapkan perubahan script/config/docs di repository.
6. **PULL & TEST** — pengguna pull dan menjalankan validasi di perangkat.
7. **VERIFY** — kedua pihak mengevaluasi bukti dan acceptance criteria; pengguna menyetujui visual/interaksi final.

Asisten tidak mengklaim pengujian perangkat yang tidak dijalankannya. Pengguna tidak perlu mengirim password, token, recovery key, atau kredensial apa pun. Laporan harus ditinjau dan data personal disunting sebelum dibagikan.

## Prosedur teknis

1. Audit lock mechanism aktif, executable/versi, konfigurasi Hyprland/Caelestia/Quickshell/Hyprlock, PAM secara read-only, proses, keybind, startup ordering, wallpaper, dan fallback.
2. Tentukan jalur lock yang benar-benar dipanggil saat runtime; keberadaan konfigurasi atau package bukan bukti pemakaian.
3. Periksa implementasi upstream Caelestia sesuai versi terpasang, termasuk kemampuan layout, wallpaper provider, blur, dan auth prompt.
4. Catat baseline visual/fungsional sebelum perubahan.
5. Buat backup konfigurasi yang akan disentuh dan prosedur rollback.
6. Terapkan perubahan kecil pada lapisan visual; autentikasi dan PAM tidak disentuh.
7. Uji manual lock, startup lock bila berlaku, screen blank/wake, password salah/benar, fokus keyboard, dan restart shell ketika terkunci.
8. Pastikan desktop tidak terlihat sebelum lock benar-benar aktif; pastikan notifikasi/konten sensitif tidak bocor.
9. Uji fingerprint/Howdy hanya bila terdeteksi aktif, serta fallback/recovery yang tersedia.
10. Minta pengguna menilai hasil visual langsung pada panel ThinkPad X280.

## Analisis baseline perangkat — 2026-11-09

Laporan aktual tersedia di `reports/lockscreen-audit/20261109T141943Z/audit.txt`. Bukti yang tercatat:

- Caelestia Shell 2.5.0-1 (revision `d999d4878ee4cec134168e60d913714566a8cfa6`), Caelestia CLI 1.1.3-1, Quickshell 0.3.2, Hyprland 0.57.1-1, dan Hyprlock 0.9.7-2 terpasang.
- Proses Hyprland dan `qs` terdeteksi. Proses bernama `caelestia` dan `hyprlock` tidak terdeteksi pada saat pengambilan laporan; nama proses `qs` saja tidak membuktikan bahwa konfigurasi Caelestia sedang berjalan.
- Konfigurasi Caelestia mencatat `lock.enabled=true`, `lock.useWallpaper=true`, dan `lock.hideNotifs=true`. Nilai konfigurasi bukan bukti bahwa lock screen aktif memakai jalur tersebut.
- `fprintd`, `pam_fprintd`, dan `howdy` tidak ditemukan sebagai paket/perintah. Karena itu, konfigurasi toggle fingerprint/Howdy tidak boleh ditafsirkan sebagai autentikasi yang benar-benar tersedia.
- Laporan menyebut sesi Wayland, tetapi `WAYLAND_DISPLAY` dan `HYPRLAND_INSTANCE_SIGNATURE` tidak tersedia dalam lingkungan collector. Query binding dilewati. Lock keybind, jalur yang dipanggil, dan status lock aktual belum terbukti.
- Service bernama `caelestia.service`, `quickshell.service`, dan `hyprlock.service` tidak aktif/tidak ditemukan. Ini tidak meniadakan shell yang dimulai langsung dari Hyprland.

### Audit upstream pada revision yang terpasang

Revision Caelestia `d999d4878ee4cec134168e60d913714566a8cfa6` memuat `WlSessionLock` dan PAM handler di modul lock. `LockSurface.qml` memilih background dari wallpaper aktif ketika `lock.useWallpaper=true`, atau screencopy desktop jika false; background memakai `MultiEffect` blur. Layout bawaan `Content.qml` masih memuat Weather, Fetch, Media, Center, Resources, dan Notification Dock. `Center.qml` memuat Clock, tanggal/hari, ProfilePic, PasswordInput, dan StateMessage.

Konsekuensi: konfigurasi `shell.json` tidak cukup untuk membentuk layout ini. QML harus berasal dari source tree Caelestia yang benar-benar dipakai Quickshell. Jangan mengedit file paket AUR; upstream secara eksplisit menyarankan instalasi manual/local source untuk modifikasi.

### Implementasi batch 1 — minimal Floating Password Card

**IMPLEMENTED di repository; belum diuji pada perangkat.**

Audit upstream pada revision yang benar-benar terpasang mengonfirmasi bahwa:
- `LockSurface.qml` menyediakan `WlSessionLockSurface`, pemilihan wallpaper aktif melalui `Wallpapers.current`, blur `MultiEffect`, animasi, dan autentikasi PAM.
- `Content.qml` upstream menyusun Weather, Fetch, Media, Center, Resources, dan NotifDock.
- `Center.qml` upstream menyusun Clock, tanggal/hari, ProfilePic, PasswordInput, dan StateMessage.
- `PasswordInput.qml` sudah merupakan `StyledRect` berbentuk kartu dengan field input, indikator autentikasi, tombol submit, dan pengelolaan keyboard focus.
- CMake upstream memasang shell ke `/etc/xdg/quickshell/caelestia`; dokumentasi upstream mendukung konfigurasi Quickshell lokal di `~/.config/quickshell/caelestia`. Karena itu, jangan mengedit file AUR/upstream.

Perubahan repository:
- `config/quickshell/caelestia/modules/lock/Content.qml`: layout hanya satu komponen Center di tengah.
- `config/quickshell/caelestia/modules/lock/Center.qml`: hanya Clock, tanggal/hari, PasswordInput, dan StateMessage.
- `scripts/k41-apply-lockscreen-design.sh`: sekarang mengambil **seluruh source tree upstream** pada revision `d999d4878ee4cec134168e60d913714566a8cfa6`, memverifikasi package `caelestia-shell 2.5.0-1`, menimpa dua QML pada staging, lalu memasang tree lengkap ke `~/.config/quickshell/caelestia`. Script menolak file lokal lain yang tidak dikenal, menyimpan snapshot direktori sebelumnya, dan menyediakan rollback yang menolak menghapus perubahan lokal.
- `tests/test-lockscreen-design.sh`: pemeriksaan struktur QML, Bash syntax, pin upstream, dan guard deployment.

**Koreksi penting atas implementasi batch pertama:** installer sebelumnya hanya menaruh dua file QML di `~/.config/quickshell/caelestia/modules/lock`, tanpa `shell.qml` dan tanpa source tree pendukung. Karena itu Quickshell tidak memiliki konfigurasi lokal lengkap untuk dipilih dan fallback ke `/etc/xdg/quickshell/caelestia/shell.qml`. Restart report membuktikan fallback tersebut. File override pertama tidak pernah menjadi source aktif; itulah sebabnya tampilan tidak berubah. Implementasi awal tersebut tidak berhasil mencapai tujuan dan tidak boleh disebut berhasil.

### Penerapan pada ThinkPad X280

Dari clone repository yang sudah diperbarui, jalankan melalui sudo dari akun desktop yang sedang digunakan:

```bash
sudo bash scripts/k41-apply-lockscreen-design.sh
```

Setiap eksekusi installer otomatis menyimpan seluruh output terminal (stdout dan stderr), timestamp, serta ringkasan exit code ke dalam working tree repository:

```text
reports/lockscreen-apply/<timestamp>-apply.log
```

File report dibuat oleh user desktop yang menjalankan Git, bukan root. Setelah selesai, tinjau report untuk memastikan tidak ada informasi sensitif, lalu masukkan ke commit bersama perubahan yang relevan:

```bash
git add reports/lockscreen-apply/
git status --short
git commit -m "Add lockscreen application report"
git push origin main
```

Jika log menunjukkan kegagalan, jangan anggap instalasi berhasil. Jangan mengedit atau menghapus bukti error sebelum dianalisis; jika perlu, jalankan ulang setelah perbaikan sehingga setiap percobaan memiliki file report tersendiri.

Installer memerlukan `SUDO_USER`. Tahap sudo hanya menyiapkan direktori target dan backup yang dikelola, lalu menurunkan privilege dengan `runuser`; operasi source checkout, backup, dan konfigurasi dilakukan sebagai user desktop. Tidak ada `chown -R` pada parent atau home. Installer mengambil source upstream pada revision yang dipin, tidak menjalankan script remote, dan tidak mengubah file package di `/etc/xdg`. Ia hanya menerima direktori lokal lama yang berisi dua file override buatan installer sebelumnya (atau direktori kosong); jika menemukan file lain, proses berhenti agar tidak menimpa pekerjaan lokal. Setelah deployment, jalankan `caelestia shell -r -d` dari terminal Hyprland aktif sebagai user biasa. Restart report berikutnya **harus** menunjukkan path `~/.config/quickshell/caelestia/shell.qml`; jika masih menunjukkan `/etc/xdg/quickshell/caelestia/shell.qml`, jangan lanjut menguji tampilan.

Rollback juga dijalankan melalui sudo. Perintah ini memulihkan snapshot direktori lokal sebelum deployment, dan menolak rollback jika source tree saat ini memiliki perubahan lokal selain dua override K41:

```bash
sudo bash scripts/k41-apply-lockscreen-design.sh --rollback "/home/<user>/.local/state/k41/lockscreen/backups/<timestamp>"
```

Jangan menjalankan script dengan `sudo -E` dari akun lain atau melalui root login; gunakan akun desktop yang memiliki sesi Caelestia. Jangan menguji lock dengan menyimpan password dalam log atau command line.

### Insiden installer — 2026-11-09

**FAILED sebelum perubahan konfigurasi.** Report `reports/lockscreen-apply/20261109T151425Z-apply.log` mencatat `hostname: command not found` dan exit code `1`. Penyebabnya adalah installer menganggap executable `hostname` sebagai dependency wajib. Pada instalasi Arch minimal, executable tersebut tidak selalu tersedia; pengambilan metadata host tidak seharusnya menjadi syarat untuk menerapkan konfigurasi.

Perbaikan di repository:
- Installer membaca hostname langsung dari `/proc/sys/kernel/hostname`, dengan fallback ke variabel `HOSTNAME` atau nilai `unknown`.
- `hostname` dihapus dari daftar executable wajib.
- Test statis ditambah untuk memastikan metadata host tidak lagi bergantung pada executable opsional tersebut.

Report gagal asli tetap dipertahankan sebagai bukti dan **bukan** bukti instalasi berhasil. Setelah menarik perbaikan, jalankan ulang installer. Setiap percobaan menghasilkan report baru; tinjau report terbaru dan pastikan exit code `0` sebelum menyimpulkan proses instalasi berhasil.

### Audit report penerapan — 2026-11-09 22:17:30 +07:00

Report `reports/lockscreen-apply/20261109T151730Z-apply.log` mencatat:
- File override berhasil disalin ke `~/.config/quickshell/caelestia/modules/lock/`.
- Backup dibuat di `~/.local/state/k41/lockscreen/backups/20261109T151730Z`.
- Installer berakhir dengan exit code `0` (`SUCCESS`).
- Perintah `caelestia shell -r -d` yang dipanggil dari proses installer mengeluarkan sejumlah warning. Karena installer menurunkan privilege melalui `runuser` dan hanya meneruskan `HOME`/XDG variables, proses restart tersebut tidak mewarisi environment sesi desktop secara andal.

Klasifikasi warning:
1. **Environment sesi tidak tersedia:** `HYPRLAND_INSTANCE_SIGNATURE is unset`, gagal menghubungkan Hyprland socket, dan `Failed to create wl_display`. Ini bukti kuat bahwa proses Quickshell yang diluncurkan dari installer tidak memiliki konteks sesi Wayland/Hyprland yang benar.
2. **Efek lanjutan yang mungkin terkait:** kegagalan attached object `WlrLayershell`, `failed to create variant`, dan `QQmlComponent: Component is not ready`. Karena `wl_display` gagal dibuat, jangan menyimpulkan ini sebagai bug QML override sebelum shell dijalankan kembali dari sesi Wayland yang benar.
3. **Integrasi compositor belum terverifikasi:** `hyprland_global_shortcuts_v1` dan `ext-idle-notify-v1` dilaporkan tidak didukung. Warning ini harus diperiksa ulang setelah Quickshell dijalankan dalam sesi aktif; jika tetap muncul, verifikasi compositor/protokol yang benar-benar berjalan dan versi terkait. Jangan menyembunyikan warning atau menambah dependency secara spekulatif.
4. **Notification D-Bus sudah terdaftar:** kemungkinan ada instance shell lain yang masih memiliki nama layanan ketika proses baru diluncurkan. Ini bukan bukti bahwa lock screen berhasil atau gagal; hindari meluncurkan instance kedua dari environment yang salah.

`Configuration Loaded` dan exit code `0` hanya membuktikan command installer/restart berakhir tanpa exit error yang terdeteksi; keduanya **tidak** membuktikan seluruh komponen Wayland berhasil dibuat atau lock screen bekerja. Tidak ada bukti dalam report ini bahwa user telah menguji lock/unlock.

### Perbaikan installer untuk restart

**IMPLEMENTED di repository.** Installer tidak lagi menjalankan `caelestia shell -r -d` dari proses `runuser` yang environment-nya disanitasi. Setelah file override berhasil dipasang, script mencetak instruksi agar restart dijalankan dari terminal sesi desktop aktif sebagai user biasa:

```bash
mkdir -p reports/lockscreen-apply
restart_log="reports/lockscreen-apply/$(date -u +'%Y%m%dT%H%M%SZ')-session-restart.log"
set -o pipefail
caelestia shell -r -d 2>&1 | tee "$restart_log"
printf 'Restart command exit code: %s\n' "$?"
```

Simpan report restart tersebut ke Git setelah meninjau isinya. Jalankan dari terminal dalam sesi Hyprland aktif, tanpa `sudo`; jangan menjalankan command itu dari TTY, SSH, atau proses installer yang kehilangan environment sesi. Ini menjaga agar Quickshell mewarisi environment Wayland/Hyprland dari sesi yang benar. Perbaikan ini tidak mengubah autentikasi, PAM, atau konfigurasi compositor. Test statis juga memastikan installer tidak lagi menjalankan restart dari konteks tersebut.

### Validasi yang harus dilakukan di perangkat

1. Pastikan shell hidup tanpa QML load error setelah restart; periksa `caelestia shell -l`.
2. Tekan shortcut lock Caelestia yang aktif atau jalankan mekanisme lock yang memang sudah digunakan sebelumnya.
3. Pastikan layar terkunci dan menampilkan hanya jam, tanggal/hari, serta kartu password di tengah.
4. Pastikan wallpaper sama dengan desktop dan blur terlihat; tidak ada dashboard, media, resources, profile picture, notification dock, atau panel lain.
5. Uji keyboard focus, password salah (sesi tetap terkunci dan pesan error tampil), lalu password benar (sesi terbuka).
6. Uji screen blank/wake dan lock kembali. Pastikan desktop tidak sempat terlihat sebelum lock aktif dan tidak ada notifikasi/konten sensitif yang bocor.
7. Jika shell gagal dimuat atau layout tidak dapat digunakan, rollback dari TTY atau terminal yang masih dapat diakses. Jangan mengubah PAM sebagai workaround.

Jangan mengklaim visual, autentikasi, atau runtime berhasil sebelum pengujian tersebut dilakukan. `qmllint`/Quickshell load, lock/unlock, wake, dan penilaian visual X280 belum dijalankan dalam sesi implementasi ini.

## Acceptance criteria

- Lock screen dipanggil melalui jalur yang telah diidentifikasi dan benar-benar mengunci sesi.
- Hanya jam, tanggal, hari, dan field password yang tampil sebagai konten utama.
- Wallpaper sama dengan desktop aktif, blur terlihat wajar, dan layout floating sesuai desain C.
- Kartu password terpisah secara visual dari clock/date dan tidak menghalangi input.
- Teks terbaca pada panel X280 dan tidak ada kebocoran desktop/notifikasi sensitif.
- Password benar membuka sesi; password salah tidak membuka sesi dan memberi feedback wajar.
- Keyboard focus/input, transisi lock/unlock, dan fallback berfungsi.
- Fingerprint/Howdy tidak mengalami regresi bila memang aktif pada baseline.
- Tidak ada perubahan PAM/authentication policy yang tidak disetujui.
- Performa dan stabilitas tetap layak pada Intel UHD 620.
- Pengguna menyetujui visual dan interaksi aktual pada perangkat.

## Rollback dan bukti

Simpan backup konfigurasi dan catat perintah pemulihan. Jangan pernah menampilkan atau mengumpulkan password. Bukti cukup berupa versi, konfigurasi non-rahasia, hasil skenario uji, log yang telah disaring, dan konfirmasi pengguna.

## Gate keluar

Status **VERIFIED** memerlukan uji lock/unlock nyata, regression startup/session, dan persetujuan visual pengguna. Hanya setelah pengguna menyatakan custom lock screen berhasil diterima, pembahasan Guest Mode boleh dimulai. Workstream berikutnya adalah [Workstream 3 — Dashboard](03-DASHBOARD.md).

## Collector audit

Jalankan script dari clone repository pada ThinkPad X280 sebagai user desktop biasa, **tanpa sudo**. Script menentukan root repository berdasarkan lokasi file script (bukan direktori terminal saat ini), memvalidasi working tree Git, menolak eksekusi sebagai root, dan memastikan checkout dimiliki UID user yang menjalankan audit. Sebelum menulis, script menolak komponen path laporan yang berupa symlink/non-direktori. Script hanya berjalan pada branch `main`. Setiap run memesan direktori timestamp secara atomik dengan `mkdir`, sehingga dua proses bersamaan tidak menimpa laporan satu sama lain. File laporan dibuat baru tanpa overwrite. Script tidak mengubah umask, permission, ownership, Git index, branch, atau HEAD. Perintah commit yang dicetak memakai `git commit --only` agar file lain yang kebetulan sudah staged tidak ikut ter-commit:

```bash
bash scripts/k41-lockscreen-audit.sh
```

### Insiden permission collector — kebijakan wajib

**REGRESSION DITEMUKAN DAN DIPERBAIKI.** Versi collector sebelumnya memakai `umask 077`, `chmod 0700` pada direktori laporan, `chmod 0600` pada file laporan, serta jalur `sudo` dengan `chown`. Walaupun dimaksudkan untuk membatasi akses laporan, perubahan mode dan ownership tersebut mengubah metadata filesystem di dalam working tree dan dapat menghambat akses/pengelolaan artefak audit saat pengguna meninjau atau melakukan Git add/commit/push. Pengguna melaporkan gangguan push setelah menjalankan collector; insiden ini dicatat sebagai regresi yang menjadi tanggung jawab perubahan script.

Mulai versi perbaikan:
- **Dilarang menjalankan collector dengan sudo/root.** Script menolak EUID 0 sebelum membuat laporan.
- Collector **tidak boleh menjalankan `chmod`, `chown`, `install -o/-g`, `umask` khusus, atau operasi lain yang mengubah permission/ownership** pada working tree maupun artefak.
- Direktori dan file laporan dibuat sebagai user pemilik checkout dengan permission default yang ditentukan oleh umask sesi pengguna; collector tidak memaksakan mode.
- Jangan memakai alasan keamanan laporan untuk mengubah permission repository. Jika laporan mengandung data sensitif, redaksi kontennya sebelum commit; jangan mengunci akses filesystem sebagai pengganti redaksi.
- Perubahan ini tidak memperbaiki permission yang mungkin sudah terlanjur berubah dari run sebelumnya. Sebelum melakukan pemulihan, periksa owner/mode target secara spesifik; jangan menjalankan `chmod -R` atau `chown -R` pada repository.

Ini adalah acceptance invariant untuk collector berikutnya: **audit tidak mengubah permission atau ownership, dan seluruh artefak dibuat oleh user biasa yang menjalankan Git.**

Script juga dapat dipanggil melalui path absolut dari direktori lain. Ini penting: proses script tidak dapat mengubah direktori kerja terminal induk. Karena itu, menjalankan `git add` atau `git push` biasa setelah memanggil script melalui path absolut dari luar clone akan menghasilkan `fatal: not a git repository`. Versi collector ini menghindari masalah tersebut dengan mencetak perintah Git memakai opsi `git -C <repo_root>`; jalankan perintah yang dicetak script setelah meninjau dan menyunting laporan.

Jika sebelumnya sudah ada commit laporan lokal dan `main` di GitHub menerima commit baru, sinkronkan dahulu dari direktori mana pun dengan:

```bash
git -C "/path/ke/clone" fetch origin
git -C "/path/ke/clone" rebase origin/main
```

Ganti `/path/ke/clone` dengan path repository yang dicetak oleh script. Jangan gunakan `git push --force`. Jika rebase berhenti karena konflik, jangan push; simpan pesan error untuk ditinjau. Pada sesi berikutnya, gunakan `git -C "/path/ke/clone" fetch origin` lalu `git -C "/path/ke/clone" merge --ff-only origin/main` sebelum mulai bekerja.

Laporan disimpan di `reports/lockscreen-audit/<timestamp>/audit.txt`, dibuat oleh user yang menjalankan collector dengan permission default sesi. Collector tidak mengubah branch, HEAD, index, permission, ownership, konfigurasi, service, package, PAM, atau autentikasi. Walaupun collector menghindari username dan credential, periksa laporan sebelum push karena dapat memuat versi kernel/package, model monitor, binding, nama file konfigurasi, dan nama modul PAM. Output statis tidak membuktikan perilaku runtime atau visual; skenario manual tetap wajib.

## Laporan restart sesi Caelestia

Untuk mengumpulkan bukti restart dari lingkungan Wayland/Hyprland yang benar, gunakan collector terpisah berikut sebagai user desktop biasa dari clone repository (tanpa sudo):

```bash
bash scripts/k41-report-lockscreen-session.sh
```

Collector memvalidasi `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, keberadaan perintah `caelestia`, dan socket Wayland. Collector kemudian menjalankan `caelestia shell -r -d` pada sesi aktif dan menyimpan stdout/stderr serta exit code ke `reports/lockscreen-apply/<timestamp>-session-restart.log`. Nilai environment yang berpotensi sensitif tidak dicetak; hanya status keberadaan signature Hyprland yang dicatat. Collector tidak menggunakan sudo, tidak mengubah permission/ownership, tidak mengubah Git index/branch/HEAD, dan tidak melakukan commit atau push. Permission file mengikuti umask user saat menjalankan script.

Setelah script selesai, tinjau laporan dan redaksi informasi personal bila diperlukan. Lalu dari root repository:

```bash
git status --short
git add reports/lockscreen-apply/
git commit -m "Add lockscreen session restart report"
git push origin main
```

Jika Git menolak push karena remote memiliki commit baru, jangan force-push. Sinkronkan dengan `git pull --ff-only origin main` bila working tree bersih dan branch dapat fast-forward; jika ada commit lokal yang belum ada di remote, hentikan dan kirim pesan error/status untuk ditinjau. Setelah laporan berhasil di-push, asisten dapat memeriksa laporan langsung dari `main`.

Exit code 0 hanya membuktikan perintah restart selesai tanpa error yang dilaporkan proses. Itu **belum** membuktikan lock screen tampil benar atau lock/unlock aman; verifikasi visual dan fungsional tetap dilakukan pada ThinkPad X280.


## Koreksi akar masalah deployment — 2026-11-09

**ROOT CAUSE TERIDENTIFIKASI:** report restart `20261109T152417Z-session-restart.log` secara eksplisit menyatakan Quickshell meluncurkan `/etc/xdg/quickshell/caelestia/shell.qml`. Direktori lokal sebelumnya hanya memiliki dua file di `modules/lock`, tidak memiliki `shell.qml` dan tidak memiliki seluruh komponen QML yang diperlukan. Quickshell karena itu tetap menjalankan konfigurasi package system; perubahan K41 tidak pernah dimuat. Exit code restart 0 dan `Configuration Loaded` hanya mengonfirmasi shell system berhasil dimuat, bukan override K41.

### Perbaikan deployment

Upstream README menyatakan jangan mengedit file yang dipasang paket AUR untuk kustomisasi; metode manual adalah menyediakan source tree Caelestia di `$XDG_CONFIG_HOME/quickshell/caelestia`. Installer K41 sekarang mengikuti model itu: fetch revision upstream yang sama dengan baseline perangkat, verifikasi SHA dan versi package, salin dua override K41 ke tree staging, lalu pasang tree lengkap di lokasi user config. Package files di `/etc/xdg` tidak diubah. Referensi: [upstream installation instructions](https://github.com/caelestia-dots/shell#manual-installation).

### Urutan eksekusi baru

```bash
git pull --ff-only origin main
sudo bash scripts/k41-apply-lockscreen-design.sh
```

Setujui prompt hanya setelah report menunjukkan revision dan package version yang sesuai. Setelah installer exit 0, dari terminal Hyprland aktif (tanpa sudo):

```bash
bash scripts/k41-report-lockscreen-session.sh
```

Periksa report restart. **Path shell yang benar adalah** `/home/<user>/.config/quickshell/caelestia/shell.qml` (home user aktual), bukan `/etc/xdg/quickshell/caelestia/shell.qml`. Jangan menganggap desain diterapkan sampai path lokal terkonfirmasi dan lock screen benar-benar memuatnya.

Rollback menggunakan path backup yang dicetak installer:

```bash
sudo bash scripts/k41-apply-lockscreen-design.sh --rollback "/home/<user>/.local/state/k41/lockscreen/backups/<timestamp>"
```

### Batas validasi

Perubahan installer, source pin, dan static tests telah **IMPLEMENTED di GitHub**. Belum ada bukti installer baru dijalankan pada X280, QML dimuat dari source lokal, lock/unlock berhasil, atau visual memenuhi desain. Tes runtime dan validasi visual tetap **NOT TESTED / NOT VERIFIED**.


## Audit permission deployment terbaru — 2026-11-09

Report terbaru menunjukkan installer berhenti dengan `Existing managed directory has unexpected owner` pada `~/.config/quickshell/caelestia`. Jangan menebak owner yang benar dan jangan menjalankan `chown -R`. Collector read-only baru ditambahkan untuk mengumpulkan:
- UID/GID/mode setiap direktori terkait dari home sampai target dan backup;
- path traversal dan symlink melalui `namei -l`;
- ACL jika `getfacl` tersedia;
- inventory metadata/path tree konfigurasi lokal dan backup;
- keberadaan `shell.qml` lokal dibanding entry point package di `/etc/xdg`;
- versi package dan metadata Git source lokal;
- ringkasan report installer sebelumnya.

Collector tidak memperbaiki apa pun, tidak mengubah permission/ownership, tidak memanggil sudo, tidak mengubah package/service/PAM, dan tidak mengubah Git state. Ia hanya membuat report baru di repository.

Jalankan setelah pull, dari sesi user desktop biasa:

```bash
bash scripts/k41-report-lockscreen-permissions.sh
```

Script akan mencetak perintah `git -C ...` untuk menambahkan hanya report baru, memeriksa staged diff, commit hanya file report tersebut, dan push ke `main`. Ikuti perintah yang dicetak setelah meninjau report. Tidak perlu menjalankan command diagnostik manual atau mengirim screenshot.

Setelah report masuk ke GitHub, audit metadata tersebut terlebih dahulu. Baru setelah penyebab ownership/ACL/path terbukti, perbaiki installer secara sempit dan aman. Tidak ada permission yang boleh diubah berdasarkan dugaan.


## Update implementasi terbaru — 2026-11-09

Bagian ini mencatat keadaan repository setelah perubahan layout terbaru. Catatan insiden dan laporan historis di atas tetap dipertahankan sebagai histori; status terkini di bawah ini yang menjadi acuan untuk implementasi pada `main`.

### Perubahan yang sudah diimplementasikan

- `config/quickshell/caelestia/modules/lock/LockSurface.qml`: surface/card besar di belakang seluruh konten dibuat transparan sehingga tidak membentuk panel pembungkus; wallpaper dan efek blur upstream tetap menjadi latar. Jalur session-lock dan autentikasi upstream tidak dimaksudkan untuk diubah.
- `config/quickshell/caelestia/modules/lock/center/PasswordInput.qml`: field password tetap mempertahankan surface rounded miliknya sendiri; transparansi surface luar tidak menghilangkan kartu input tersebut.
- `config/quickshell/caelestia/modules/lock/Content.qml`: komponen `Center` mengisi seluruh area konten yang diberikan parent melalui `anchors.fill: parent`.
- `config/quickshell/caelestia/modules/lock/Center.qml`: root menjadi area `Item` penuh; `ColumnLayout` yang berisi clock, tanggal, password, dan pesan state diposisikan dengan `anchors.centerIn: parent`.
- `scripts/k41-apply-lockscreen-design.sh`: installer mengirimkan override ke source tree Caelestia lokal dengan mekanisme backup/rollback dan validasi versi/revision upstream. Ikuti instruksi installer yang berlaku di repository; restart shell harus dilakukan dari terminal sesi Hyprland aktif sebagai user biasa.

### Commit terkait

- `35d924ad2de25c858389961c8eac3b255d13ed46` — membuat konten lock screen mengisi area parent yang tersedia.
- `5851a5b5ef90621f460e5541aecd44ad2fc96e7b` — memusatkan kelompok konten secara geometris di dalam area tersebut.
- Perubahan pendukung sebelumnya: `0d3f80d` (password surface rounded), `e2df3cc` (outer surface transparan), `f75a8e4` (installer deploy LockSurface override), dan `1bb8ba1` (deduplikasi pemeriksaan sumber installer).

### Status validasi

- **IMPLEMENTED:** perubahan QML dan installer ada pada branch `main`.
- **NOT TESTED:** belum ada hasil `qmllint`, validasi parser QML, atau runtime Quickshell untuk perubahan layout terakhir.
- **NOT VERIFIED:** belum ada bukti perangkat bahwa source tree lokal terbaru aktif, seluruh elemen benar-benar berada di tengah layar, password field tampil terpisah, autentikasi benar/salah berfungsi, wake/resume aman, dan tampilan diterima pengguna.
- Restart command exit 0 atau log `Configuration Loaded` saja tidak cukup untuk mengubah status menjadi VERIFIED.

### Langkah penerapan dan penerimaan berikutnya

Dari clone repository yang sudah diperbarui:

```bash
git pull --ff-only origin main
sudo bash scripts/k41-apply-lockscreen-design.sh
```

Setelah installer selesai, jalankan restart dari terminal Hyprland aktif sebagai user biasa atau gunakan collector sesi yang didokumentasikan di atas. Pastikan report restart menunjukkan source tree lokal `~/.config/quickshell/caelestia/shell.qml`, bukan fallback `/etc/xdg/quickshell/caelestia/shell.qml`. Kemudian lakukan seluruh skenario pada bagian **Validasi yang harus dilakukan di perangkat** dan acceptance criteria. Tidak perlu mengirim screenshot; review visual dilakukan langsung pada display X280.

### Guest Mode — BELUM DIIMPLEMENTASIKAN

Guest Mode **belum memiliki implementasi**. Statusnya **NOT IMPLEMENTED / DEFERRED**, bukan fitur aktif, bukan fitur yang sudah diuji, dan bukan bagian dari acceptance lock screen saat ini. Jangan membuat desain, akun guest, session workflow, atau perubahan permission/policy terkait Guest Mode sampai pengguna secara eksplisit menyatakan custom lock screen telah diterima. Setelah persetujuan tersebut, Guest Mode harus diaudit dan dirancang sebagai workstream terpisah dengan batas keamanan, isolasi data, persistence, dan cleanup yang jelas.
