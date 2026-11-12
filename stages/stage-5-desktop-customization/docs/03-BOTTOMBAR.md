# Workstream 03 — Bottombar

**Status: COMPLETED / USER ACCEPTED.** Implementasi Bottombar K41 dan integrasi host Caelestia sesuai arsitektur yang disepakati telah diselesaikan. Cleanup sisa fitur Caelestia dipisahkan ke Workstream 09 dan dikerjakan paling akhir.

Dokumen ini adalah dokumen pemilik Workstream 03. Pola dokumentasi dan urutan kerja mengikuti Workstream 02, tetapi implementasi Bottombar tetap disesuaikan dengan hasil audit dan kontrak Quickshell/Caelestia yang benar-benar terverifikasi.

## Tujuan dan batas ownership

- Menyediakan Bottombar K41 untuk indikator dan navigasi workspace Hyprland.
- Menjaga source, script, test, dan dokumentasi K41 di repository sebagai sumber kanonis.
- Menempatkan source dan deployment modul di namespace K41, sementara Caelestia tetap menjadi shell host/runtime.
- Mempertahankan perilaku Bottombar yang sebelumnya diterima pengguna kecuali audit menemukan masalah atau perubahan disetujui.
- Memastikan setiap perubahan runtime memiliki preflight, backup, verifikasi pascaperubahan, logging, dan rollback yang diuji.
- Audit harus read-only terhadap runtime dan Git checkout.

## Workflow kanonis — audit dan implementasi

Urutan pengerjaan mengikuti pola Workstream 02. Audit dan implementasi memiliki ownership dan tanggung jawab terpisah; tidak digabung menjadi satu installer serba guna. Cleanup Caelestia bukan bagian dari Workstream 03.

| Urutan | Script | Tanggung jawab | Status |
|---:|---|---|---|
| 1 | `scripts/k41-audit-bottombar.sh` | Mengumpulkan baseline source/runtime, provenance, dependency, API, konfigurasi, versi, installer lama, test, dan integrasi. Read-only. | **IMPLEMENTED — audit X280 selesai; baseline 2026-11-12** |
| 2 | `scripts/k41-implement-bottombar.sh` | Deploy `Dock.qml` ke namespace K41 dan migrasikan import/instance Bottombar di Caelestia `shell.qml` dari `k41dock` ke modul canonical K41. Backup privat, atomic replacement, verifikasi, dan rollback dua target. | **IMPLEMENTED — VALIDASI BELUM DIJALANKAN** |

