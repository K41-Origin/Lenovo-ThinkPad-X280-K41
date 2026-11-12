# Workstream 03 — Bottombar

**Status: AUDIT IN PROGRESS.** Tahap saat ini hanya menyelaraskan dokumentasi dan mengaudit baseline. Refactoring, migrasi source/runtime, deployment, serta perubahan konfigurasi laptop belum dilakukan dan belum diotorisasi.

Dokumen ini adalah dokumen pemilik Workstream 03. Pola dokumentasi mengikuti Workstream 02: tujuan dan ownership, alur kerja bertahap, source, deployment, cleanup/integrasi, daftar script, batas keamanan, validasi/bukti, serta acceptance. Kesamaan pola dokumentasi tidak berarti Bottombar harus menyalin implementasi Lock Screen.

## Tujuan dan batas ownership

- Menyediakan Bottombar K41 untuk indikator dan navigasi workspace Hyprland.
- Menjaga source, installer, test, dan dokumentasi K41 di repository sebagai sumber kanonis.
- Memisahkan komponen K41 dari source milik Caelestia sejauh didukung oleh arsitektur Quickshell yang telah diverifikasi.
- Mempertahankan Caelestia sebagai host/runtime selama belum ada keputusan arsitektur berbeda yang didukung bukti.
- Menghindari perubahan terhadap autentikasi, lock/session protocol, konfigurasi global yang tidak relevan, serta komponen upstream di luar kebutuhan Bottombar.
- Memastikan setiap perubahan runtime memiliki preflight, backup, verifikasi pascaperubahan, logging, dan strategi rollback yang diuji.
- Mempertahankan perilaku visual/fungsional yang sebelumnya diterima pengguna, kecuali audit menemukan masalah atau pengguna menyetujui perubahan desain.

## Ringkasan alur kerja

Urutan berikut menjadi workflow kanonis Workstream 03. Setiap tahap harus memiliki hasil dan bukti sebelum tahap berikutnya dimulai.

### 1. Audit dan pengumpulan bukti — IN PROGRESS

Audit awal repository telah menemukan baseline berikut:

- Source QML historis: `workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`.
- Installer historis: `stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`.
- Runtime target installer historis: `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`.
- Entry point Caelestia yang dimodifikasi: `~/.config/quickshell/caelestia/shell.qml`.
- Konfigurasi Caelestia yang dimodifikasi: `~/.config/caelestia/shell.json`.

Audit statis atas installer menunjukkan bahwa proses install membuat backup untuk tiga target, menyalin QML, menambahkan import/instance ke `shell.qml`, dan menonaktifkan entry pada `bar.entries` di `shell.json`. Installer menyediakan `--check`, `--install`, dan `--rollback`; tidak melakukan sudo, pemasangan paket, restart service, atau reload Quickshell otomatis.

Temuan awal yang perlu dituntaskan:

1. Identitas workstream adalah 03, tetapi direktori source masih bernama `04-taskbar-panel`.
2. Installer masih mengikat source dan runtime ke struktur Caelestia lama.
3. Installer mengubah entry point shell dan konfigurasi bar upstream; kebutuhan dan dampak integrasi ini harus dievaluasi.
4. Rollback tersedia sebagai operasi manual, tetapi installer belum memiliki pemulihan otomatis untuk kegagalan parsial.
5. Validasi belum membuktikan QML compile/runtime, kompatibilitas versi API, atau perilaku UI.
6. Inventaris test khusus, dependency closure, dan bukti runtime X280 belum selesai diaudit.

Audit tahap ini harus bersifat read-only. Inventarisasi perangkat, source aktif, revision/provenance, dependency, konfigurasi, proses, dan log harus disimpan sebagai bukti; jangan mengubah runtime selama audit.

### 2. Audit dependency, API, dan desain integrasi — PLANNED

Sebelum menentukan arsitektur target:

