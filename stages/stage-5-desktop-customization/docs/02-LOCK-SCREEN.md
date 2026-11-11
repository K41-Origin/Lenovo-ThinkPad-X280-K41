# Workstream 02 — Lock Screen

**Status desain: COMPLETED / USER ACCEPTED.** Tampilan Lock Screen dengan konsep Floating Password Card sudah disetujui pengguna. **Status operasional: BLOCKED — startup failure terbukti berasal dari lock-readiness handoff yang tidak selesai; penyebab internal Caelestia/helper/QML masih diselidiki.** Pekerjaan berikutnya bukan redesign: tujuannya mengaudit, mengambil, dan memisahkan source tampilan yang sudah disetujui, lalu memigrasikannya menjadi modul visual langsung di workstream Stage 5.

**Status audit visual: COMPLETED FOR SOURCE EXTRACTION. Status source dan automatic deployment/reload: IMPLEMENTED. Status runtime rendering: NOT VERIFIED pada ThinkPad X280.** Source visual Floating Password Card berada langsung di `workstreams/02-lock-screen/modules/lockscreen/`; tidak ada subproject terpisah.

## Tujuan dan batas scope

- Pertahankan tampilan Lock Screen yang saat ini telah disetujui. Jangan mengubah desain, layout, warna, typography, animasi, atau perilaku visual tanpa persetujuan baru.
- Identifikasi dan ambil hanya source visual serta resource yang benar-benar diperlukan.
- Pisahkan ownership source K41 dari source upstream Caelestia.
- Pertahankan Caelestia sebagai host/runtime selama belum ada keputusan arsitektur baru.
- Jangan mengubah autentikasi, PAM, password handling, fingerprint/Howdy policy, atau session-lock protocol sebagai bagian dari pekerjaan visual.

Detail bahasa visual lintas-komponen: [Design System](../../../docs/07-DESKTOP-DESIGN-SYSTEM.md).

## Protokol kolaborasi

Pengguna menetapkan batas partisipasi: **pengguna tidak ingin melakukan pekerjaan teknis selain `git pull` dan `git push`.**

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Audit repository dan upstream; membuat serta memelihara script audit, ekstraksi/penyiapan, migrasi, implementasi, test, dan dokumentasi; memeriksa perubahan repository dan melaporkan bukti serta keterbatasannya. |
| Pengguna | Hanya melakukan `git pull` dan `git push` untuk sinkronisasi perubahan sesuai alur yang disepakati. Tidak diminta mengedit file, menulis kode, menjalankan perintah manual, atau mengubah konfigurasi secara manual. |

**Batasan eksekusi:** pull/push Git tidak menjalankan script dan tidak membuktikan perilaku runtime pada laptop. Karena pengguna membatasi aktivitasnya pada pull/push, rancangan alur otomatisasi harus memperhitungkan cara menjalankan dan mengumpulkan hasil pengujian tanpa membebankan langkah manual tambahan. Jangan mengklaim test lokal, deployment, atau runtime berhasil sebelum ada bukti nyata. Jika suatu validasi tidak dapat dilakukan dalam batasan ini, laporkan sebagai BLOCKED/NOT VERIFIED dan jelaskan alasan teknisnya; jangan diam-diam mengubah pembagian tanggung jawab.

## Urutan pengerjaan wajib