Source kanonis berada di `stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.qml`. Target runtime adalah `~/.config/quickshell/k41/modules/bottombar/Dock.qml`. Caelestia tetap dijalankan melalui `~/.config/quickshell/caelestia/shell.qml` dan mengimpor direktori K41 melalui path relatif `../k41/modules/bottombar`.

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
- Root runtime K41 dan Caelestia user/XDG/system, target `modules/bottombar/Dock.qml`, entry point, provenance Git jika tersedia, metadata, ownership, permission, dan file modul yang sudah terpasang.
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
workstreams/03-bottombar/modules/bottombar/Dock.qml
```

Jalankan dari Git checkout sebagai user desktop biasa:

```bash
bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-implement-bottombar.sh
```

Installer dan fixture test menggunakan target `~/.config/quickshell/k41/modules/bottombar/Dock.qml`. Script tetap satu operasi install/repair. Selain deployment modul, script mengganti tepat satu pasangan import/instance legacy `K41Dock` di Caelestia `shell.qml` menjadi import relatif `../k41/modules/bottombar` dan instance `K41Bottombar.Dock {}`. Perubahan host dan modul memiliki backup privat, staging, verifikasi, serta rollback jika salah satu atomic replacement gagal.

**Pemetaan source, runtime module, dan host:**

```text
Source kanonis: stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.qml
Runtime module: ~/.config/quickshell/k41/modules/bottombar/Dock.qml
Caelestia host: ~/.config/quickshell/caelestia/shell.qml
```

Namespace `~/.config/quickshell/k41` hanya menjadi lokasi ownership/deployment modul K41, bukan shell mandiri. Caelestia tetap menjadi host; `shell.qml` mengimpor `../k41/modules/bottombar` dan menginstansiasi `K41Bottombar.Dock {}`.

Perilaku script:
- Menolak root/sumber/target symlink, path tidak aman, dan file yang bukan regular file.
- Memastikan direktori induk Quickshell tersedia; membuat namespace K41 dan direktori modul jika belum ada; menolak symlink, tipe file, dan ownership yang tidak aman.
- Membaca dan memperbarui hanya pasangan import/instance Bottombar yang dikenali pada `shell.qml`; tidak mengubah struktur `ShellRoot`, `shell.json`, konfigurasi system-wide, paket, atau service.
- Jika module dan import/instance host sudah sesuai, berhenti tanpa perubahan.
- Jika ada perubahan, membuat backup privat dan manifest checksum untuk modul serta `shell.qml` sebelum atomic replacement.
- Memverifikasi kedua target; kegagalan setelah salah satu perubahan memicu pemulihan otomatis dari backup.
- Tidak me-reload atau me-restart Quickshell.

Backup disimpan di `$XDG_STATE_HOME/k41/backups/bottombar/<timestamp>/` (atau `~/.local/state/...` jika XDG_STATE_HOME tidak disetel). File backup dan manifest berada di direktori privat.

Script hanya menerima salah satu dari dua keadaan host: pasangan legacy `import "modules/k41dock" as K41Dock` + `K41Dock.K41Dock {}`, atau pasangan baru yang sudah terpasang. Jika ditemukan struktur lain, duplikasi, atau modifikasi manual yang tidak dikenali, script berhenti tanpa mengubah file. Script tidak menghapus file legacy `modules/k41dock/K41Dock.qml`; penghapusan tersebut merupakan cleanup terpisah setelah runtime baru diverifikasi.

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

## Dependency, API, dan desain integrasi — IMPLEMENTED / RUNTIME VERIFICATION PLANNED

Audit harus memverifikasi versi Quickshell, Caelestia, Hyprland, Qt, modul QML, dan API yang benar-benar terpasang. Minimal telusuri `PanelWindow`, `WlrLayershell`, `HyprlandMonitor`, `Screens`, `Hypr.workspaces`, `Hypr.focusWorkspace()`, `ScriptModel`, dan dependency transitif. Petakan entry point, konfigurasi, lifecycle, monitor behavior, dan ownership. Dokumentasikan batas pemindaian statis; validasi upstream/API tidak boleh disimpulkan hanya dari nama import.

Kontrak integrasi yang dipakai: `shell.qml` Caelestia mengimpor `../k41/modules/bottombar` sebagai `K41Bottombar` dan membuat `K41Bottombar.Dock {}`. Ini menggunakan relative directory import QML; nama file harus berakhiran `.qml` agar otomatis diekspos sebagai type tanpa `qmldir`. Kompatibilitas runtime tetap harus diuji pada Quickshell/Caelestia yang terpasang di X280.

## Automated testing dan runtime verification — PLANNED

Test plan minimum:

- Bash syntax dan ShellCheck.
- Audit tidak mengubah HEAD, branch, index, tracked worktree, atau menulis report ke checkout.
- Path symlink, ownership salah, HOME/XDG path tidak aman, dependency hilang, dan source/runtime tidak tersedia.
- Installer deploy/repair namespace K41, migrasi import Caelestia, failure injection, automatic rollback dua file, idempotensi, dan fail-closed jika host berubah.
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
- Source canonical `modules/bottombar/Dock.qml`, installer integrasi Caelestia, dan fixture test telah diperbarui.
- Pengguna menyatakan file runtime legacy K41Dock telah dihapus secara manual. Penghapusan tersebut tidak dilakukan oleh installer Workstream 03 dan kondisi runtime terkini tidak diverifikasi oleh repository.
- Fixture test mencakup deploy, migrasi host, idempotensi, repair, rollback, dan host state ambigu; eksekusinya belum diklaim.
- Bash syntax, ShellCheck, fixture execution, QML compile/runtime compatibility, visual behavior, multi-monitor, fullscreen, dan regression belum VERIFIED.
- Workstream 03 ditutup sebagai COMPLETED / USER ACCEPTED sesuai keputusan pengguna; status ini tidak menyatakan seluruh detail teknis telah TESTED atau VERIFIED.
- Audit dan cleanup legacy Caelestia yang lebih luas dipindahkan ke Workstream 09 — Clean up Caelestia, yang wajib dikerjakan setelah semua workstream Stage 5 selesai.

Acceptance berikutnya: jalankan `bash -n`, ShellCheck, fixture test, lalu installer pada X280 sebagai user biasa. Setelah deployment, verifikasi QML/runtime dan perilaku visual/interaksi secara terpisah. Deployment modul dan perubahan import belum membuktikan QML berhasil dimuat atau tampilan bekerja; verifikasi runtime pada Caelestia tetap wajib. Catat IMPLEMENTED, TESTED, VERIFIED, dan penerimaan pengguna secara terpisah.
