# Stage 5 — Desktop Customization

Stage 5 mengerjakan customization desktop secara bertahap dan satu workstream pada satu waktu. **Status terkini hanya dimiliki oleh [docs/06-STATUS.md](../../../docs/06-STATUS.md).** Dokumen ini menetapkan urutan dan cara kerja, bukan menyalin riwayat implementasi.

## Batas fondasi k41-dots

Stage 5 menjadi fondasi bertahap **k41-dots**: kumpulan komponen desktop K41 yang dibangun seperlunya di atas Quickshell, bukan pengembangan shell mandiri berskala besar. **Workstream 01 — Boot Experience dikecualikan dari scope k41-dots.** Implementasi Plymouth-only berstatus COMPLETE; runtime acceptance tema/UKI masih NOT VERIFIED. TTY2 fallback akibat lock-readiness timeout ditangani sebagai dependency Workstream 02, bukan dibuka kembali sebagai kegagalan renderer Plymouth. Workstream 01 tetap bagian dari proyek utama, tetapi bukan komponen, dependency, atau backlog k41-dots. Artefak Quickshell boot splash legacy telah dihapus dari branch aktif.

## Urutan workstream

| Urutan | ID | Workstream | Status/arah |
|---:|---:|---|---|
| 1 | 01 | [Boot Experience](01-BOOT-EXPERIENCE.md) | COMPLETE — Plymouth implementation; runtime acceptance pending |
| 2 | 02 | [Lock Screen](02-LOCK-SCREEN.md) | Design accepted; bounded startup fix implemented; X280 validation pending |
| 3 | 04 | [Bottombar / K41Dock](04-TASKBAR-PANEL.md) | Berhasil; menjadi pola komponen K41 |
| 4 | 05 | [Topbar](05-TOPBAR.md) | Spesifikasi; desain detail menunggu keputusan |
| 5 | 06 | [Launcher](05-LAUNCHER.md) | Planned |
| 6 | 07 | [Sidebar](06-SIDEBAR.md) | Planned |
| 7 | 08 | [Utilities](07-UTILITIES.md) | Planned |

ID workstream adalah identitas komponen; urutan adalah urutan pengerjaan. Nomor pada beberapa nama file dokumentasi dipertahankan untuk menjaga tautan lama. Guest Mode (ID 03) deferred dan bukan bagian dari urutan implementasi aktif.

## Prinsip penyimpanan dan ownership

- Repository adalah sumber kanonis untuk source, installer, dokumentasi, dan test.
- Source runtime komponen Quickshell pada laptop berada di bawah `~/.config/quickshell/`.
- Untuk integrasi Lock Screen saat ini, source upstream aktif berada pada `~/.config/quickshell/caelestia/`; empat file visual K41 disimpan di `workstreams/02-lock-screen/modules/lockscreen/` dan dideploy sebagai overlay ke `modules/lock/` setelah runtime stabil.
- Source milik K41 disimpan di direktori ownership khusus pada workstream; lokasi runtime mengikuti integrasi yang sudah diaudit. Jangan mengasumsikan seluruh fitur menggunakan namespace runtime `k41-dots` sebelum migrasi terbukti.
- Jangan mengedit source upstream atau file package-owned jika komponen K41 terpisah dapat digunakan.
- Perubahan runtime harus memiliki preflight, backup, verifikasi pascaperubahan, dan rollback yang sesuai.

## Peta implementasi repository

Source visual Workstream 02 berada di `workstreams/02-lock-screen/modules/lockscreen/`; helper lock startup dan updater berada di `workstreams/02-lock-screen/scripts/`. Deployment overlay ke Caelestia ditahan sampai fix startup diuji pada X280. Artefak Workstream 04 dipetakan di [Stage 5 — Desktop Customization](../README.md). Dokumen workstream tetap menjadi acuan prosedur dan acceptance.

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
