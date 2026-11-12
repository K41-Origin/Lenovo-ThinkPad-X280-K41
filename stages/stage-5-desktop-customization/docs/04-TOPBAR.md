# Workstream 04 — Topbar

**Status: PLANNED — DOCUMENTATION READY; AUDIT NOT STARTED.** Dokumen ini menetapkan tujuan, batas, alur kerja, acceptance, dan gate Workstream 04. Status implementasi dan status proyek tetap mengikuti `docs/06-STATUS.md`.

## Tujuan dan batas ownership

Membuat panel horizontal di tepi atas layar sebagai area informasi/status desktop yang ringkas. Topbar melengkapi Bottombar tanpa menduplikasi indikator workspace atau mengambil terlalu banyak ruang vertikal.

Prinsip ownership:

- Repository K41 adalah sumber kanonis source, script, test, dan dokumentasi yang dikelola proyek.
- Caelestia tetap menjadi host/runtime selama audit tidak menemukan alasan teknis yang memerlukan keputusan arsitektur baru.
- Source K41 harus dipisahkan dari source upstream; jangan mengubah file upstream lebih luas dari titik integrasi minimum yang terbukti diperlukan.
- Lokasi source dan target runtime final ditetapkan setelah audit; jangan mengasumsikan path atau API sebelum diverifikasi.
- Audit bersifat read-only. Deployment/implementasi merupakan operasi terpisah dan eksplisit.
- Workstream 08 — Clean up Caelestia tetap menjadi pekerjaan terakhir; WS04 tidak boleh melakukan cleanup upstream yang tidak diperlukan untuk Topbar.

## Keputusan desain awal

Yang sudah diputuskan:

- Posisi di tepi atas layar.
- Orientasi horizontal.
- Menjadi komponen terpisah dari Bottombar.
- Mengikuti Design System K41 dan mempertahankan area kerja tetap luas.

Yang belum diputuskan dan wajib diselesaikan sebelum implementasi:

- Elemen yang ditampilkan dan alasan/fungsi setiap elemen.
- Sumber data/backend untuk setiap elemen serta perilaku saat data unavailable/error.
- Alignment kiri/tengah/kanan dan urutan elemen.
- Tinggi, margin, padding, transparansi, radius, dan tipografi.
- Visibility: persistent, auto-hide, atau perilaku lain.
- Interaksi, menu, tray, dan keybind yang benar-benar diperlukan.
- Perilaku terhadap fullscreen, fokus, multi-monitor, dan perubahan resolusi/scaling.
- Pilihan integrasi: native Caelestia bar, modul QML K41, atau pendekatan lain yang didukung API upstream terverifikasi.

Jangan menambahkan elemen hanya karena tersedia di upstream. Jangan menampilkan status yang ditebak atau membuat provider duplikat tanpa kebutuhan.

## Batas scope

Termasuk:

- Audit dan desain Topbar.
- Layout, elemen status/informasi yang disetujui, visibility, dan interaksi terkait.
- Integrasi minimum dengan host/runtime yang telah diaudit.
- Source K41, deployment/repair yang diperlukan, test, dokumentasi, dan rollback.

Tidak termasuk:

- Workspace dock/navigasi workspace yang dimiliki Bottombar.
- Launcher, Sidebar, Utilities, dan Dashboard.
- Perubahan PAM, autentikasi, lock/session protocol, boot configuration, atau system services.
- Optimasi hardware Stage 6.
- Cleanup luas Caelestia atau penghapusan komponen upstream yang tidak terbukti khusus menjadi penghalang Topbar.

## Workflow kanonis — audit, desain, implementasi, verifikasi

Urutan mengikuti pola Workstream 02 dan 03: audit read-only lebih dahulu, keputusan desain berdasarkan bukti, lalu implementasi terpisah. Jangan menggabungkan audit dan deployment menjadi satu script serba guna.

