# Stage 5 — Desktop Customization

Stage 5 mengerjakan customization desktop secara bertahap dan satu workstream pada satu waktu. **Status terkini hanya dimiliki oleh [docs/06-STATUS.md](../../../docs/06-STATUS.md).** Dokumen ini menetapkan urutan dan cara kerja, bukan menyalin riwayat implementasi.

## Batas fondasi k41-dots

Stage 5 menjadi fondasi bertahap **k41-dots**: kumpulan komponen desktop K41 yang dibangun seperlunya di atas Quickshell, bukan pengembangan shell mandiri berskala besar. **Workstream 01 — Boot Experience tidak termasuk fondasi k41-dots**; boot splash ditangani Plymouth. Workstream 01 tetap tercatat sebagai pekerjaan boot proyek, tetapi tidak menjadi komponen, dependency, atau backlog k41-dots. Artefak Quickshell lama pada Workstream 01 tidak mengubah keputusan scope ini.

## Urutan workstream

| Urutan | ID | Workstream | Status/arah |
|---:|---:|---|---|
| 1 | 01 | [Boot Experience](01-BOOT-EXPERIENCE.md) | Diterima pengguna |
| 2 | 02 | [Lock Screen](02-LOCK-SCREEN.md) | Diterima pengguna |
| 3 | 04 | [Bottombar / K41Dock](04-TASKBAR-PANEL.md) | Berhasil; menjadi pola komponen K41 |
| 4 | 05 | [Topbar](05-TOPBAR.md) | Spesifikasi; desain detail menunggu keputusan |
| 5 | 06 | [Launcher](05-LAUNCHER.md) | Planned |
| 6 | 07 | [Sidebar](06-SIDEBAR.md) | Planned |
| 7 | 08 | [Utilities](07-UTILITIES.md) | Planned |

ID workstream adalah identitas komponen; urutan adalah urutan pengerjaan. Nomor pada beberapa nama file dokumentasi dipertahankan untuk menjaga tautan lama. Guest Mode (ID 03) deferred dan bukan bagian dari urutan implementasi aktif.

## Prinsip penyimpanan dan ownership

- Repository adalah sumber kanonis untuk source, installer, dokumentasi, dan test.
- Source runtime komponen Quickshell pada laptop berada di bawah `~/.config/quickshell/`.
- Untuk integrasi Caelestia saat ini, source aktif berada pada `~/.config/quickshell/caelestia/`. Komponen K41 ditempatkan dalam namespace/folder milik K41, misalnya `modules/k41dock/K41Dock.qml`.
- Setiap workstream menyimpan template source dalam `workstreams/<id>/config/quickshell/...`; installer menyalinnya ke lokasi runtime yang sesuai.
- Jangan mengedit source upstream atau file package-owned jika komponen K41 terpisah dapat digunakan.
- Perubahan runtime harus memiliki preflight, backup, verifikasi pascaperubahan, dan rollback yang sesuai.

## Peta implementasi repository

Source runtime Workstream 1–2 dan artefak Workstream 04 dipetakan di [Stage 5 — Desktop Customization](../README.md). Dokumen workstream tetap menjadi acuan prosedur dan acceptance.

## Alur kolaborasi dan verifikasi

Ikuti [Alur Kolaborasi, Audit, dan Verifikasi](00-COLLABORATION-WORKFLOW.md) untuk pembagian tanggung jawab, pembaruan melalui GitHub, sinkronisasi dan eksekusi pada X280, pemeriksaan privasi laporan, serta verifikasi hasil.

## Dokumen acuan

- [Project architecture](../../../docs/01-PROJECT.md)
- [Desktop handoff](../../../docs/03-DESKTOP.md)
- [Design System](../../../docs/07-DESKTOP-DESIGN-SYSTEM.md)
- [Current status](../../../docs/06-STATUS.md)

Design System menentukan bahasa visual lintas-komponen. Implementasi global yang tidak diperlukan oleh komponen aktif ditunda sampai workstream komponen selesai.

## Aturan eksekusi

1. Mulai dari implementasi dan konfigurasi aktif; jangan mengasumsikan audit lama masih berlaku.
2. Audit read-only terlebih dahulu: versi, source path aktif, konfigurasi, proses, service, keybind, dan dependensi yang relevan.
3. Identifikasi file pemilik, backup, interface, dan rollback sebelum perubahan.
4. Utamakan schema/API upstream dan hindari komponen, daemon, service, widget, atau fungsi duplikat.
5. Terapkan perubahan kecil dan terisolasi; jangan mencampur Stage 6.
6. Validasi syntax/configuration, runtime, fungsi, regression, dan resource sesuai perubahan.
7. Review visual/interaksi dilakukan langsung oleh pengguna pada ThinkPad X280. Screenshot bukan acceptance gate.
8. Catat perintah, hasil aktual, keterbatasan, dan keputusan pengguna dalam teks. Jangan mengarang hasil atau menyamakan file tersedia dengan runtime VERIFIED.
9. Lanjutkan ke workstream berikutnya setelah acceptance terpenuhi atau pengguna secara eksplisit menerima pengecualian.

## Cleanup Caelestia

Dashboard dinonaktifkan melalui `dashboard.enabled=false` pada konfigurasi Caelestia global dan override monitor yang memiliki bagian Dashboard. Script `scripts/k41-cleanup-caelestia.sh` berjalan tanpa argumen, menolak root, memvalidasi JSON, membuat backup, dan tidak menghapus source QML upstream. Entry Dashboard pada Nexus masih dapat terlihat; penghapusan halaman Nexus belum dilakukan.

## Guest Mode

Guest Mode **NOT IMPLEMENTED / DEFERRED**. Fitur ini bukan bagian dari workstream lock screen dan tidak otomatis aktif setelah Lock Screen diterima. Lihat [spesifikasi Guest Mode](03-GUEST-MODE.md). Implementasi memerlukan keputusan teknis dan persetujuan eksplisit yang baru.