1. **Audit visual read-only — COMPLETED.** Audit source visual pada report 20261110T192941Z telah menyediakan source QML, dependency visual, aset, dan konfigurasi terpilih. Report mengandung satu file di luar scope; file itu tidak dipakai sebagai input implementasi. Screenshot/runtime capture belum tersedia.
2. **Audit dependency dan batas ownership — PARTIAL.** Dependency statis yang tampak pada QML dicatat di `workstreams/02-lock-screen/modules/lockscreen/README.md`. Kelengkapan dependency runtime masih menunggu pemeriksaan setelah modul dipasang.
3. **Ekstraksi source terpilih — IMPLEMENTED.** Empat file QML visual tersedia langsung di `workstreams/02-lock-screen/modules/lockscreen/`.
4. **Struktur modul visual Stage 5 — IMPLEMENTED.** Struktur dan kontrak komponen didokumentasikan di `workstreams/02-lock-screen/modules/lockscreen/README.md`; host integration dan runtime masih belum diverifikasi.
5. **Automatic deployment, aktivasi, dan persistent log — IMPLEMENTED.** Script tunggal `workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh` tanpa opsi CLI melakukan preflight, backup empat file, staging, verifikasi, penggantian source visual di `~/.config/quickshell/caelestia/modules/lock/`, lalu memanggil `caelestia shell -r -d`. Seluruh output standar/error dan kegagalan command dicatat secara lokal ke `~/.local/state/k41/lockscreen/deployment-logs/history/deploy-<timestamp>-<pid>.log`; salinan terbaru lokal tersedia di `latest.log`. Setelah deployment selesai, script membuat worktree Git terisolasi, menyalin log yang telah menyamarkan prefix home directory, lalu commit dan push **hanya** `reports/lockscreen-deployment/` ke branch `main`. Upload memakai kredensial Git yang sudah tersedia untuk repository; tidak memerlukan PAT/token baru dan tidak menyentuh perubahan lain di working tree. Log publik di GitHub tersedia pada `reports/lockscreen-deployment/history/` dan `reports/lockscreen-deployment/latest.log`. Log lokal memakai permission user-only (0600), log yang dipublikasikan 0644, dan keduanya mencakup preflight, backup, deployment, reload, rollback, serta exit status. Script menolak source tree/revision yang tidak sesuai, symlink, ownership yang tidak aman, atau perubahan lokal pada target; kegagalan deployment/reload memulihkan file dari backup. Jalankan dari root checkout sebagai user desktop biasa dalam sesi Hyprland aktif:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh
```

Log lokal disimpan di direktori state user, bukan working tree. Script memublikasikan salinan tersanitasi secara otomatis ke GitHub melalui worktree terpisah dan push non-force ke `main`; hanya direktori report deployment yang masuk commit. Bila fetch/push gagal atau origin tidak cocok, deployment log tetap tersimpan lokal dan script mengembalikan status gagal agar upload tidak terlewat. Tidak ada PAT/token baru yang diminta; upload bergantung pada kredensial Git yang sudah digunakan untuk push repository. Script tidak membuat partial config overlay, tidak mengubah `shell.qml`, `Lock.qml`, `Pam.qml`, `InputField.qml`, PAM/authentication, session-lock protocol, keybind, Hyprland config, maupun system services. Tidak ada opsi `--install`, `--status`, atau `--rollback`.
6. **Static/isolated testing — IMPLEMENTED; runtime — NOT VERIFIED.** Test fixture memeriksa provenance guard, backup, penggantian empat file visual, dan pemanggilan reload. QML rendering, lock/unlock, password salah, wake/resume, dan penerimaan visual hanya boleh dinyatakan VERIFIED setelah diuji pada X280.
7. **Audit pascamigrasi.** Pastikan modul K41 tidak lagi bergantung pada source visual Caelestia yang akan dibersihkan, sementara dependency upstream yang masih diperlukan tetap tersedia dan tercatat.
8. **Cleanup source visual upstream.** Hanya setelah migrasi terbukti berfungsi dan pengguna menerima hasilnya, identifikasi serta hapus source visual upstream yang sudah tidak digunakan. Cleanup harus sempit, berdasarkan dependency graph, dan memiliki rencana rollback. Jangan menghapus komponen autentikasi atau dependency bersama.
9. **Penerimaan.** Hasil akhir harus mempertahankan desain yang disetujui dan memenuhi acceptance di bawah.

Setiap tahap menghasilkan artefak dan bukti yang dapat ditinjau sebelum tahap berikutnya. Jangan melewati audit atau menggabungkan audit read-only dengan operasi tulis.

## Struktur runtime tujuan

```text
~/.config/quickshell/caelestia/
└── modules/lock/                 # host/runtime; empat file visual diganti oleh deployment Stage 5
```

Source visual berada langsung di workstream `workstreams/02-lock-screen/modules/lockscreen/`; tidak ada subproject atau namespace `K41-dots`.

## Kondisi repository saat ini

Implementasi saat ini:
- Source visual K41: `workstreams/02-lock-screen/modules/lockscreen/`.
- Satu-satunya script deployment: `workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh`.
- Persistent deployment logs lokal: `~/.local/state/k41/lockscreen/deployment-logs/`; salinan tersanitasi otomatis dipublikasikan ke `reports/lockscreen-deployment/history/` dan `reports/lockscreen-deployment/latest.log` pada branch `main`.
- Target aktif: `~/.config/quickshell/caelestia/modules/lock/`.
- Installer interaktif lama `k41-apply-lockscreen-design.sh` telah dihapus. Tidak ada jalur deployment alternatif atau opsi CLI.

## Script audit visual baru

Script khusus audit visual telah ditambahkan:

`workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh`

Jalankan dari checkout repository pada ThinkPad X280 sebagai user desktop biasa (tanpa sudo):

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh
```

