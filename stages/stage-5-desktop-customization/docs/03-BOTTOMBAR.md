# Workstream 03 — Bottombar

**Status: IMPLEMENTER DISESUAIKAN DENGAN AUDIT X280 — SIAP UNTUK UJI COBA TERBATAS.** Audit membuktikan host aktif adalah `qs -c caelestia -n -d`, dan `shell.qml` user mengimpor `modules/k41dock` serta membuat `K41Dock.K41Dock {}`. Installer sekarang memasang source kanonis ke target import tersebut tanpa mengubah entry point atau konfigurasi Caelestia.

Dokumen ini adalah dokumen pemilik Workstream 03. Pola dokumentasi dan urutan kerja mengikuti Workstream 02, tetapi implementasi Bottombar tetap disesuaikan dengan hasil audit dan kontrak Quickshell/Caelestia yang benar-benar terverifikasi.

## Tujuan dan batas ownership

- Menyediakan Bottombar K41 untuk indikator dan navigasi workspace Hyprland.
- Menjaga source, script, test, dan dokumentasi K41 di repository sebagai sumber kanonis.
- Memisahkan komponen K41 dari source milik Caelestia sejauh didukung arsitektur Quickshell yang telah diverifikasi.
- Mempertahankan perilaku Bottombar yang sebelumnya diterima pengguna kecuali audit menemukan masalah atau perubahan disetujui.
- Memastikan setiap perubahan runtime memiliki preflight, backup, verifikasi pascaperubahan, logging, dan rollback yang diuji.
- Audit harus read-only terhadap runtime dan Git checkout.

## Workflow kanonis — tiga script

Urutan pengerjaan mengikuti pola Workstream 02. Ketiga script memiliki ownership dan tanggung jawab terpisah; tidak boleh digabung menjadi satu installer serba guna.

| Urutan | Script | Tanggung jawab | Status |
|---:|---|---|---|
| 1 | `scripts/k41-audit-bottombar.sh` | Mengumpulkan baseline source/runtime, provenance, dependency, API, konfigurasi, versi, installer lama, test, dan integrasi. Read-only. | **IMPLEMENTED — audit X280 selesai; baseline 2026-11-12** |
| 2 | `scripts/k41-implement-bottombar.sh` | Memasang atau memperbaiki modul kanonis pada lokasi import host Caelestia yang sudah diaudit. Backup privat, atomic replacement, verifikasi, dan rollback otomatis; tidak mengubah host integration/configuration. | **IMPLEMENTED — SIAP UJI COBA TERBATAS; QML/RUNTIME BELUM VERIFIED** |
| 3 | `scripts/k41-cleanup-bottombar.sh` | Audit target cleanup, dry-run, backup, penghapusan/nonaktifkan komponen yang disetujui, verifikasi, dan rollback. | PLANNED |

Source kanonis berada di `stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.Qml`. Target runtime arsitektural adalah `~/.config/quickshell/k41/modules/bottombar/Dock.Qml`. Script berada di `stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/`.

### Tahap 1 — Audit dan pengumpulan bukti

Jalankan dari Git checkout repository, branch `main`, sebagai user desktop biasa tanpa sudo:

```bash
bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-audit-bottombar.sh
```

Laporan lengkap disimpan privat di:

```text
~/.local/state/k41/bottombar/audits/<timestamp>/bottombar-audit.txt
```

Setelah report selesai dibuat, script otomatis membuat salinan tersanitasi dan mempublikasikannya ke branch `main` melalui temporary independent clone di:

```text
reports/stage-5-desktop-customization/03-bottombar/audits/<timestamp>/
├── report.txt
└── README.txt
```

Audit mengumpulkan:

- Repository HEAD, status branch/worktree/index sebagai observasi read-only.
- Source kanonis K41 dan source historis, ukuran, SHA-256, import, serta relative dependency.
- Root runtime K41 dan Caelestia user/XDG/system, target `modules/bottombar/Dock.Qml`, entry point, provenance Git jika tersedia, metadata, ownership, permission, dan file modul yang sudah terpasang.
- Direktori konfigurasi Quickshell, konfigurasi bernama yang tersedia, proses Quickshell aktif (command line saja), serta referensi K41/Bottombar dalam QML/JS host.
- Titik integrasi pada `shell.qml` serta metadata `bar.entries` dari konfigurasi JSON tanpa mencetak seluruh konfigurasi.
- Isi installer historis, mode operasi, target perubahan, backup/manifest, dan indikasi rollback.
- Import QML, API yang dipakai, relative import, dan kandidat type yang perlu diverifikasi.
- Versi Quickshell/Caelestia/Hyprland/Qt, package metadata, serta ketersediaan `qmllint`, `qmlformat`, dan ShellCheck.
- Inventaris tests, source, dokumentasi, dan artefak workstream yang relevan.
- Ringkasan keterbatasan dan input yang dibutuhkan untuk desain implementasi.

