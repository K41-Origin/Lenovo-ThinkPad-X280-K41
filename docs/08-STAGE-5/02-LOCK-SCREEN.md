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

Jalankan dari terminal dalam sesi Hyprland sebagai user biasa (tanpa sudo):

```bash
bash scripts/k41-lockscreen-audit.sh
```

Laporan dibuat di `~/.local/state/k41/lockscreen-audit/<timestamp>/audit.txt` dengan permission direktori/file privat. Collector read-only; ia tidak mengubah konfigurasi, service, package, PAM, atau autentikasi. Output statis tidak membuktikan perilaku runtime atau visual; skenario manual tetap wajib.
