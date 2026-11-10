# Workstream 06 — Launcher

## Tujuan

Menetapkan satu launcher utama yang cepat, keyboard-first, mudah diprediksi, dan tidak menduplikasi fungsi pencarian atau menu lain.

## Batas

Termasuk launcher utama, keybind, pencarian aplikasi, hasil, kategori/action yang benar-benar didukung, navigasi keyboard, command execution safety, dan fallback.

Tidak termasuk redesign global typography/iconography atau penambahan launcher kedua untuk fungsi yang sama.

## Prosedur

1. Audit executable dan package launcher yang terpasang, versi, konfigurasi aktif, keybind Hyprland, desktop entries, environment/session, dan launcher lain yang berjalan.
2. Pastikan launcher yang dipilih tidak menduplikasi fungsi Caelestia atau komponen K41 yang sudah aktif.
3. Tentukan interface, ownership source, runtime path di bawah `~/.config/quickshell/`, deployment, backup, dan rollback.
4. Implementasikan perubahan minimal menggunakan API upstream yang diverifikasi.
5. Uji pencarian, keyboard navigation, command/action, keybind, fokus, fullscreen, dan shell restart.
6. Periksa error runtime, keamanan command execution, serta konsumsi resource.

## Acceptance criteria

- Hanya ada satu launcher utama yang jelas.
- Pencarian dan navigasi keyboard bekerja konsisten.
- Command/action dibatasi pada perilaku yang disetujui dan tidak mengeksekusi input secara tidak aman.
- Tidak mengganggu fokus, fullscreen, atau komponen desktop lain.
- Source K41 terpisah dan dapat dipelihara sebagai kandidat komponen k41-dots.
- Pengguna menerima hasil langsung pada X280.

## Status

PLANNED. Mulai setelah Topbar diterima atau urutan diubah secara eksplisit oleh pengguna.
