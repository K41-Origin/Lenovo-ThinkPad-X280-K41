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

Konsekuensi: konfigurasi `shell.json` yang terlihat pada laporan dapat mengaktifkan wallpaper dan menyembunyikan notifikasi, tetapi tidak menyediakan kontrol konfigurasi yang cukup untuk menghapus seluruh widget samping/profile picture dan membentuk Floating Password Card sesuai desain C. Perubahan QML terarah kemungkinan diperlukan. Jangan edit file paket AUR langsung; gunakan mekanisme override/local Quickshell config yang sesuai setelah lokasi file paket dan jalur startup aktual dipastikan.

### Status analisis

**ANALYZE — PARTIALLY COMPLETED.** Belum ada perubahan visual, autentikasi, PAM, atau startup. Langkah berikutnya adalah melengkapi collector agar menemukan instance Hyprland melalui `hyprctl instances` (bukan mengandalkan environment marker dari `/proc`), menginventarisasi lokasi file QML paket, dan memastikan apakah startup Caelestia berasal dari konfigurasi Hyprland atau mekanisme opsional autologin. Setelah itu baru siapkan override QML minimal beserta backup/rollback.

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