| Urutan | Tahap | Tanggung jawab | Status |
|---:|---|---|---|
| 1 | Audit Topbar | Inventaris source/runtime aktif, versi, dependency/API, panel/bar yang tersedia, konfigurasi, monitor/scaling, tray/status providers, lifecycle, dan titik integrasi. Read-only. | **PLANNED** |
| 2 | Review audit dan spesifikasi | Klasifikasikan dependency upstream vs source K41; tetapkan elemen, data source, layout, visibility, interaksi, dan acceptance bersama pengguna. | **PLANNED — USER DECISION REQUIRED** |
| 3 | Implementasi/deployment | Buat source K41 seperlunya dan integrasikan dengan perubahan minimum. Preflight, backup, staging/atomic write bila sesuai, verifikasi, logging, dan rollback. | **PLANNED — GATED BY DESIGN APPROVAL** |
| 4 | Automated testing | Bash syntax/ShellCheck untuk script; fixture/mock untuk path, backup, idempotensi, failure, rollback, serta kontrak integrasi yang dapat diuji statis. | **PLANNED** |
| 5 | Runtime verification dan review | Verifikasi QML/API pada versi X280, visual/interaksi, multi-monitor, fullscreen/fokus, restart, error log, dan resource. | **PLANNED** |
| 6 | Acceptance dan handoff | Tinjau bukti, catat batas yang belum diverifikasi, minta penerimaan pengguna, lalu perbarui status dan lanjutkan ke WS05 bila gate terpenuhi. | **PLANNED** |

### Tahap 1 — Audit read-only

Audit dilakukan terhadap kondisi aktual, bukan asumsi atau snapshot lama. Cakupan minimum:

- Identitas repository/branch dan status checkout sebagai observasi read-only.
- Versi Quickshell, Caelestia, Hyprland, Qt, package, dan tooling QML yang tersedia.
- Source Caelestia user/system XDG yang benar-benar aktif, entry point, provenance/revision, konfigurasi, dan ownership file.
- Panel/bar yang sudah berjalan, konfigurasi native bar, tray host, status provider, serta kemungkinan duplikasi.
- Monitor aktif, resolusi, scaling, posisi/geometry panel, exclusive zone, dan perilaku fullscreen.
- QML imports, type/API, resource, relative imports, serta dependency transitif yang relevan.
- Keybind, menu, interaksi, lifecycle/reload, serta konflik dengan Bottombar dan komponen desktop lain.
- Source historis K41/Topbar, installer lama bila ada, test, dan dokumentasi terkait.
- Unknown, keterbatasan scan statis, dan data yang masih harus dikonfirmasi pada X280.

Audit tidak boleh mengubah source/runtime, package, konfigurasi, service, atau Git metadata checkout. Laporan lengkap disimpan secara privat; publikasi laporan hanya dilakukan setelah sanitasi dan review privasi. Jika otomatisasi publikasi digunakan, operasinya harus terisolasi dari metadata Git checkout aktif sebagaimana pola publisher WS02/WS03.

**Acceptance audit:** report tersedia dan direview; source aktif serta titik integrasi teridentifikasi; dependency/API memiliki bukti; konflik/duplikasi dan unknown dicatat; tidak ada perubahan runtime atau checkout.

### Tahap 2 — Review dan persetujuan desain

Sebelum implementasi, sediakan spesifikasi ringkas yang dapat ditinjau pengguna:

- Daftar elemen dan fungsi masing-masing.
- Backend/sumber data aktual dan fallback/error state.
- Alignment dan urutan elemen.
- Ukuran, spacing, typography, bentuk, dan transparansi.
- Visibility serta perilaku fullscreen/fokus.
- Interaksi, tray/menu, dan keybind.
- Target monitor dan perilaku multi-monitor/scaling.
- Batas integrasi Caelestia dan dependency yang tetap dimiliki upstream.

Jangan mulai membuat atau mengubah source runtime sebelum keputusan desain dan acceptance disetujui pengguna. Jika audit menunjukkan kebutuhan tidak jelas atau API belum terverifikasi, tandai BLOCKED dan lakukan investigasi terarah.

### Tahap 3 — Implementasi dan deployment

Implementasi harus mengikuti hasil audit dan desain yang disetujui:

1. Tetapkan source canonical K41, target runtime, host file yang perlu diintegrasikan, dan dependency.
2. Buat perubahan sekecil mungkin; hindari menyalin seluruh modul upstream.
3. Pisahkan audit dari installer/deployer.
4. Lakukan preflight terhadap user/session, source, target, versi/API, file type, symlink, ownership, dan kondisi host yang dikenali.
5. Jangan menimpa perubahan lokal atau struktur yang tidak dikenali; berhenti fail-closed.
6. Buat backup privat dan checksum/manifest sebelum mutasi.
7. Gunakan staging dan atomic replacement jika sesuai dengan jenis target.
8. Verifikasi setiap target setelah perubahan; rollback jika implementasi parsial/gagal.
9. Jangan restart/reload shell secara otomatis kecuali diperlukan, disetujui, dan mekanisme pemulihannya jelas.
10. Simpan log privat; publikasi hanya salinan tersanitasi dan setelah review.

