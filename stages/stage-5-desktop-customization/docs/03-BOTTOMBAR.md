# Workstream 03 — Bottombar

**Status: AUDIT IN PROGRESS.** Tahap ini menetapkan workflow tiga script dan memperbarui alat audit. Refactoring komponen, deployment, dan cleanup runtime belum dilakukan atau diotorisasi.

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
| 1 | `scripts/k41-audit-bottombar.sh` | Mengumpulkan baseline source/runtime, provenance, dependency, API, konfigurasi, versi, installer lama, test, dan integrasi. Read-only. | **IMPLEMENTED — audit diperbarui; eksekusi pada X280 menunggu** |
| 2 | `scripts/k41-implement-bottombar.sh` | Preflight dan implementasi/deployment modul K41 berdasarkan keputusan arsitektur yang disetujui; backup, atomic staging, verifikasi, log, dan automatic rollback. | PLANNED |
| 3 | `scripts/k41-cleanup-bottombar.sh` | Audit target cleanup, dry-run, backup, penghapusan/nonaktifkan komponen yang disetujui, verifikasi, dan rollback. | PLANNED |

Script ditempatkan di `stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/`. Source QML kanonis dan path runtime final belum dipindahkan/ditetapkan; jangan menyimpulkan bahwa path legacy otomatis menjadi arsitektur target.

### Tahap 1 — Audit dan pengumpulan bukti

Jalankan dari Git checkout repository, branch `main`, sebagai user desktop biasa tanpa sudo:

```bash
bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-audit-bottombar.sh
```

Laporan disimpan privat di:

```text
~/.local/state/k41/bottombar/audits/<timestamp>/bottombar-audit.txt
```

Audit mengumpulkan:

- Repository HEAD, status branch/worktree/index sebagai observasi read-only.
- Source K41 legacy, seluruh file terkait, ukuran dan SHA-256.
- Root Caelestia user/XDG/system yang ditemukan, provenance Git jika tersedia, metadata runtime, dan file Bottombar yang sudah terpasang.
- Titik integrasi pada `shell.qml` serta metadata `bar.entries` dari konfigurasi JSON tanpa mencetak seluruh konfigurasi.
- Isi installer historis, mode operasi, target perubahan, backup/manifest, dan indikasi rollback.
- Import QML, API yang dipakai, relative import, dan kandidat type yang perlu diverifikasi.
- Versi Quickshell/Caelestia/Hyprland/Qt, package metadata, serta ketersediaan `qmllint`, `qmlformat`, dan ShellCheck.
- Inventaris tests, source, dokumentasi, dan artefak workstream yang relevan.
- Ringkasan keterbatasan dan input yang dibutuhkan untuk desain implementasi.

Audit bersifat read-only terhadap source, runtime, konfigurasi, package, service, dan Git. Satu-satunya write adalah report privat di luar checkout. Script tidak melakukan fetch, checkout, reset, clean, stash, add, commit, push, atau mengubah index/HEAD/FETCH_HEAD. Karena report tidak ditulis ke dalam repository, audit tidak meninggalkan untracked report yang dapat menghalangi pull atau perpindahan branch.

Report berisi cuplikan source dan metadata host/package. Review dan sanitasi sebelum dibagikan. Audit statis tidak membuktikan QML compile atau runtime behavior.

**Acceptance tahap audit:** report lengkap tersedia; setiap target/source runtime diklasifikasikan; dependency/API dan integration map memiliki bukti; unknown/missing data ditandai; tidak ada perubahan runtime atau Git checkout.

### Tahap 2 — Implementasi

Script implementasi baru dibuat setelah report audit ditinjau dan arsitektur target disetujui. Tanggung jawab minimal:

1. Validasi user/session, versi, dependency, repository, source, dan target.
2. Tolak symlink, ownership/path ambigu, serta file lokal yang tidak dikenal atau berubah.
3. Pastikan kontrak host-loading dan konfigurasi yang dibutuhkan berdasarkan hasil audit.
4. Buat backup/checksum manifest sebelum mutasi pertama.
5. Stage file dan gunakan atomic replacement jika sesuai.
6. Verifikasi seluruh hasil; lakukan automatic rollback jika tahapan deployment gagal.
7. Simpan log privat dan sediakan check/dry-run tanpa mutasi.
8. Idempotent saat dijalankan ulang; tidak reload/restart shell kecuali perilaku tersebut disetujui dan diuji.

Tidak boleh mengimplementasikan berdasarkan asumsi namespace `~/.config/quickshell/k41/` atau mengubah `shell.qml`/`shell.json` sebelum kebutuhan dan API loading dibuktikan.

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
- Installer check/dry-run, install, failure injection, automatic rollback, rollback manual jika disediakan, dan idempotensi.
- QML lint/compile terhadap versi runtime yang dipin.
- Workspace switch, hover, fullscreen, monitor, reload, dan regression komponen Caelestia.
- Resource usage dan stabilitas yang relevan.

Test berbahaya harus menggunakan fixture/mock. Runtime verification dilakukan pada ThinkPad X280 dan mencatat versi, kondisi, perintah, hasil, serta batasan. Konfirmasi visual/interaksi akhir dilakukan pengguna.

## Batas keamanan

- Tidak menggunakan sudo untuk deployment user-level.
- Tidak mengubah PAM, autentikasi, lock/session protocol, system services, atau boot configuration.
- Tidak menimpa file lokal/upstream yang belum diidentifikasi.
- Audit tidak mengubah runtime atau Git metadata.
- Log/report privat; review dan sanitasi sebelum publikasi.
- Jangan mengklaim rollback, idempotensi, QML compatibility, atau runtime safety tanpa test yang relevan.

## Validasi, status, dan acceptance

- Baseline QML dan installer historis telah diperiksa secara statis dari GitHub.
- Audit script baru telah ditambahkan ke repository; eksekusi di ThinkPad X280 dan hasil report belum tersedia.
- Dependency/API audit lengkap, desain arsitektur, implementasi, cleanup, QML runtime test, dan regression masih PLANNED.
- Workstream tetap **AUDIT IN PROGRESS** sampai report aktual ditinjau dan arsitektur disetujui.

Sebelum script implementasi dibuat, harus tersedia: (1) report audit X280, (2) dependency/integration map, (3) keputusan source/runtime ownership dan host contract, (4) daftar target dan perubahan, (5) strategi backup/rollback/logging, serta (6) acceptance dan test plan. Penutupan workstream mencatat IMPLEMENTED, TESTED, VERIFIED, dan penerimaan pengguna secara terpisah.
