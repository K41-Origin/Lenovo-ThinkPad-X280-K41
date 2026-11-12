# Stage 5 — Desktop Customization

Stage 5 mengerjakan customization desktop secara bertahap dan satu workstream pada satu waktu. **Status terkini hanya dimiliki oleh [docs/06-STATUS.md](../../../docs/06-STATUS.md).** Dokumen ini menetapkan urutan dan cara kerja, bukan menyalin riwayat implementasi.

## Batas fondasi k41-dots

Stage 5 menjadi fondasi bertahap **k41-dots**: kumpulan komponen desktop K41 yang dibangun seperlunya di atas Quickshell, bukan pengembangan shell mandiri berskala besar. **Workstream 01 — Boot Experience dikecualikan dari scope k41-dots.** Implementasi Plymouth-only tersedia di repository, tetapi Workstream 01 saat ini **PAUSED — INVESTIGATION PENDING** karena splash tidak terlihat pada boot aktual. Workstream 01 tetap bagian dari proyek utama, tetapi bukan komponen, dependency, atau backlog k41-dots. Artefak Quickshell boot splash legacy telah dihapus dari branch aktif.

## Urutan workstream

| Urutan | ID | Workstream | Status/arah |
|---:|---:|---|---|
| 1 | 01 | [Boot Experience](01-BOOT-EXPERIENCE.md) | PAUSED — investigasi tampilan Plymouth |
| 2 | 02 | [Lock Screen](02-LOCK-SCREEN.md) | COMPLETED / USER ACCEPTED |
| 3 | 04 | [Bottombar / K41Dock](04-TASKBAR-PANEL.md) | Berhasil; menjadi pola komponen K41 |
| 4 | 05 | [Topbar](05-TOPBAR.md) | Spesifikasi; desain detail menunggu keputusan |
| 5 | 06 | [Launcher](05-LAUNCHER.md) | Planned |
| 6 | 07 | [Sidebar](06-SIDEBAR.md) | Planned |
| 7 | 08 | [Utilities](07-UTILITIES.md) | Planned |

ID workstream adalah identitas komponen yang stabil, bukan nomor urutan pengerjaan. Urutan pada tabel adalah urutan eksekusi; nomor ID tidak perlu dibuat berurutan atau diubah hanya untuk menghilangkan celah. Hanya workstream yang tercantum pada tabel yang termasuk roadmap Stage 5 aktif.

## Prinsip penyimpanan dan ownership

- Repository adalah sumber kanonis untuk source, installer, dokumentasi, dan test.
- Source runtime komponen Quickshell pada laptop berada di bawah ~/.config/quickshell/.
- Untuk integrasi Lock Screen, Caelestia tetap menjadi host/runtime pada ~/.config/quickshell/caelestia/; empat file visual K41 dikelola di workstreams/02-lock-screen/modules/lockscreen/ dan deployment overlay disediakan oleh script Workstream 02. Cleanup visual upstream menghapus sembilan komponen yang tidak digunakan dari user checkout saja; detail dan risiko tracked deletions ada di dokumen pemilik.
- Source milik K41 disimpan di direktori ownership khusus pada workstream; lokasi runtime mengikuti integrasi yang sudah diaudit. Jangan mengasumsikan seluruh fitur menggunakan namespace runtime k41-dots sebelum migrasi terbukti.
- Jangan mengedit source upstream atau file package-owned jika komponen K41 terpisah dapat digunakan.
- Perubahan runtime harus memiliki preflight, backup, verifikasi pascaperubahan, dan rollback yang sesuai.

## Peta implementasi repository

Workstream 02 — Lock Screen berstatus COMPLETED / USER ACCEPTED. Source visual, audit, helper startup, updater, deployment, cleanup hook, dan cleanup visual upstream berada di workstreams/02-lock-screen/. Prosedur, urutan kerja, bukti, dan batas validasi dicatat pada [Workstream 02 — Lock Screen](02-LOCK-SCREEN.md). Status penerimaan tidak menyatakan seluruh runtime X280 VERIFIED. Artefak Workstream 04 dipetakan di [Stage 5 — Desktop Customization](../README.md).

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

Dashboard dinonaktifkan melalui dashboard.enabled=false pada konfigurasi Caelestia global dan override monitor yang memiliki bagian Dashboard. Script scripts/k41-cleanup-caelestia.sh menonaktifkan konfigurasi tanpa menghapus source QML upstream. Jika modul upstream hilang dari checkout user, scripts/k41-repair-caelestia-modules.sh memulihkan hanya modules/dashboard dari instalasi package di /etc/xdg/quickshell/caelestia; default dry-run, --apply menyalin secara atomik setelah memverifikasi source dimiliki pacman, dan tidak menimpa direktori tujuan yang sudah ada. Jalankan --check setelah repair. Test fixture: tests/test-caelestia-module-repair.sh. Entry Dashboard pada Nexus masih dapat terlihat; penghapusan halaman Nexus belum dilakukan.
