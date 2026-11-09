# Workstream 2 — Lock Screen

## Tujuan

Menyempurnakan tampilan dan alur interaksi lock screen agar sederhana, mudah dibaca, konsisten dengan arah K41, serta tetap aman dan dapat dipulihkan.

## Batas

Termasuk layout, jam/tanggal, wallpaper khusus lock screen bila diperlukan, prompt, indikator status, feedback autentikasi, notifikasi saat terkunci, keyboard/focus behavior, dan transisi lock/unlock.

Tidak termasuk redesign global wallpaper/typography/iconography, perubahan PAM atau kebijakan autentikasi, perubahan password, LUKS, TPM, atau penggantian arsitektur shell.

## Prosedur

1. Audit lock mechanism yang aktif, executable dan versi, konfigurasi Hyprland/Caelestia/Hyprlock, PAM stack yang dipakai (read-only), proses, keybind, startup ordering, dan fallback.
2. Verifikasi jalur lock yang benar-benar digunakan; jangan menyimpulkan hanya dari keberadaan file konfigurasi.
3. Uji kondisi awal: lock manual, lock setelah startup bila berlaku, screen blank/wake, salah password, password benar, dan sesi yang terkunci saat komponen shell restart.
4. Catat perilaku aktual dan masalah visual/fungsional sebelum mengubah apa pun.
5. Buat backup; implementasikan perubahan tampilan kecil yang tidak mengubah autentikasi.
6. Uji keyboard navigation, input password, focus, feedback, dan transisi unlock. Pastikan tidak ada kebocoran desktop sebelum status locked terkonfirmasi.
7. Uji fallback/recovery yang telah tersedia tanpa mengubah PAM atau kredensial.

## Acceptance criteria

- Lock screen dapat dipanggil melalui jalur yang ditetapkan dan benar-benar mengunci sesi.
- Tampilan terbaca pada panel X280 dan tidak mengungkap konten desktop ketika terkunci.
- Password benar membuka sesi; password salah tidak membuka sesi dan memberikan feedback yang wajar.
- Fokus keyboard/input bekerja; tidak ada dialog atau notifikasi sensitif yang bocor.
- Jalur fallback yang ada tetap berfungsi.
- Tidak ada perubahan PAM/authentication policy yang tidak disetujui.
- Pengguna mengonfirmasi visual dan interaksi langsung pada perangkat.

## Rollback dan bukti

Simpan backup konfigurasi dan catat cara mengembalikan konfigurasi sebelumnya. Jangan pernah menampilkan atau mengumpulkan password. Bukti cukup berupa versi, konfigurasi non-rahasia, hasil skenario uji, log yang telah disaring, dan konfirmasi pengguna.

## Gate keluar

Status VERIFIED memerlukan uji lock/unlock nyata dan regression startup/session. Setelah diterima, lanjutkan ke [Workstream 3 — Dashboard](03-DASHBOARD.md).