- Identifikasi versi Quickshell, Caelestia, Hyprland, Qt, dan modul QML yang benar-benar digunakan.
- Verifikasi API yang dipakai oleh `PanelWindow`, `WlrLayershell`, `HyprlandMonitor`, `Hypr.workspaces`, dan `Hypr.focusWorkspace()` terhadap versi terpasang serta dokumentasi upstream.
- Petakan dependency langsung dan transitif dari QML Bottombar.
- Identifikasi entry point, konfigurasi, dan lifecycle yang diperlukan untuk memuat komponen K41.
- Evaluasi apakah Bottombar dapat dimuat sebagai modul K41 terpisah tanpa memodifikasi source Caelestia yang tidak diperlukan.
- Tetapkan interface dan ownership antara host Caelestia dengan modul Bottombar.

Hasil tahap ini adalah dependency map, integration map, daftar risiko kompatibilitas, dan keputusan arsitektur yang dapat ditinjau. Jangan menganggap namespace runtime K41 yang pernah ditulis di dokumen lama sebagai keputusan implementasi final sebelum mekanisme loading Quickshell diverifikasi.

### 3. Source module K41 — PLANNED

Baseline source historis berada di:

`workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`

Lokasi source dan struktur final Workstream 03 belum ditetapkan. Penetapan path baru dilakukan setelah audit dependency dan desain integrasi disetujui.

Perilaku baseline yang perlu dipertahankan atau diuji:

- Menampilkan workspace pada monitor terkait.
- Membedakan workspace aktif dan workspace yang memiliki window.
- Mengganti workspace melalui interaksi klik.
- Menampilkan dock melalui trigger hover di tepi bawah.
- Menjaga dock tetap terlihat ketika pointer berada di dock dan menyembunyikannya setelah pointer meninggalkan area.
- Menyembunyikan dock ketika fullscreen toplevel aktif.
- Tidak memesan exclusive zone pada layout workspace.

Perubahan desain bukan bagian otomatis dari refactoring struktur. Perubahan perilaku/visual memerlukan alasan, spesifikasi, dan acceptance tersendiri.

### 4. Deployment, backup, log, dan rollback — PLANNED

Installer historis:

`stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`

Perilaku historis dan gap yang ditemukan:

- Memiliki mode `--check`, `--install`, dan `--rollback`.
- Membuat backup sebelum mengubah target `shell.qml`, `K41Dock.qml`, dan `shell.json`.
- Menyimpan manifest serta log pada state directory user.
- Melakukan validasi pascaperubahan.
- Tidak melakukan automatic rollback ketika proses berhenti setelah sebagian perubahan diterapkan.
- Belum ada bukti bahwa target replacement, rollback, symlink/path handling, interruption, atau concurrent execution telah diuji secara memadai.

Desain installer baru harus menetapkan:

1. Validasi user/session dan dependency sebelum perubahan.
2. Pemeriksaan repository, source, target, ownership, dan kondisi file aktual.
3. Penolakan kondisi ambigu atau file lokal yang tidak dikenal; jangan menimpa perubahan pengguna tanpa keputusan eksplisit.
4. Backup dan checksum manifest sebelum mutasi.
5. Staging serta penggantian file secara atomik jika sesuai.
6. Automatic rollback untuk kegagalan deployment yang dapat dipulihkan.
7. Verifikasi hasil dan status rollback.
8. Log privat lokal; publikasi laporan hanya setelah sanitasi dan review privasi.
9. Idempotensi dan perilaku aman saat dijalankan ulang.
10. Mode check/dry-run yang tidak mengubah runtime.

Perintah dan path final belum ditetapkan. Jangan menjalankan installer historis sebagai bagian dari audit dokumentasi ini.

### 5. Cleanup dan integrasi upstream — PLANNED

Belum ada keputusan untuk menghapus file atau komponen upstream Caelestia terkait Bottombar.

Tahap ini harus:

- Memetakan fungsi bar upstream yang saat ini aktif.
- Memastikan apakah seluruh atau sebagian `bar.entries` memang harus dinonaktifkan.
- Memeriksa referensi QML/JS, konfigurasi, dynamic loader, serta dependency yang mungkin memakai komponen tersebut.
- Memisahkan kebutuhan menonaktifkan konfigurasi dari kebutuhan menghapus source.
- Menghindari penghapusan source upstream kecuali dependency audit membuktikan aman dan pengguna menyetujui perubahan.
- Menyediakan backup, dry-run, validasi, dan rollback untuk setiap cleanup yang akhirnya disetujui.

