# Stage 5 — Desktop Customization

Stage 5 mengerjakan customization desktop secara berurutan. **Status terkini hanya dimiliki oleh [docs/06-STATUS.md](../06-STATUS.md).** Dokumen ini menetapkan urutan dan cara kerja, bukan menyalin riwayat implementasi.

## Urutan workstream

| Urutan | Workstream |
|---|---|
| 1 | [Boot Experience](01-BOOT-EXPERIENCE.md) |
| 2 | [Lock Screen](02-LOCK-SCREEN.md) |
| 3 | [Dashboard](03-DASHBOARD.md) |
| 4 | [Taskbar/Panel](04-TASKBAR-PANEL.md) |
| 5 | [Launcher](05-LAUNCHER.md) |
| 6 | [Sidebar](06-SIDEBAR.md) |
| 7 | [Utilities](07-UTILITIES.md) |

Kerjakan satu workstream pada satu waktu. Status tiap workstream mengikuti [status proyek](../06-STATUS.md); jangan membuka kembali workstream yang telah diterima pengguna hanya berdasarkan catatan historis.

## Peta implementasi repository

Source runtime Workstream 1–2 dan ownership fisiknya dipetakan di [Stage 5 — Desktop Customization](../../stages/stage-5-desktop-customization/README.md). Dokumen workstream di direktori ini tetap menjadi acuan prosedur dan acceptance.

## Dokumen acuan

- [Project architecture](../01-PROJECT.md)
- [Desktop handoff](../03-DESKTOP.md)
- [Design System](../07-DESKTOP-DESIGN-SYSTEM.md)
- [Current status](../06-STATUS.md)

Design System menentukan bahasa visual lintas-komponen. Implementasi global yang tidak diperlukan oleh komponen aktif ditunda sampai workstream komponen selesai. Setiap workstream tetap harus mengikuti token/prinsip desain yang relevan.

## Aturan eksekusi

1. Mulai dari implementasi dan konfigurasi aktif; jangan mengasumsikan audit lama masih berlaku.
2. Audit read-only terlebih dahulu: versi, source path aktif, konfigurasi, proses, service, keybind, dan dependensi yang relevan.
3. Identifikasi file pemilik, backup, interface, dan rollback sebelum perubahan.
4. Utamakan schema/API upstream dan hindari komponen, daemon, service, widget, atau fungsi duplikat.
5. Terapkan perubahan kecil dan terisolasi; jangan mencampur Stage 6.
6. Validasi syntax/configuration, runtime, fungsi, regression, dan resource sesuai perubahan.
7. Review visual/interaksi dilakukan langsung oleh pengguna pada ThinkPad X280. **Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.**
8. Catat perintah, hasil aktual, keterbatasan, dan keputusan pengguna dalam teks. Jangan mengarang hasil atau menyamakan file tersedia dengan runtime VERIFIED.
9. Lanjutkan ke workstream berikutnya setelah acceptance terpenuhi atau pengguna secara eksplisit menerima pengecualian.

## Status

Gunakan definisi status kanonis di [AGENTS.md](../../AGENTS.md). Status aktual dan prioritas tidak disalin di sini.

## Guest Mode

Guest Mode **NOT IMPLEMENTED / DEFERRED**. Fitur ini bukan bagian dari workstream lock screen saat ini. Lihat [spesifikasi Guest Mode](03-GUEST-MODE.md). Implementasi memerlukan keputusan teknis dan persetujuan baru setelah lock screen diterima.