Script menghasilkan direktori laporan bertimestamp di `reports/lockscreen-visual-audit/`. Laporan mencakup metadata host/session, versi dan provenance package/source Caelestia, inventory serta SHA-256 file terkait, source QML/JS lock yang ditemukan, teks source visual legacy/upstream terpilih, aset visual, referensi/import/resource, resolusi dependency QML lokal secara rekursif, field konfigurasi lock/wallpaper terpilih, user systemd units, identitas executable proses tanpa command-line/environment, serta metadata integrasi Hyprland/PAM tanpa mengambil isi lengkap file PAM. Filter keybind Hyprland menghindari properti generik `locked` agar tidak salah mengumpulkan seluruh keybind.

Audit tidak melakukan deployment, cleanup, perubahan konfigurasi, instalasi package, restart service, atau perubahan autentikasi. Binary asset dicatat melalui path/ukuran/hash, bukan disalin ke log. Report dapat memuat source custom dan metadata host; periksa/redaksi sebelum dipublikasikan. `.gitignore` saat ini tidak mengecualikan `reports/`; laporan baru dapat ikut di-commit/push bila di-stage. Jangan publikasikan sebelum review privasi dan kepemilikan source.

Script mengandalkan path umum Caelestia. Jika instalasi menggunakan source root nonstandar, hasil audit akan menunjukkan root yang tidak ditemukan; jangan menganggap inventory lengkap sampai path aktual diketahui.

## Artefak audit terdahulu

Script berikut sudah ada di repository dan perlu diperiksa sebelum digunakan atau diganti:
- `workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh`

Keberadaan script tidak membuktikan audit terbaru sudah dilakukan. Audit baru harus memverifikasi source/revision Caelestia yang benar-benar digunakan dan berfokus pada tampilan serta dependency terkait. Audit bersifat read-only dan harus menghasilkan laporan yang dapat ditinjau.

## Acceptance criteria

- Tampilan hasil migrasi tetap sesuai desain Lock Screen yang telah disetujui; tidak ada perubahan visual tanpa persetujuan.
- Source visual K41 dikelola di Stage 5 dan dideploy ke empat file visual pada modul lock Caelestia; source/runtime dan dependency upstream lain tetap dipertahankan.
- Seluruh file, aset, dependency, konfigurasi, dan titik integrasi yang diperlukan telah diidentifikasi.
- Tidak ada dependency tersembunyi pada source visual upstream yang dihapus.
- PAM, autentikasi, password handling, fingerprint/Howdy policy, dan session-lock protocol tidak diubah oleh migrasi visual.
- Script audit read-only; script migrasi/implementasi terpisah, aman, dapat diulang, dan menyediakan backup/recovery.
- Pemeriksaan statis/otomatis lulus sesuai cakupan yang dilaporkan.
- Runtime dan perilaku pada ThinkPad X280 hanya dinyatakan VERIFIED setelah ada bukti pengujian aktual.
- Pengguna menerima hasil akhir.

Screenshot bukan acceptance gate.

## Status Guest Mode

Guest Mode (ID 03) **NOT IMPLEMENTED / DEFERRED** dan bukan bagian dari scope atau acceptance Lock Screen.


## Desktop startup regression — temuan audit X280 11 November 2026

Report aktual: `reports/stage-5-desktop-customization/02-lock-screen/startup-audits/20261111T070139Z/report.txt`.

### Fakta yang sudah VERIFIED

1. Hyprland session mencapai target sekitar 19 detik setelah boot; `xdg-desktop-portal-hyprland` berhasil terhubung ke Wayland.
2. Pada sekitar 91.58 detik, journal mencatat: `Lock screen did not become ready within 75s; stopping tty1 autologin and releasing Plymouth.`
3. `getty@tty1.service` dihentikan, `getty@tty2.service` dimulai, dan Hyprland session berhenti sekitar 101.87 detik.
4. Perpindahan ke TTY2 merupakan akibat langsung dari fail-safe timeout Workstream 01. Pemicu timeout adalah tidak adanya readiness marker dari jalur Caelestia lock.
5. Percobaan manual `start-hyprland` dari TTY2 kemudian core-dump dengan `std::system_error: Resource deadlock avoided`. Kejadian ini muncul setelah fallback dan bukan bukti penyebab awal boot gagal.

### Defect source-level ditemukan

Source helper lama memiliki nested retry yang tidak dibatasi oleh timeout total:
- Outer loop: hingga 45 percobaan menunggu/menjalankan lock IPC.
- Setiap kali IPC siap dan perintah lock diterima, inner loop melakukan hingga 10 percobaan verifikasi `isLocked`, dengan jeda 1 detik.
- Jika perintah lock sukses tetapi status `isLocked` tidak pernah menjadi true, helper mengulang inner loop pada setiap iterasi outer loop. Durasi teoretisnya dapat mencapai sekitar 45 × 11 detik = 495 detik, jauh melewati timeout handoff Plymouth 75 detik.