Tidak ada cleanup upstream yang diotorisasi atau dilakukan pada tahap audit ini.

### 6. Automated testing dan runtime verification — PLANNED

Test plan harus mencakup sekurang-kurangnya:

- Bash syntax dan ShellCheck untuk script.
- Preflight: dependency hilang, versi tidak cocok, source tidak ditemukan, target ambigu, dan session tidak sesuai.
- Install: target baru, target lama yang dikenal, dan file konfigurasi dengan konten yang tidak terkait.
- Failure injection pada setiap tahap mutasi dan pemulihan.
- Rollback: file sebelumnya dipulihkan dengan checksum yang cocok.
- Idempotensi: eksekusi berulang tidak menghasilkan perubahan tak perlu.
- QML loading/compile dan integrasi terhadap versi runtime yang dipin.
- Fungsi workspace, monitor, hover, fullscreen, dan perubahan workspace.
- Regression terhadap bar/komponen Caelestia lain.
- Resource usage dan stabilitas runtime yang relevan.

Test berbahaya harus memakai fixture atau mock; jangan menguji rollback dengan mengubah konfigurasi laptop tanpa persetujuan. Runtime verification pada ThinkPad X280 harus mencatat perintah, versi, kondisi, hasil aktual, dan batasan. Konfirmasi visual/interaksi akhir dilakukan pengguna pada perangkat.

## Daftar script dan artefak

| Artefak | Fungsi | Status audit |
|---|---|---|
| `K41Dock.qml` historis | Komponen Bottombar | Source ditemukan; dependency audit belum selesai |
| `k41-install-caelestia-dock.sh` | Check, install, backup, rollback manual | Source diperiksa statis; test belum dijalankan |
| Test khusus Bottombar | Regression dan installer tests | Inventaris penuh belum selesai |
| Audit report Workstream 03 | Bukti kondisi source/runtime/dependency | Belum ditetapkan/dihasilkan dalam sesi ini |

## Batas keamanan

- Jangan menggunakan sudo untuk deployment komponen user-level kecuali kebutuhan telah dibuktikan dan disetujui.
- Jangan mengubah PAM, autentikasi, lock/session protocol, system services, atau boot configuration dalam scope Bottombar.
- Jangan menghapus atau menimpa file upstream maupun konfigurasi pengguna tanpa audit, backup, dan persetujuan.
- Jangan menjalankan perubahan runtime selama audit read-only.
- Jangan memublikasikan log yang memuat username, home path, hostname, token, environment, atau data pribadi tanpa sanitasi dan review.
- Jangan mengklaim rollback, idempotensi, atau runtime safety sebelum test yang relevan benar-benar dijalankan.

## Validasi dan bukti

- Source QML dan installer historis telah dibaca dari repository GitHub.
- Temuan struktur path, target deployment, modifikasi `shell.qml`/`shell.json`, backup, dan rollback manual berasal dari inspeksi statis source installer.
- Konfirmasi pengguna terdahulu bahwa Bottombar berhasil digunakan dicatat sebagai bukti penerimaan historis, bukan bukti regression atau runtime verification terkini.
- Audit dependency penuh, pengujian script, QML validation, runtime verification, dan regression belum diklaim selesai.
- Setiap hasil selanjutnya harus diklasifikasikan sebagai PLANNED, IMPLEMENTED, TESTED, atau VERIFIED berdasarkan bukti aktual.

## Acceptance dan penutupan

Workstream 03 tetap **AUDIT IN PROGRESS** sampai audit source/runtime, dependency, integrasi, installer, security, dan test selesai serta hasilnya ditinjau.

Sebelum refactoring dimulai, harus tersedia dan disetujui:

1. Baseline audit dan dependency map.
2. Arsitektur source/runtime serta integration contract.
3. Daftar perubahan dan file target.
4. Strategi backup, rollback, logging, dan privasi.
5. Test plan dan acceptance criteria.

Workstream hanya dapat ditutup setelah implementasi, pengujian, runtime verification yang disepakati, dokumentasi, dan penerimaan pengguna dicatat secara terpisah. Penerimaan pengguna tidak boleh digunakan untuk mengklaim pengujian yang tidak dilakukan.