Nama script, path source, target runtime, serta detail API belum ditetapkan. Semua itu baru boleh diputuskan setelah audit; jangan mengarang entry point atau menganggap kompatibilitas berdasarkan nama API.

### Tahap 4 — Automated testing

Test minimum ditentukan oleh desain final dan mencakup, bila relevan:

- Bash syntax dan ShellCheck.
- Audit tetap read-only terhadap runtime dan Git checkout.
- Missing dependency/source/target, symlink, file type, ownership, dan host state ambigu.
- Deploy/repair, idempotensi, backup/checksum, failure injection, rollback, dan fail-closed.
- Validasi konfigurasi/QML dan import/type terhadap versi runtime yang ditargetkan.
- Tidak ada perubahan pada Bottombar atau komponen di luar scope.
- Sanitasi laporan dan isolasi operasi Git publisher bila fitur publikasi diimplementasikan.

Gunakan fixture/mock untuk test yang berpotensi mengubah sistem. Jangan mengklaim test dijalankan jika hanya ditulis atau direncanakan.

### Tahap 5 — Runtime verification

Pada ThinkPad X280, verifikasi sekurang-kurangnya:

- QML load/compile dan tidak ada error runtime yang relevan.
- Posisi, alignment, ukuran, keterbacaan, dan data aktual.
- Tray/menu/interaksi sesuai desain yang disetujui.
- Tidak mengganggu input, fokus window, aplikasi fullscreen, atau Bottombar.
- Perilaku pada monitor/resolusi/scaling yang benar-benar tersedia.
- Shell restart/reload dan pemulihan setelah kegagalan, bila termasuk scope.
- Konsumsi resource dan stabilitas yang wajar.

Review visual dan interaksi dilakukan langsung oleh pengguna pada X280. Screenshot bukan acceptance gate. Catat perintah, kondisi, versi, hasil, log, dan keterbatasan; jangan menyamakan source terpasang atau test statis dengan runtime VERIFIED.

## Acceptance criteria

- Spesifikasi desain disetujui sebelum implementasi.
- Topbar berada di tepi atas dan hanya memuat elemen yang disetujui.
- Setiap status berasal dari backend aktual; unavailable/error ditangani secara jelas.
- Tidak menduplikasi fungsi Bottombar atau komponen lain.
- Tidak menghalangi input, fokus window, atau aplikasi fullscreen.
- Ukuran, alignment, dan keterbacaan sesuai display X280.
- Integrasi upstream minimal dan dependency yang tersisa terdokumentasi.
- Backup, verifikasi, idempotensi, dan rollback memiliki bukti test yang sesuai.
- Tidak ada error runtime kritis atau konsumsi resource yang tidak wajar.
- Pengguna menerima tampilan dan interaksi langsung pada X280.

## Status, bukti, dan rollback

Gunakan klasifikasi secara terpisah:

- **PLANNED:** belum dikerjakan.
- **IMPLEMENTED:** source/script/dokumentasi telah dibuat atau diubah.
- **TESTED:** test tertentu benar-benar dijalankan; sebutkan perintah dan hasil.
- **VERIFIED:** perilaku dikonfirmasi dengan bukti yang sesuai, termasuk runtime bila klaim menyangkut runtime.
- **COMPLETED / USER ACCEPTED:** pengguna menerima scope workstream; bukan sinonim bahwa semua aspek runtime VERIFIED.
- **BLOCKED:** pekerjaan tertahan oleh dependency, bukti, keputusan, atau risiko yang belum terselesaikan.

Backup runtime tidak di-commit. Catat lokasi backup, checksum/manifest, target perubahan, hasil verifikasi, dan cara rollback. Jangan menghapus backup sebelum hasil diterima dan prosedur pemulihan dinilai memadai.

## Gate keluar

Workstream 04 hanya dapat ditutup setelah acceptance criteria ditinjau dan pengguna menyatakan menerima hasil, atau pengguna secara eksplisit menyetujui pengecualian yang dicatat. Setelah itu lanjut ke [Workstream 05 — Launcher](05-LAUNCHER.md). Cleanup Caelestia tetap ditunda sampai seluruh workstream komponen selesai dan diterima.
