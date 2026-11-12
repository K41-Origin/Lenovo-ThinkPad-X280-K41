# Workstream 04 — Topbar

**Status: IN PROGRESS — RENDERING USER-CONFIRMED; FUNCTIONAL REVIEW AND STANDALONE MIGRATION PENDING.** Pengguna telah mengonfirmasi Topbar tampil setelah reboot. Rendering dasar diterima, tetapi seluruh fungsi dan acceptance belum VERIFIED. Anomali battery percentage (laporan pengguna pernah 1%, sedangkan audit UPower berikutnya 55%) dan perilaku klik Notifications masih perlu dituntaskan. Arah migrasi terbaru adalah membuat Topbar sebagai konfigurasi Quickshell mandiri milik K41, tidak di-import ke `caelestia/shell.qml`, dan tidak memodifikasi source Caelestia. Script deployment saat ini masih menerapkan arsitektur lama; migrasi script ditahan sampai kepemilikan Notification D-Bus dan mekanisme start/stop dua shell ditetapkan. Status proyek mengikuti `docs/06-STATUS.md`.

## Tujuan dan batas ownership

Membuat panel horizontal di tepi atas layar sebagai area informasi/status desktop yang ringkas. Topbar melengkapi Bottombar tanpa menduplikasi indikator workspace atau mengambil terlalu banyak ruang vertikal.

Prinsip ownership:

- Repository K41 adalah sumber kanonis source, script, test, dan dokumentasi yang dikelola proyek.
- Caelestia/Quickshell dapat menjadi host/runtime berdasarkan kondisi aktual yang diaudit, tetapi Caelestia tidak menyediakan Topbar siap pakai dalam baseline proyek ini. Topbar adalah komponen milik K41 yang harus dirancang dan diintegrasikan secara terpisah; jangan mengasumsikan ada native bar, modul Topbar, atau entry point khusus Topbar dari Caelestia.
- Source K41 harus dipisahkan dari source upstream; jangan mengubah file upstream lebih luas dari titik integrasi minimum yang terbukti diperlukan.
- Lokasi source dan target runtime final ditetapkan setelah audit; jangan mengasumsikan path atau API sebelum diverifikasi.
- Audit bersifat read-only. Deployment/implementasi merupakan operasi terpisah dan eksplisit.
- Workstream 08 — Clean up Caelestia tetap menjadi pekerjaan terakhir; WS04 tidak boleh melakukan cleanup upstream yang tidak diperlukan untuk Topbar.
- **Keputusan arah WS04 (13 November 2026):** Topbar target adalah shell/configuration Quickshell mandiri milik K41, bukan modul yang di-host oleh `caelestia/shell.qml`. K41 akan memiliki QML, komponen, service/logic, dan tray yang diperlukan sendiri. Source Caelestia boleh dipelajari sebagai referensi dan bagian yang benar-benar diperlukan boleh diadaptasi dengan mempertahankan atribusi serta lisensi upstream; file/source Caelestia yang terpasang tidak boleh diubah. Implementasi/deployer lama yang mengedit host Caelestia dianggap transitional dan akan diganti setelah desain notifikasi D-Bus diselesaikan.

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

## Implementasi setelah audit Caelestia — 13 November 2026

Source K41 dan deployer telah direvisi berdasarkan audit source Caelestia pada revision `d999d4878ee4cec134168e60d913714566a8cfa6`. Topbar tetap merupakan panel horizontal milik K41, tetapi data dan interaksi menggunakan service/runtime yang sudah tersedia.

| Artefak | Lokasi canonical |
|---|---|
| QML module | `workstreams/04-topbar/modules/topbar/Topbar.qml` |
| Deployment script | `workstreams/04-topbar/scripts/k41-implement-topbar.sh` |
| Fixture test | `tests/test-topbar-module-install.sh` |
| Runtime module | `~/.config/quickshell/caelestia/k41/modules/topbar/Topbar.qml` (primary; imported by `qs.k41.modules.topbar`) dan `~/.config/quickshell/k41/modules/topbar/Topbar.qml` (compatibility mirror). |
| Caelestia host | `~/.config/quickshell/caelestia/shell.qml` |

### Backend kanonis

