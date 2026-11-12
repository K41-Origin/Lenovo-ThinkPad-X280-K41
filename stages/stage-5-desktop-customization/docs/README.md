# Stage 5 — Desktop Customization

Stage 5 mengerjakan customization desktop secara bertahap dan satu workstream pada satu waktu. **Status terkini hanya dimiliki oleh [docs/06-STATUS.md](../../../docs/06-STATUS.md).** Dokumen ini menetapkan urutan dan cara kerja, bukan menyalin riwayat implementasi.

## Batas fondasi k41-dots

Stage 5 menjadi fondasi bertahap **k41-dots**: kumpulan komponen desktop K41 yang dibangun seperlunya di atas Quickshell, bukan pengembangan shell mandiri berskala besar. **Workstream 01 — Boot Experience dikecualikan dari scope k41-dots.** Implementasi Plymouth-only tersedia di repository, tetapi Workstream 01 saat ini **PAUSED — INVESTIGATION PENDING** karena splash tidak terlihat pada boot aktual. Workstream 01 tetap bagian dari proyek utama, tetapi bukan komponen, dependency, atau backlog k41-dots. Artefak Quickshell boot splash legacy telah dihapus dari branch aktif.

## Urutan workstream

| Urutan | ID | Workstream | Status/arah |
|---:|---:|---|---|
| 1 | 01 | [Boot Experience](01-BOOT-EXPERIENCE.md) | PAUSED — investigasi tampilan Plymouth |
| 2 | 02 | [Lock Screen](02-LOCK-SCREEN.md) | COMPLETED / USER ACCEPTED |
| 3 | 03 | [Bottombar](03-BOTTOMBAR.md) | **COMPLETED / USER ACCEPTED** |
| — | 04 | [Workflow Standardization](04-WORKFLOW.md) | **DOCUMENTATION IMPLEMENTED — proses lintas-workstream** |
| 4 | 05 | [Topbar](05-TOPBAR.md) | Spesifikasi; desain detail menunggu keputusan |
| 5 | 06 | [Launcher](05-LAUNCHER.md) | Planned |
| 6 | 07 | [Sidebar](06-SIDEBAR.md) | Planned |
| 7 | 08 | [Utilities](07-UTILITIES.md) | Planned |
| 8 | 09 | [Clean up Caelestia](09-CLEAN-UP-CAELESTIA.md) | **PLANNED — FINAL WORKSTREAM AFTER ALL COMPONENT WORKSTREAMS** |

Guest Mode berada di `archive/guest-mode/` dan bukan workstream aktif. Bottombar ditetapkan sebagai Workstream 03 dan menempati urutan eksekusi ke-3 setelah Boot Experience dan Lock Screen. Workstream 04 adalah standardisasi workflow dan dokumentasi proses; bukan komponen desktop dan tidak mengubah urutan eksekusi komponen. Workstream 09 — Clean up Caelestia tetap menjadi tahap konsolidasi terakhir setelah seluruh workstream komponen 02/03/05/06/07/08 selesai dan diterima.

ID 04 kini digunakan untuk Workstream Workflow Standardization sesuai keputusan pengguna. ID 05–08 dipertahankan agar referensi komponen yang sudah ada tidak berubah. Urutan pada tabel adalah urutan eksekusi komponen; Workstream 04 merupakan pekerjaan tata kelola lintas-workstream.

## Prinsip penyimpanan dan ownership

- Repository adalah sumber kanonis untuk source, installer, dokumentasi, dan test.
- Source runtime komponen Quickshell pada laptop berada di bawah ~/.config/quickshell/.
- Untuk integrasi Lock Screen, Caelestia tetap menjadi host/runtime pada ~/.config/quickshell/caelestia/; empat file visual K41 dikelola di workstreams/02-lock-screen/modules/lockscreen/ dan deployment overlay disediakan oleh script Workstream 02. Cleanup visual upstream menghapus sembilan komponen yang tidak digunakan dari user checkout saja; detail dan risiko tracked deletions ada di dokumen pemilik.
- Source milik K41 disimpan di direktori ownership khusus pada workstream; lokasi runtime mengikuti integrasi yang sudah diaudit. Jangan mengasumsikan seluruh fitur menggunakan namespace runtime k41-dots sebelum migrasi terbukti.
- Jangan mengedit source upstream atau file package-owned jika komponen K41 terpisah dapat digunakan.
- Perubahan runtime harus memiliki preflight, backup, verifikasi pascaperubahan, dan rollback yang sesuai.

## Peta implementasi repository

Workstream 02 — Lock Screen berstatus COMPLETED / USER ACCEPTED. Source visual, audit, helper startup, updater, deployment, cleanup hook, dan cleanup visual upstream berada di workstreams/02-lock-screen/. Prosedur, urutan kerja, bukti, dan batas validasi dicatat pada [Workstream 02 — Lock Screen](02-LOCK-SCREEN.md). Status penerimaan tidak menyatakan seluruh runtime X280 VERIFIED. Workstream 03 — Bottombar berstatus **COMPLETED / USER ACCEPTED**. Dokumen pemilik [Bottombar](03-BOTTOMBAR.md) mencatat arsitektur K41 → Caelestia, source canonical, deployment, integrasi host, batas validasi, dan keputusan pengguna. [Historical Implementation Record](03-BOTTOMBAR-IMPLEMENTATION.md) hanya menyimpan baseline lama. Validasi syntax, fixture, QML, dan runtime tetap harus dibedakan dari status penerimaan workstream.

## Alur kolaborasi dan verifikasi

Ikuti [Workstream 04 — Workflow Standardization](04-WORKFLOW.md) sebagai standar proses tujuh tahap. [Alur Kolaborasi, Audit, dan Verifikasi](00-COLLABORATION-WORKFLOW.md) tetap menjadi panduan operasional Stage 5 untuk pembagian tanggung jawab, pembaruan melalui GitHub, sinkronisasi dan eksekusi pada X280, pemeriksaan privasi laporan, serta verifikasi hasil.

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

## Cleanup Caelestia — Workstream 09

Pekerjaan cleanup luas Caelestia ditunda sampai seluruh workstream komponen Stage 5 selesai dan diterima. Scope, audit read-only, dependency map, approval gate, dry-run, backup, rollback, dan acceptance dicatat di [Workstream 09 — Clean up Caelestia](09-CLEAN-UP-CAELESTIA.md). Catatan dashboard yang sudah dinonaktifkan tetap menjadi histori; jangan menyamakan cleanup dashboard terdahulu dengan cleanup final seluruh Caelestia.
