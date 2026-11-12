# Workstream 04 — Topbar

**Status: IMPLEMENTED — SOURCE, DEPLOYER, AND FIXTURE TEST CREATED; RUNTIME VERIFICATION PENDING.** Dokumen ini menetapkan tujuan, batas, alur kerja, acceptance, dan gate Workstream 04. Status implementasi dan status proyek tetap mengikuti `docs/06-STATUS.md`.

## Tujuan dan batas ownership

Membuat panel horizontal di tepi atas layar sebagai area informasi/status desktop yang ringkas. Topbar melengkapi Bottombar tanpa menduplikasi indikator workspace atau mengambil terlalu banyak ruang vertikal.

Prinsip ownership:

- Repository K41 adalah sumber kanonis source, script, test, dan dokumentasi yang dikelola proyek.
- Caelestia/Quickshell dapat menjadi host/runtime berdasarkan kondisi aktual yang diaudit, tetapi Caelestia tidak menyediakan Topbar siap pakai dalam baseline proyek ini. Topbar adalah komponen milik K41 yang harus dirancang dan diintegrasikan secara terpisah; jangan mengasumsikan ada native bar, modul Topbar, atau entry point khusus Topbar dari Caelestia.
- Source K41 harus dipisahkan dari source upstream; jangan mengubah file upstream lebih luas dari titik integrasi minimum yang terbukti diperlukan.
- Lokasi source dan target runtime final ditetapkan setelah audit; jangan mengasumsikan path atau API sebelum diverifikasi.
- Audit bersifat read-only. Deployment/implementasi merupakan operasi terpisah dan eksplisit.
- Workstream 08 — Clean up Caelestia tetap menjadi pekerjaan terakhir; WS04 tidak boleh melakukan cleanup upstream yang tidak diperlukan untuk Topbar.

## Keputusan desain

Keputusan berikut telah disepakati bersama pengguna dan menjadi baseline desain WS04.

### Pendekatan dan susunan elemen

- Gaya **Minimal**: hanya menampilkan lima elemen informasi/status yang disepakati.
- Topbar berbentuk panel horizontal di tepi atas layar.
- Urutan elemen dari kiri ke kanan:

| Posisi | Elemen | Informasi |
|---|---|---|
| Paling kiri | CPU | Penggunaan CPU |
| Di sebelah kanan CPU | RAM | Penggunaan RAM |
| Di sebelah kiri baterai | Notifications | Ikon notifikasi yang dapat diklik untuk membuka tray/panel berisi daftar notifikasi |
| Di sebelah kiri waktu | Battery | Status dan persentase baterai |
| Paling kanan | Clock | Jam, hari, dan tanggal |

