# Stage 5 — Panduan Eksekusi Workstream

Dokumen ini adalah indeks operasional untuk tujuh workstream customization desktop. Ikuti urutan yang ditetapkan; satu workstream harus melewati audit, implementasi, pengujian, review pengguna, dan pencatatan bukti sebelum workstream berikutnya dimulai.

## Urutan resmi

| Urutan | Workstream | Panduan |
|---|---|---|
| 1 | Boot experience — power-on, reboot, poweroff | [01 — Boot Experience](01-BOOT-EXPERIENCE.md) |
| 2 | Lock screen | [02 — Lock Screen](02-LOCK-SCREEN.md) |
| 3 | Dashboard | [03 — Dashboard](03-DASHBOARD.md) |
| 4 | Taskbar/panel | [04 — Taskbar dan Panel](04-TASKBAR-PANEL.md) |
| 5 | Launcher | [05 — Launcher](05-LAUNCHER.md) |
| 6 | Sidebar | [06 — Sidebar](06-SIDEBAR.md) |
| 7 | Utilities | [07 — Utilities](07-UTILITIES.md) |

## Dokumen acuan

- [Proyek dan arsitektur](../01-PROJECT.md)
- [Panduan desktop](../03-DESKTOP.md)
- [Design System](../07-DESKTOP-DESIGN-SYSTEM.md)
- [Status proyek](../06-STATUS.md)

Design System menentukan arah desain yang telah disetujui, tetapi **penerapan global atau penyelarasan tampilan lintas-komponen ditunda sampai ketujuh workstream selesai**. Selama suatu workstream, perubahan visual dibatasi pada komponen yang sedang dikerjakan dan hanya sejauh diperlukan untuk memenuhi fungsinya. Jangan memulai redesign wallpaper, typography global, icon/cursor global, window/compositor, GTK/Qt, terminal, notifications/OSD, atau tema aplikasi lain sebagai pekerjaan paralel.

## Status khusus — Guest Mode

**Guest Mode: NOT IMPLEMENTED / BELUM DIIMPLEMENTASIKAN.** Belum ada kode atau workflow Guest Mode yang dapat digunakan. Fitur ini secara eksplisit ditunda dan tidak boleh mulai dirancang atau diimplementasikan sampai pengguna menyatakan custom lock screen telah diterima. Status lock screen saat ini tetap **IN PROGRESS**, bukan VERIFIED; lihat [Workstream 2 — Lock Screen](02-LOCK-SCREEN.md) dan [status proyek](../06-STATUS.md).

## Aturan eksekusi wajib

1. Kerjakan satu workstream pada satu waktu dan ikuti urutan di atas.
2. Mulai dari kondisi aktual perangkat dan repository; jangan mengasumsikan konfigurasi, versi, proses, service, atau package masih sama dengan audit sebelumnya.
3. Audit bersifat read-only terlebih dahulu. Catat sumber konfigurasi yang benar-benar aktif, versi aplikasi, dependensi, proses, service, keybind, dan perilaku saat ini yang relevan.
4. Sebelum mengubah file, identifikasi pemilik file, buat backup yang dapat dipulihkan, dan tentukan prosedur rollback.
5. Pilih konfigurasi upstream yang didukung. Hindari duplikasi fungsi, daemon, service, widget, dan konfigurasi.
6. Terapkan perubahan kecil dan terisolasi. Jangan mencampur pekerjaan workstream lain atau optimasi tahap 6.
7. Validasi syntax/configuration, runtime, fungsi, regresi, serta dampak resource yang relevan. Jangan menyebut VERIFIED hanya karena script exit 0 atau file berhasil ditulis.
8. Minta pengguna melakukan review visual dan interaksi langsung pada ThinkPad X280. Screenshot tidak wajib.
9. Simpan ringkasan perubahan, perintah yang dijalankan, hasil aktual, keterbatasan, dan lokasi bukti. Redaksi data sensitif sebelum commit.
10. Jangan lanjut sebelum acceptance criteria workstream terpenuhi atau pengguna secara eksplisit menerima pengecualian yang dicatat.

## Siklus status

- **PLANNED** — belum dibuat atau belum diterapkan.
- **IMPLEMENTED** — perubahan tersedia di repository/perangkat.
- **TESTED** — pemeriksaan yang disebutkan benar-benar dijalankan.
- **VERIFIED** — perilaku dan acceptance criteria dibuktikan pada lingkungan yang disebutkan.
- **RELEASED** — termasuk dalam rilis yang ditetapkan.
- **BLOCKED** — ada prasyarat atau masalah yang menghalangi.
- **NOT APPLICABLE** — tidak relevan, disertai alasan.

Status harus menyebut commit, perangkat/lingkungan, metode pengujian, dan artefak bukti jika tersedia.

## Template laporan workstream

- Workstream dan tanggal:
- Commit repository:
- Kondisi awal dan versi:
- Konfigurasi aktif yang diaudit:
- Masalah/tujuan:
- Perubahan dan file yang disentuh:
- Backup dan rollback:
- Perintah/test yang dijalankan:
- Hasil aktual (PASS/WARN/FAIL/SKIP):
- Review visual/interaksi pengguna:
- Regresi dan keterbatasan:
- Status akhir:
- Keputusan lanjut:

## Batas global

Ketujuh workstream bukan alasan untuk melakukan redesign keseluruhan desktop secara bertahap tanpa kontrol. Setelah workstream 7 selesai, lakukan satu fase terpisah untuk audit dan penerapan global appearance serta konsistensi lintas-komponen. Fase global tersebut harus direncanakan dan disetujui berdasarkan temuan nyata dari tujuh workstream.