Audit bersifat read-only terhadap source, runtime, konfigurasi, package, dan service. Report lengkap hanya ditulis ke state directory privat. Publikasi dilakukan melalui clone baru yang memiliki direktori `.git` sendiri; fetch, commit, dan push hanya berjalan di clone sementara tersebut. Script tidak menjalankan operasi Git mutatif pada checkout aktif, sehingga branch, HEAD, index, FETCH_HEAD, dan worktree metadata checkout lokal tidak disentuh. Report publik berada pada path yang berbeda dari report lokal; tidak ada untracked report di checkout yang dapat menghalangi `git pull`.

Sebelum publikasi, script membuat salinan UTF-8 tersanitasi yang mengganti home/repository path, username, hostname, UID/GID, alamat IP/MAC, SSID, URL user-info, dan pola credential umum. Sanitasi otomatis bukan jaminan bahwa semua data sensitif terhapus. Review report publik di GitHub tetap wajib. Jika clone/commit/push gagal, report privat tetap tersedia dan script keluar dengan status non-zero. Audit statis tidak membuktikan QML compile atau runtime behavior.

**Acceptance tahap audit:** report lengkap tersedia; setiap target/source runtime diklasifikasikan; dependency/API dan integration map memiliki bukti; unknown/missing data ditandai; tidak ada perubahan runtime atau Git checkout.

### Tahap 2 — Implementasi modul

Source kanonis:

```text
workstreams/03-bottombar/modules/bottombar/Dock.Qml
```

Jalankan dari Git checkout sebagai user desktop biasa:

```bash
bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-implement-bottombar.sh
```

Audit X280 menunjukkan bahwa konfigurasi aktif Caelestia saat ini secara eksplisit memuat `modules/k41dock` dan membuat `K41Dock.K41Dock {}`. Karena belum ada entry point K41 standalone dan file pada namespace K41 tidak otomatis dimuat oleh host aktif, installer untuk uji coba ini menggunakan target kompatibilitas yang benar-benar direferensikan host: `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`. Source tetap berasal dari modul kanonis K41 di repository. Ini sengaja mempertahankan integrasi yang sudah ada agar kita dapat menguji deployment tanpa mengedit `shell.qml` atau `shell.json`. Script tetap satu operasi: memasang atau memperbaiki modul; tidak ada mode `--check`, `--rollback`, cleanup, package management, atau service management.

**Pemetaan source ke runtime untuk uji coba host aktif:**

```text
Source kanonis: stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.Qml
Runtime host:   ~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml
```

Target namespace standalone `~/.config/quickshell/k41/modules/bottombar/Dock.Qml` tetap menjadi arah arsitektur jangka panjang, tetapi belum menjadi target deployment sampai ada entry point/loading contract K41 yang dirancang dan diuji. File pada namespace K41 tidak otomatis dimuat oleh host Caelestia.

Perilaku script:
- Menolak root/sumber/target symlink, path tidak aman, dan file yang bukan regular file.
- Memastikan target host Caelestia yang sudah ada, parent directory, ownership, permission, serta source valid sesuai hasil audit.
- Memastikan `shell.qml` memiliki tepat satu import `modules/k41dock` dan satu instance `K41Dock.K41Dock {}`; mencatat checksum sebelum deployment dan memverifikasi `shell.qml` serta `shell.json` tidak berubah. Tidak mengubah konfigurasi system-wide, paket, atau service.
- Jika source dan target sudah sama, berhenti tanpa perubahan.
- Jika target berbeda, membuat backup privat dan manifest checksum sebelum atomic replacement.
- Memverifikasi hasil; kegagalan setelah perubahan memicu pemulihan otomatis dari backup.
- Tidak me-reload atau me-restart Quickshell.

Backup disimpan di `$XDG_STATE_HOME/k41/backups/bottombar/<timestamp>/` (atau `~/.local/state/...` jika XDG_STATE_HOME tidak disetel). File backup dan manifest berada di direktori privat.

Script tidak mengedit integrasi host. Jika import/instance berbeda dari kontrak yang diaudit, script berhenti. Deployment ini adalah jembatan kompatibilitas ke host Caelestia aktif, bukan implementasi runtime K41 standalone.

### Tahap 3 — Cleanup

Script cleanup dibuat terpisah dan hanya dijalankan setelah implementasi baru diverifikasi serta pengguna menyetujui target cleanup. Tanggung jawab minimal:

- Inventarisasi referensi, dependency, konfigurasi, dan file upstream yang menjadi target.
- Default dry-run; tampilkan tepat apa yang akan diubah/dihapus.
- Tolak target yang tidak cocok dengan provenance/hash yang diaudit.
- Backup seluruh target dan catat manifest.
- Terapkan hanya cleanup yang disetujui, verifikasi hasil, dan sediakan rollback.
- Jangan menghapus source Caelestia atau mengubah konfigurasi global secara luas tanpa bukti dependency dan persetujuan eksplisit.

## Baseline historis dan temuan awal

Source historis yang ditemukan:

- QML: `workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`.
- Installer lama: `stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`.
- Runtime target installer lama: `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`.
- Entry point host yang pernah dimodifikasi: `~/.config/quickshell/caelestia/shell.qml`.
- Konfigurasi yang pernah dimodifikasi: `~/.config/caelestia/shell.json`.

Inspeksi statis sebelumnya menunjukkan installer lama memiliki `--check`, `--install`, dan `--rollback`; membuat backup tiga target; menyalin QML; menambahkan import/instance ke `shell.qml`; serta menonaktifkan `bar.entries` di `shell.json`. Tidak ditemukan automatic rollback untuk kegagalan parsial. Temuan ini harus diperiksa ulang oleh audit baru terhadap perangkat dan source terkini.

Identitas workstream kini 03, sedangkan source historis masih berada pada direktori bernama `04-taskbar-panel`. Jangan memindahkan atau mengganti path sebelum seluruh referensi, ownership, dan dependency diperiksa.

## Perilaku baseline yang perlu dipertahankan atau diuji

- Menampilkan workspace pada monitor terkait.
- Membedakan workspace aktif dan workspace yang memiliki window.
- Mengganti workspace melalui klik.
- Menampilkan dock melalui trigger hover di tepi bawah.
- Menjaga dock tetap terlihat ketika pointer berada di dock dan menyembunyikannya setelah pointer keluar.
- Menyembunyikan dock ketika fullscreen toplevel aktif.
- Tidak memesan exclusive zone.

Ini adalah deskripsi source QML historis, bukan hasil regression test terkini.

## Dependency, API, dan desain integrasi — PLANNED

Audit harus memverifikasi versi Quickshell, Caelestia, Hyprland, Qt, modul QML, dan API yang benar-benar terpasang. Minimal telusuri `PanelWindow`, `WlrLayershell`, `HyprlandMonitor`, `Screens`, `Hypr.workspaces`, `Hypr.focusWorkspace()`, `ScriptModel`, dan dependency transitif. Petakan entry point, konfigurasi, lifecycle, monitor behavior, dan ownership. Dokumentasikan batas pemindaian statis; validasi upstream/API tidak boleh disimpulkan hanya dari nama import.

Hasil wajib: dependency map, integration map, daftar risiko/unknown, keputusan namespace source/runtime, dan kontrak host-loading yang dapat direview sebelum implementasi.

## Automated testing dan runtime verification — PLANNED

Test plan minimum:

- Bash syntax dan ShellCheck.
- Audit tidak mengubah HEAD, branch, index, tracked worktree, atau menulis report ke checkout.
- Path symlink, ownership salah, HOME/XDG path tidak aman, dependency hilang, dan source/runtime tidak tersedia.
- Installer install/repair ke lokasi import Caelestia yang diaudit, failure injection, automatic rollback, idempotensi, serta verifikasi bahwa `shell.qml` dan `shell.json` tidak berubah.
- QML lint/compile terhadap versi runtime yang dipin.
- Workspace switch, hover, fullscreen, monitor, reload, dan regression komponen Caelestia.
- Resource usage dan stabilitas yang relevan.

Test berbahaya harus menggunakan fixture/mock. Runtime verification dilakukan pada ThinkPad X280 dan mencatat versi, kondisi, perintah, hasil, serta batasan. Konfirmasi visual/interaksi akhir dilakukan pengguna.

## Batas keamanan

- Tidak menggunakan sudo untuk deployment user-level.
- Tidak mengubah PAM, autentikasi, lock/session protocol, system services, atau boot configuration.
- Tidak menimpa file lokal/upstream yang belum diidentifikasi.
- Audit tidak mengubah runtime atau Git metadata checkout aktif.
- Report lengkap bersifat privat; hanya salinan tersanitasi yang dipublikasikan otomatis melalui independent clone. Review report publik tetap wajib.
- Jangan mengklaim rollback, idempotensi, QML compatibility, atau runtime safety tanpa test yang relevan.

## Validasi, status, dan acceptance

- Report audit aktual X280 tersedia di `reports/stage-5-desktop-customization/03-bottombar/audits/20261112T170456Z/` dan telah ditinjau.
- Source kanonis `modules/bottombar/Dock.Qml` dan script install/repair telah ditambahkan.
- Automated fixture test telah ditambahkan ke `tests/run.sh`; eksekusinya belum diklaim.
- QML compile/runtime compatibility, visual behavior, multi-monitor, fullscreen, dan regression belum VERIFIED.
- Cleanup script tetap PLANNED dan tidak menjadi bagian dari installer.

Acceptance berikutnya: jalankan `bash -n`, ShellCheck, fixture test, lalu installer pada X280 sebagai user biasa. Setelah deployment, verifikasi QML/runtime dan perilaku visual/interaksi secara terpisah. Deployment ke host aktif tidak membuktikan bahwa namespace K41 standalone sudah tersedia. Catat IMPLEMENTED, TESTED, VERIFIED, dan penerimaan pengguna secara terpisah.