- **CPU:** `Caelestia.Services.Cpu.percentage`; nilai 0.0–1.0 dikonversi menjadi persen. `ServiceRef { service: Cpu }` mengaktifkan TickingService Caelestia.
- **RAM:** `Caelestia.Services.Memory.percentage`; nilai 0.0–1.0 dikonversi menjadi persen. `ServiceRef { service: Memory }` mengaktifkan service yang sama.
- **Battery:** `Quickshell.Services.UPower`, melalui `UPower.displayDevice.percentage` dan `UPower.onBattery`. Tidak membaca BAT0/sysfs secara langsung.
- **Clock:** singleton Caelestia `Time.format(...)`; tidak membuat `Date` sendiri atau timer clock tambahan.
- **Notifications:** singleton `Notifs.notClosed` untuk jumlah notifikasi. Klik indikator meminta Caelestia membuka sidebar pada monitor yang sama melalui `ShellState.forScreen(screen).sidebar = true`; daftar notifikasi tetap ditangani oleh NotificationServer dan Notification Dock Caelestia yang sudah ada. K41 tidak membuat NotificationServer, notification store, atau tray duplikat.

CPU/RAM, battery, clock, dan notification backend tersebut diperiksa pada source Caelestia yang dipin di atas. `modules/sidebar/Content.qml` memasang `NotifDock`, sedangkan `ShellState.forScreen()` menyediakan state per monitor. Karena itu Topbar tidak membuat UI daftar notifikasi paralel.

### Deployment dan batas implementasi

Deployment script tetap menjalankan integrasi minimum melalui satu import dan satu instance `K41Topbar.Topbar` di `shell.qml`. Sebelum deployment, script memeriksa kontrak backend QML dan menolak pola polling/provider duplikat yang sudah diketahui. Pola backup privat, staging, atomic replacement, verifikasi, idempotensi, rollback, serta larangan auto-restart tetap dipertahankan.

Topbar memakai `Variants` atas `Quickshell.screens`, panel horizontal 34 px, exclusive zone 34 px, `WlrLayer.Overlay`, dan keyboard focus none. Properti layer/fullscreen masih harus diverifikasi di Hyprland pada X280; konfigurasi tersebut bukan bukti runtime bahwa panel selalu terlihat saat fullscreen.

### Perubahan dari implementasi awal

Implementasi awal membaca `/proc/stat`, `/proc/meminfo`, dan `/sys/class/power_supply/BAT0`, membuat timer polling sendiri, menggunakan `new Date()`, serta membuat tray notifikasi kedua. Semua pendekatan tersebut telah dikeluarkan dari QML canonical. Backend sekarang menggunakan service upstream sesuai audit, dan klik notifikasi membuka Notification Dock Caelestia yang sudah tersedia.

### Status bukti

- **IMPLEMENTED:** QML, deployer, dan fixture test direvisi untuk backend Caelestia/Quickshell yang diaudit.
- **SOURCE-LEVEL REVIEWED:** API CPU, RAM, UPower, Time, Notifs, dan ShellState diperiksa pada revision Caelestia yang dipin.
- **TEST EVIDENCE:** Bash syntax dan fixture deployer pernah dilaporkan lulus untuk revisi sebelumnya; hasil tersebut tidak otomatis mencakup revisi terakhir. Bash syntax/fixture regression setelah revisi terakhir belum dikonfirmasi dalam dokumentasi ini. ShellCheck dan QML lint/compile belum dijalankan.
- **NOT VERIFIED:** QML load/instantiation/rendering, tampilan pada X280, nilai provider saat runtime, klik indikator dan pembukaan sidebar, fullscreen, multi-monitor/hotplug, scaling, serta regression Bottombar.
- **DEPLOYMENT:** belum dijalankan ke runtime X280. Jangan deploy sebelum fixture/syntax test dan review QML selesai.

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
| 4 | Automated testing | Bash syntax/ShellCheck untuk script; fixture/mock untuk path, backup, idempotensi, failure, rollback, serta kontrak integrasi yang dapat diuji statis. | **PENDING — hasil test versi implementasi awal tidak dianggap berlaku untuk revisi backend; bash -n dan fixture harus dijalankan ulang. ShellCheck/QML lint belum tersedia pada audit X280.** |
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

Untuk diagnosis setelah deployment, audit juga merekam:

- Perbandingan SHA-256 source canonical `Topbar.qml` dengan module runtime, serta keberadaan, tipe file, permission, ukuran, dan waktu modifikasi target.
- Path efektif `XDG_CONFIG_HOME`, struktur/import/instance host Caelestia, posisi instance relatif terhadap `id: root`, dan checksum host.
- Proses Quickshell aktif, executable basename, selector konfigurasi eksplisit, serta allowlist terbatas environment yang relevan.
- Unit user systemd yang terkait Quickshell/Caelestia dan error/warning QML/Quickshell dari journal 30 menit terakhir.

Audit tidak menampilkan PID, full command line, full environment, isi file konfigurasi, atau path home absolut. Selector konfigurasi eksplisit dan variabel allowlist yang diperlukan untuk memastikan instance aktif dilaporkan. Ringkasan yang dipublikasikan tetap perlu diperiksa sebelum dibagikan lebih lanjut.

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