Ini adalah bug logika yang nyata pada source helper lama dan kandidat kuat penyebab marker tidak pernah terbit sebelum timeout. Namun, report pertama tidak mengumpulkan isi/hash helper yang terpasang; ukuran file lokal 2527 byte berbeda dari source lama repository 2152 byte. Karena itu belum terbukti bahwa branch nested-loop tersebut persis yang dieksekusi di perangkat.

### Perbaikan yang sudah diimplementasikan

1. Ownership helper lock dipindahkan dari Workstream 01 ke Workstream 02: `workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh`. Installer autologin Workstream 01 sekarang mengambil helper dari lokasi Workstream 02; Workstream 01 tetap hanya menyediakan handoff marker consumer dan Plymouth lifecycle.
2. Retry logic diperbaiki: discovery Caelestia IPC memakai deadline total 30 detik; lock request dilakukan satu kali; verifikasi `isLocked` dibatasi hingga 10 percobaan. Bila tidak terverifikasi, helper segera mencoba Hyprlock fallback, bukan mengulang inner verification sampai ratusan detik.
3. Setiap pemanggilan helper menulis log privat di `~/.local/state/k41/lockscreen/startup-<timestamp>-<pid>.log`. Audit startup mengambil log tersebut.
4. Script `workstreams/02-lock-screen/scripts/k41-update-lockscreen-startup-helper.sh` dibuat untuk memperbarui helper yang sudah terpasang pada `~/.local/bin/`. Script membuat backup file lama di `~/.local/state/k41/lockscreen/helper-backups/`, memvalidasi source, melakukan penggantian atomik, dan membandingkan hasil. Ia tidak memakai sudo dan tidak mengubah systemd, Plymouth, getty, PAM, autentikasi, package, bootloader, atau initramfs.
5. Test baru `tests/test-lockscreen-startup-helper.sh` menguji timeout bounded, verifikasi lock, fallback, fail-closed, backup updater, dan penolakan symlink.

### Bukti lain yang masih perlu diperiksa

- `hyprland.lua` pada report memuat sisa directive `qs -c k41-boot-splash`. Ini tidak sesuai keputusan proyek bahwa Plymouth satu-satunya boot splash. Source QML legacy tidak ada di branch aktif; directive runtime harus dibersihkan secara terkontrol setelah konfigurasi aktual ditinjau. Jangan menganggapnya root cause.
- Empat file QML runtime belum dibuktikan byte-identical dengan source. Audit berikutnya membandingkan checksum.
- Report lama tidak memiliki log Quickshell/Caelestia yang cukup. Audit baru mengumpulkan helper terpasang, backup helper lama, log startup, QML comparison, dan coredump metadata.
- `start-hyprland` versi 0.57.1 menghasilkan abort `Resource deadlock avoided` pada percobaan manual. Upstream merilis 0.57.2 pada 9 November 2026 dengan beberapa perbaikan, termasuk penanganan child process yang dihentikan signal. Ini kandidat perbaikan crash sekunder, bukan bukti penyebab lock timeout.

Referensi upstream: https://github.com/hyprwm/Hyprland/releases/tag/v0.57.2

### Langkah perangkat berikutnya

Setelah perubahan repository ditarik ke X280, jalankan satu updater berikut dari TTY2 sebagai user biasa (tanpa sudo):

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-update-lockscreen-startup-helper.sh
```

Updater akan menyimpan helper lama sebelum menggantinya. Setelah updater berhasil, reboot dan amati apakah desktop masuk ke lock screen Caelestia. Jika masih masuk TTY2, jalankan collector read-only berikut dari TTY2; report dipublikasikan otomatis ke GitHub:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh
```

Jangan deploy ulang visual Lock Screen atau membersihkan source upstream sebelum jalur lock readiness terbukti berfungsi. Jangan mengubah PAM, password handling, fingerprint/Howdy policy, session-lock protocol, atau Plymouth untuk mengatasi bug timeout ini.

### Batas status

- Desain Floating Password Card: **COMPLETED / USER ACCEPTED**.
- Empat file source visual: **IMPLEMENTED**; runtime rendering **NOT VERIFIED**.
- Deployment visual dan isolated fixture: **IMPLEMENTED / STATIC TESTED** sesuai cakupan CI.
- TTY2 fallback karena readiness timeout: **VERIFIED**.
- Nested retry/verification timeout bug pada source helper lama: **IDENTIFIED**.
- Bounded lock helper, updater, dan regression tests: **IMPLEMENTED; CI/runtime validation pending**.
- Penyebab runtime final pada helper yang sebelumnya terpasang: **STRONG CANDIDATE; DEVICE CONFIRMATION PENDING**.
- Visual deployment lanjutan dan cleanup source upstream: **PAUSED** sampai lock path pulih.