Representasi urutan:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ CPU  RAM                                      NOTIFICATIONS BATTERY CLOCK │
└──────────────────────────────────────────────────────────────────────┘
```

Urutan tersebut adalah urutan relatif elemen dari kiri ke kanan. Pembagian ruang, alignment internal, dan jarak final ditetapkan setelah audit dan review spesifikasi teknis.

### Interaksi notifikasi

- Notifikasi ditampilkan pada Topbar sebagai sebuah ikon, bukan daftar notifikasi permanen.
- Ketika ikon notifikasi diklik, sebuah tray/panel notifikasi akan terbuka untuk menampilkan notifikasi.
- Tray/panel merupakan tampilan yang muncul sebagai respons terhadap klik; bukan elemen tambahan yang selalu memenuhi Topbar.
- Mekanisme membuka/menutup, penempatan, tampilan daftar, sumber notifikasi, dan perilaku ketika tidak ada notifikasi ditentukan setelah audit terhadap API/runtime yang tersedia.
- Implementasi harus menggunakan sumber notifikasi yang benar-benar aktif dan menghindari duplikasi daemon/provider.

### Properti visual

| Properti | Keputusan desain |
|---|---|
| Posisi | Top |
| Orientasi | Horizontal |
| Tinggi | Target awal 32–36 px; perlu validasi pada display X280 |
| Background | Dark translucent |
| Border radius | Minimal |
| Shadow | Subtle |
| Typography | Mengikuti Design System K41 |
| Karakter desain | Minimalis, elegan, ringkas, dan mudah dibaca |
| Visibility | Always visible; tidak menggunakan auto-hide |
| Monitor | Tampil pada seluruh monitor |
| Fullscreen | Intent desain: tetap terlihat; implementasi dan kompatibilitas compositor harus diverifikasi saat audit/runtime testing |

Keputusan visual merupakan target desain, bukan klaim bahwa nilai teknis atau tampilan runtime telah diuji.

### Prinsip desain

- **Minimal information:** hanya lima elemen yang disetujui.
- **Compact:** tidak menghabiskan ruang layar secara berlebihan.
- **Readable:** informasi tetap mudah dibaca.
- **Consistent:** mengikuti identitas visual Bottombar dan Design System K41.
- **Non-duplicative:** tidak menduplikasi fungsi Bottombar.
- **Lightweight:** menghindari indikator dan proses yang tidak diperlukan.
- **Always visible:** tidak menghilang otomatis dan direncanakan tampil pada semua monitor.

### Hal yang masih terbuka

Backend awal telah dipilih berdasarkan audit X280 dan source upstream yang dipin ke revision Caelestia `d999d4878ee4cec134168e60d913714566a8cfa6` serta dokumentasi Quickshell 0.3.2. Detail berikut tetap memerlukan verifikasi atau review perangkat:

- Typography final, ukuran ikon, alignment, spacing, padding, dan detail visual tray.
- Format tanggal/locale aktual pada sesi X280 dan keterbacaan pada scaling 1.5.
- Perilaku overlay layer saat fullscreen pada Hyprland aktual; penggunaan `WlrLayer.Overlay` adalah implementasi awal, bukan bukti runtime.
- Hotplug, multi-monitor, tray positioning, dan respons ketika data source tidak tersedia.
- Validasi QML compile/runtime pada versi paket yang terpasang.

Jangan menambahkan elemen lain tanpa persetujuan. Jangan menampilkan status yang ditebak atau membuat provider/notification daemon duplikat.

## Baseline implementasi awal — 13 November 2026

Source dan deployer awal telah dibuat dengan pola ownership dan deployment WS02/WS03:

| Artefak | Lokasi canonical |
|---|---|
| QML module | `workstreams/04-topbar/modules/topbar/Topbar.qml` |
| Deployment script | `workstreams/04-topbar/scripts/k41-implement-topbar.sh` |
| Fixture test | `tests/test-topbar-module-install.sh` |
| Runtime module | `~/.config/quickshell/k41/modules/topbar/Topbar.qml` |
| Caelestia host | `~/.config/quickshell/caelestia/shell.qml` |

Backend yang dipakai:

- CPU: delta counter aggregate `/proc/stat`, diperbarui setiap 2 detik.
- RAM: `MemTotal` dan `MemAvailable` dari `/proc/meminfo`, diperbarui setiap 2 detik.
- Battery: `/sys/class/power_supply/BAT0/capacity` dan `status`, diperbarui setiap 15 detik. Nama BAT0 sesuai hasil audit X280; perangkat lain belum didukung otomatis.
- Clock: Qt locale formatter, diperbarui setiap detik.
- Notifications: singleton Caelestia `Notifs` melalui `qs.services`; tray memakai `Notifs.notClosed` dan `NotifData.close()`. Tidak membuat notification daemon atau NotificationServer kedua. API diverifikasi terhadap source Caelestia revision yang tercatat di atas.

Topbar memakai Quickshell `Variants` atas `Quickshell.screens`, `PanelWindow` setinggi 34 px, exclusive zone 34 px, keyboard focus none, dan `WlrLayer.Overlay` sebagai upaya memenuhi intent tetap terlihat saat fullscreen. Tray notifikasi dibuka dari ikon/count dan dapat ditutup melalui tombol close. Source upstream Caelestia tidak disalin atau dimodifikasi; host hanya menerima satu import dan satu instance K41.

Deployment script berjalan sebagai user desktop biasa, menolak root, memvalidasi ownership/file type/symlink/host structure, membuat backup privat plus manifest, memakai staging dan atomic replacement, memverifikasi hasil, mendukung idempotensi, serta rollback untuk dua target. Script tidak me-restart atau me-reload Quickshell secara otomatis.

**Batas bukti saat ini:**
- IMPLEMENTED: source QML, deployer, dan fixture test telah ditambahkan ke repository.
- TESTED: `bash -n` untuk deployer dan fixture; fixture dijalankan sebagai user non-root dan lulus untuk deployment, integrasi host, backup, idempotensi, dan fail-closed pada integrasi parsial.
- NOT TESTED: ShellCheck tidak tersedia pada lingkungan validasi; `qmllint`/QML compiler tidak tersedia pada audit X280.
- NOT VERIFIED: QML compile/load, data provider pada runtime, tampilan, klik/tray, exclusive zone, fullscreen, seluruh monitor, scaling, dan regression Bottombar. Deployment ke X280 belum dijalankan.

## Batas scope

Termasuk:

- Audit dan desain Topbar.
- Lima elemen yang telah disepakati, termasuk ikon dan tray notifikasi, data source, visibility, dan perilaku multi-monitor.
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
| 1 | Audit Topbar | Inventaris source/runtime aktif, versi, dependency/API, panel/bar yang tersedia, konfigurasi, monitor/scaling, tray/status providers, lifecycle, dan titik integrasi. Read-only. | **IMPLEMENTED — audit X280 2026-11-12 direview; source Caelestia dipin dan API Notifs diperiksa** |
| 2 | Review audit dan spesifikasi | Validasi keputusan desain yang sudah disepakati terhadap bukti teknis; tetapkan backend, format data, detail layout, dan acceptance final. | **IMPLEMENTED — baseline backend/integrasi awal ditetapkan; detail visual/runtime masih perlu review** |
| 3 | Implementasi/deployment | Buat source K41 seperlunya dan integrasikan dengan perubahan minimum. Preflight, backup, staging/atomic write bila sesuai, verifikasi, logging, dan rollback. | **IMPLEMENTED — source/deployer dibuat; deployment X280 belum dijalankan** |
| 4 | Automated testing | Bash syntax/ShellCheck untuk script; fixture/mock untuk path, backup, idempotensi, failure, rollback, serta kontrak integrasi yang dapat diuji statis. | **PARTIALLY TESTED — bash -n dan fixture lulus; ShellCheck/QML lint belum tersedia** |
| 5 | Runtime verification dan review | Verifikasi QML/API pada versi X280, visual/interaksi, seluruh monitor, fullscreen/fokus, restart, error log, dan resource. | **PLANNED** |
| 6 | Acceptance dan handoff | Tinjau bukti, catat batas yang belum diverifikasi, minta penerimaan pengguna, lalu perbarui status dan lanjutkan ke WS05 bila gate terpenuhi. | **PLANNED** |

### Tahap 1 — Audit read-only

Audit dilakukan terhadap kondisi aktual, bukan asumsi atau snapshot lama. Cakupan minimum:

- Identitas repository/branch dan status checkout sebagai observasi read-only.
- Versi Quickshell, Caelestia, Hyprland, Qt, package, dan tooling QML yang tersedia.
- Source Caelestia user/system XDG yang benar-benar aktif, entry point, provenance/revision, konfigurasi, dan ownership file.
- Panel/bar yang sudah berjalan, konfigurasi native bar, tray host, notification daemon/provider dan API untuk membuka/menampilkan notification tray, serta kemungkinan duplikasi.
- Monitor aktif, resolusi, scaling, posisi/geometry panel, exclusive zone, dan perilaku fullscreen.
- QML imports, type/API, resource, relative imports, serta dependency transitif yang relevan.
- Keybind, menu, interaksi, lifecycle/reload, serta konflik dengan Bottombar dan komponen desktop lain.
- Source historis K41/Topbar, installer lama bila ada, test, dan dokumentasi terkait.
- Unknown, keterbatasan scan statis, dan data yang masih harus dikonfirmasi pada X280.

Audit tidak boleh mengubah source/runtime, package, konfigurasi, service, atau Git metadata checkout. Laporan lengkap disimpan secara privat; publikasi laporan hanya dilakukan setelah sanitasi dan review privasi. Jika otomatisasi publikasi digunakan, operasinya harus terisolasi dari metadata Git checkout aktif sebagaimana pola publisher WS02/WS03.

**Acceptance audit:** report tersedia dan direview; source aktif serta titik integrasi teridentifikasi; dependency/API memiliki bukti; konflik/duplikasi dan unknown dicatat; tidak ada perubahan runtime atau checkout.

### Tahap 2 — Review dan spesifikasi

Keputusan pendekatan, lima elemen, urutan, properti visual, visibility, dan cakupan monitor sudah disetujui dan dicatat di bagian Keputusan desain. Setelah audit, siapkan spesifikasi teknis ringkas untuk:

- Backend/sumber data aktual dan fallback/error state setiap elemen, termasuk mekanisme notification tray.
- Format tampilan CPU, RAM, baterai, dan waktu; desain ikon serta isi/tray notifikasi.
- Alignment, pembagian ruang, ukuran, spacing, typography, bentuk, dan transparansi final.
- Perilaku exclusive zone, fullscreen/fokus, seluruh monitor, monitor hotplug, resolusi, dan scaling.
- Batas integrasi Caelestia dan dependency yang tetap dimiliki upstream.

Source canonical K41 boleh disiapkan setelah baseline teknis disepakati, tetapi deployment runtime tetap menunggu review implementasi dan validasi preflight pada X280. Jika audit menunjukkan kebutuhan tidak jelas atau API belum terverifikasi, tandai BLOCKED dan lakukan investigasi terarah.

### Tahap 3 — Implementasi dan deployment

Implementasi harus mengikuti hasil audit dan spesifikasi yang disetujui:

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

Nama script, source, target runtime, dan API baseline telah ditetapkan pada tabel Baseline implementasi awal. Perubahan terhadap titik integrasi host tetap fail-closed jika struktur Caelestia lokal tidak cocok dengan pola yang dikenali.

### Tahap 4 — Automated testing

Test minimum ditentukan oleh desain final dan mencakup, bila relevan:

- Bash syntax dan ShellCheck. Bash syntax telah diuji; ShellCheck belum dijalankan karena tidak tersedia pada lingkungan validasi.
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
- Kelima elemen berfungsi dan menangani kondisi data unavailable/error dengan benar; klik ikon notifikasi membuka tray yang menampilkan notifikasi aktual, dan tray dapat ditutup kembali.
- Topbar tampil pada seluruh monitor dan tetap terlihat sesuai keputusan desain, termasuk pengujian fullscreen.
- Tidak mengganggu input, fokus window, atau Bottombar.
- Perilaku pada monitor/resolusi/scaling yang benar-benar tersedia.
- Shell restart/reload dan pemulihan setelah kegagalan, bila termasuk scope.
- Konsumsi resource dan stabilitas yang wajar.

Review visual dan interaksi dilakukan langsung oleh pengguna pada X280. Screenshot bukan acceptance gate. Catat perintah, kondisi, versi, hasil, log, dan keterbatasan; jangan menyamakan source terpasang atau test statis dengan runtime VERIFIED.

## Acceptance criteria

- Keputusan desain baseline sesuai bagian Keputusan desain dan tidak berubah tanpa persetujuan pengguna.
- Topbar berada di tepi atas, memuat tepat lima elemen yang disetujui, dengan urutan CPU, RAM, Notifications, Battery, Clock dari kiri ke kanan.
- Setiap status berasal dari backend aktual; unavailable/error ditangani secara jelas.
- Topbar selalu terlihat dan tampil pada seluruh monitor; perilaku fullscreen diuji dan keterbatasan teknis didokumentasikan.
- Tidak menduplikasi fungsi Bottombar atau komponen lain.
- Tidak menghalangi input atau fokus window.
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