- Bash syntax dan ShellCheck. Bash syntax dan fixture versi implementasi awal pernah diuji, tetapi hasil tersebut tidak berlaku otomatis untuk revisi ini. Jalankan ulang sebelum deployment; ShellCheck belum dijalankan karena tidak tersedia pada lingkungan validasi.
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


## Target arsitektur mandiri — keputusan 13 November 2026

Target WS04 diperbarui: K41 Topbar akan berjalan dari konfigurasi Quickshell milik K41 sendiri, dengan entry point terpisah (misalnya `~/.config/quickshell/k41/shell.qml`). Topbar tidak lagi membutuhkan import, instance, `ShellState`, `Notifs`, `Time`, atau service internal Caelestia. Script deployer final tidak boleh mengedit `~/.config/quickshell/caelestia/shell.qml` maupun menyalin file ke namespace Caelestia.

K41 boleh mempelajari dan mengadaptasi bagian source Caelestia yang relevan sebagai referensi implementasi. Source hasil adaptasi harus berada sepenuhnya di direktori K41, diberi atribusi dan lisensi upstream yang sesuai, serta menggunakan API Quickshell/Qt yang telah diverifikasi. Tidak boleh ada patch terhadap file upstream Caelestia.

**Gate teknis sebelum perubahan deployer:** Quickshell `NotificationServer` mengimplementasikan Desktop Notifications Specification dan menerima notifikasi dari aplikasi. Karena hanya satu pemilik service D-Bus `org.freedesktop.Notifications` yang dapat aktif pada satu sesi, shell K41 mandiri berpotensi bersaing dengan NotificationServer Caelestia. Sebelum K41 mengambil alih server dan tray, audit harus memastikan siapa pemilik service aktif dan menentukan transisi yang tidak membuat notifikasi hilang/duplikat. Jangan membuat dua NotificationServer aktif dan jangan menganggap Caelestia Notification Dock dapat dipakai tanpa ketergantungan Caelestia.

CPU/RAM harus memakai service/logic yang dimiliki K41; battery dapat menggunakan Quickshell UPower API; clock menggunakan Qt/QML. Semua API harus diverifikasi terhadap versi Quickshell yang benar-benar terpasang pada X280. Target lokasi, autostart, single-instance, lifecycle, dan rollback deployer juga harus ditetapkan sebelum deployment.

Status migrasi: **PLANNED**. Belum ada shell mandiri, service K41, perubahan deployer, atau runtime migration yang diimplementasikan/diuji. Deployer lama masih mengintegrasikan module ke Caelestia dan tidak memenuhi target arsitektur baru; jangan jalankan sebagai implementasi mandiri.

## Status runtime dan langkah berikutnya — 13 November 2026

Audit X280 terbaru yang dipublikasikan pada commit `faef1785050da16ae3a437099ee1b8e5249e5714` menunjukkan:

- File module canonical dan runtime memiliki SHA-256 yang sama.
- Host `~/.config/quickshell/caelestia/shell.qml` memiliki import dan satu instance Topbar; instance berada setelah `id: root`.
- Satu proses Quickshell terdeteksi dengan selector konfigurasi eksplisit `caelestia`.
- Audit tidak menemukan `qmllint`, `qmlformat`, atau `qml` melalui PATH.
- Hasil tersebut membuktikan kesesuaian file dan struktur integrasi, bukan bahwa QML berhasil dimuat atau panel dirender.

Pengguna menyampaikan bahwa reboot diperlukan untuk melihat perubahan yang telah diterapkan. Karena itu WS04 ditandai **PENDING** sampai sesi baru setelah reboot diperiksa. Tidak ada reboot yang dijalankan oleh proses dokumentasi ini.

### Langkah verifikasi setelah reboot

1. Pastikan sesi Hyprland dan proses Quickshell aktif normal.
2. Periksa log startup/runtime Quickshell untuk error import, unresolved type/property, binding, atau instantiation.
3. Pastikan Topbar terlihat dan lima indikator menampilkan data yang masuk akal.
4. Uji klik notification indicator dan pastikan Notification Dock Caelestia terbuka pada monitor yang benar.
5. Periksa fullscreen, multi-monitor, scaling 1.5, dan regression Bottombar.
6. Catat hasil aktual. Jika panel tetap tidak tampil, kumpulkan log runtime sebelum mengubah source atau melakukan restart tambahan.

Jangan menganggap reboot saja sebagai bukti keberhasilan. Gate WS04 tetap memerlukan observasi runtime dan penerimaan pengguna.

## Runtime audit terarah — 13 November 2026

Untuk menindaklanjuti error QML setelah reboot, tersedia collector terpisah yang mengikuti pola audit startup WS02:

`workstreams/04-topbar/scripts/k41-audit-topbar-runtime.sh`

Jalankan sebagai user desktop biasa, dari TTY maupun terminal desktop, pada branch `main`:

```bash
bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar-runtime.sh
```

Audit mengumpulkan:
- Versi Quickshell, Caelestia, Hyprland, paket Qt, serta ketersediaan `qmllint`.
- Isi dan SHA-256 host `shell.qml`, module Topbar runtime, dan source canonical K41; termasuk deteksi namespace lama `K41.Topbar.Topbar`.
- Selector konfigurasi dan environment allowlisted dari proses Quickshell aktif tanpa merekam PID, command line lengkap, atau seluruh environment.
- Inventaris instance Quickshell, log Caelestia, Hyprland config errors, monitor, service user, dan journal boot/session yang relevan.
- Pemeriksaan `qmllint` bila tersedia; audit tidak memasang dependency.

Laporan lengkap disimpan privat di `~/.local/state/k41/topbar/runtime-audits/<timestamp>/report.txt` dengan permission terbatas. Salinan yang disanitasi dipublikasikan melalui temporary independent clone ke `reports/stage-5-desktop-customization/04-topbar/runtime-audits/<timestamp>/`. Publisher tidak melakukan fetch, checkout, atau operasi worktree pada Git metadata checkout aktif. Jika publikasi gagal, report lokal dipertahankan dan script keluar non-zero.

Audit ini read-only: tidak menjalankan Quickshell baru, tidak melakukan reload/restart, tidak menjalankan deployer, dan tidak mengubah package, service, maupun konfigurasi. Sanitasi otomatis tidak menjamin semua data sensitif terhapus; periksa report publik setelah audit. Jalankan dari TTY setelah kegagalan startup agar log boot dan konfigurasi yang bermasalah tetap tersedia.

Regression guard: `stages/stage-5-desktop-customization/tests/test-topbar-runtime-audit.sh`, terdaftar pada `tests/run.sh`. Penambahan test belum berarti test telah dijalankan pada X280.



## Implementasi deployer standalone — 13 November 2026

Arah implementasi deployer kini sudah dipindahkan dari integrasi host Caelestia ke konfigurasi mandiri K41:

- Entry point canonical: `workstreams/04-topbar/shell.qml`.
- Target runtime: `$XDG_CONFIG_HOME/quickshell/k41/shell.qml` dan `$XDG_CONFIG_HOME/quickshell/k41/modules/topbar/Topbar.qml`.
- Perintah pemilihan konfigurasi yang direncanakan: `qs -c k41` (harus dikonfirmasi terhadap versi Quickshell yang terpasang).
- Deployer tidak mengedit `quickshell/caelestia/shell.qml`, tidak menulis ke direktori Caelestia, tidak mengubah autostart, dan tidak me-reload/restart Quickshell.
- Deployer memvalidasi ownership, symlink, file type, dependency Caelestia yang diketahui, melakukan backup privat, staging, atomic replacement, verifikasi hasil, dan rollback saat operasi gagal.
- Source QML harus memiliki marker standalone K41. Import `Caelestia`, `qs.services`, `ShellState`, `Notifs`, `Time.format`, dan `ServiceRef` ditolak oleh preflight.

**Penting:** source canonical `modules/topbar/Topbar.qml` yang saat ini ada di repository masih memakai API Caelestia. Karena itu deployer baru akan berhenti secara fail-closed dan belum boleh dijalankan untuk deployment aktual sampai source tersebut dimigrasikan ke implementasi K41-owned. Entry point mandiri telah dibuat, tetapi modul belum mandiri. Tidak ada runtime deployment pada perubahan ini.

Fixture test diperbarui untuk memakai QML standalone sintetis dan menguji:
1. Instalasi ke namespace `quickshell/k41`.
2. Tidak berubahnya file host Caelestia.
3. Idempotensi tanpa backup tambahan.
4. Penolakan source yang kembali mengimpor Caelestia.
5. Penolakan symlink pada target.

Test tersebut belum dijalankan pada checkout lokal atau X280. Status saat ini: deployer dan entry point **IMPLEMENTED**; adaptasi module/services **PLANNED/BLOCKED**; runtime deployment dan verifikasi **NOT TESTED**.

Jangan jalankan `qs -c k41` dulu. K41 belum memiliki Topbar mandiri yang siap dirender, dan kepemilikan D-Bus `org.freedesktop.Notifications` belum ditransisikan dari Caelestia. Menjalankan dua NotificationServer bersamaan dapat menimbulkan konflik kepemilikan service. Setelah adaptasi modul dan strategi transisi notification server selesai, jalankan fixture test dan validasi QML sebelum runtime deployment.
