# Workstream 3 — Dashboard

## Tujuan

Menyediakan dashboard yang informatif saat diminta, terstruktur, responsif, dan tidak memenuhi desktop ketika tidak digunakan.

## Batas

Termasuk layout dashboard, hierarki informasi, widget yang memang diperlukan, kalender/media/resource summary bila didukung, open/close behavior, keyboard/mouse interaction, dan integrasi dengan Caelestia/Quickshell yang aktif.

Tidak termasuk redesign global shell, perubahan taskbar, sidebar, utilities panel, atau optimasi CPU/thermal tahap 6.

## Prosedur

1. Audit versi Caelestia/Quickshell, konfigurasi dashboard yang aktif, widget upstream yang tersedia, keybind/trigger, proses, dependensi data, dan log runtime.
2. Inventarisasi fitur yang sudah disediakan upstream; jangan membuat widget duplikat.
3. Catat kebutuhan informasi berdasarkan kegunaan. Hindari widget dekoratif atau data yang tidak membantu keputusan pengguna.
4. Tetapkan layout, urutan, ukuran, dan trigger minimal untuk iterasi pertama.
5. Backup konfigurasi dan lakukan perubahan terisolasi; prioritaskan schema dan API upstream.
6. Uji dashboard tampil/tutup, fokus, keyboard navigation, data unavailable, refresh, dan perilaku saat shell restart.
7. Periksa penggunaan resource secara proporsional; hindari polling agresif atau proses tambahan yang tidak perlu.

## Acceptance criteria

- Dashboard dapat dibuka dan ditutup secara konsisten.
- Informasi penting mudah dipindai dan tidak berlebihan.
- Widget menampilkan data yang benar atau status unavailable dengan jelas.
- Tidak ada widget/proses duplikat yang tidak diperlukan.
- Dashboard tidak mengganggu jendela kerja atau keybind penting.
- Runtime stabil dan pengguna menerima tampilan serta interaksi pada X280.

## Rollback dan bukti

Backup file konfigurasi sebelum edit. Catat versi shell, widget yang dipakai, sumber data, keybind, test, log error, dan hasil review pengguna. Jangan memasukkan token/API key atau data personal ke laporan.

## Gate keluar

Status VERIFIED memerlukan pengujian runtime dan konfirmasi pengguna. Setelah diterima, lanjutkan ke [Workstream 5 — Launcher](05-LAUNCHER.md).