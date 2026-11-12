# Workstream 03 — Bottombar

**Status: AUDIT IN PROGRESS.** Refactoring total direncanakan setelah audit selesai; belum ada perubahan implementasi/runtime yang diotorisasi pada tahap ini.

Implementasi yang diterima adalah `K41Dock.qml`, dock horizontal minimal di tepi bawah untuk indikator workspace Hyprland.

## Baseline implementasi historis (belum dinyatakan sebagai target akhir)

Bagian berikut mencatat kondisi yang ditemukan di repository. Keberadaan source dan konfirmasi keberhasilan sebelumnya tidak membuktikan bahwa desain, arsitektur, deployment, atau integrasinya masih sesuai dengan alur kerja Workstream 02.

- Source repository: `stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`
- Runtime historis: `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`
- Installer: `stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`

K41Dock menampilkan workspace pada monitor terkait, menandai workspace aktif/berisi window, mengganti workspace saat diklik, memakai trigger hover di tepi bawah, dan menghilang ketika fullscreen toplevel aktif. Komponen tidak memakai exclusive zone.

## Arah K41-Dots

K41-Dots menggunakan namespace runtime K41 yang terpisah:

`~/.config/quickshell/k41/modules/bottombar/`

Source dan deployment K41Dock akan dipindahkan/disesuaikan ke struktur tersebut pada pekerjaan migrasi terpisah. Desain dan perilaku yang telah diterima tidak berubah hanya karena perpindahan lokasi.

Caelestia tetap menjadi host. Integrasi dilakukan seperlunya; jangan menyalin seluruh source Caelestia atau membuat runtime/bootstrapping K41 mandiri.

## Ruang lingkup audit

Audit mencakup keselarasan alur kerja dengan Workstream 02, ownership source/runtime, struktur direktori dan namespace, dependency/API Quickshell-Hyprland-Caelestia, desain dan perilaku UI, installer/check/rollback, backup dan failure handling, idempotency, security, test coverage, dokumentasi, serta acceptance dan regression.

## Temuan awal

1. **Struktur source belum selaras:** source masih berada di `workstreams/04-taskbar-panel/`, sedangkan identitas workstream dan dokumen sudah Workstream 03. Installer masih hard-code path lama tersebut.
2. **Runtime masih terikat pada Caelestia:** installer mengubah `shell.qml` dan `shell.json`, menambahkan import/instance ke shell upstream, dan menonaktifkan seluruh `bar.entries`. Ini perlu dibandingkan dengan pola ownership, isolasi, preflight, dan deployment Workstream 02.
3. **Kontrak migrasi K41 belum diwujudkan:** dokumen menyebut namespace `~/.config/quickshell/k41/modules/bottombar/`, tetapi installer/source yang diaudit masih deploy ke `~/.config/quickshell/caelestia/modules/k41dock/`.
4. **Rollback/failure handling perlu diperiksa:** installer membuat backup sebelum perubahan, tetapi tidak memiliki trap/rollback otomatis bila operasi berhenti setelah sebagian target berubah. Rollback manual mengubah file runtime dan perlu validasi tambahan.
5. **Validasi terbatas:** `--check` memeriksa struktur precondition dan JSON, tetapi tidak memvalidasi QML compile/runtime, versi/API dependency, kondisi target aktual, atau hasil interaksi. Tidak ditemukan test khusus Bottombar dari pencarian repository yang dilakukan; status ini perlu dikonfirmasi melalui pemeriksaan tree/test suite penuh.
6. **Bukti perangkat tidak cukup untuk klaim luas:** konfirmasi pengguna terdahulu menyatakan komponen berhasil digunakan, tetapi tidak membuktikan regression terkini, multi-monitor, fullscreen edge cases, resource use, atau kompatibilitas setelah migrasi.

Temuan ini adalah hasil inspeksi statis repository, bukan hasil eksekusi test atau pemeriksaan laptop. Klasifikasi final dan prioritas remediasi menunggu audit dependency, test, serta bukti runtime yang relevan.

## Batas klaim

Penerimaan pengguna menutup scope Bottombar yang diserahkan. Hal tersebut tidak membuktikan seluruh versi Quickshell, multi-monitor, semua edge-case fullscreen, atau konsumsi resource telah diuji terukur. Status runtime setelah migrasi namespace perlu diverifikasi kembali.

## Pemeliharaan

- Pertahankan perilaku K41Dock yang sudah diterima kecuali ada permintaan perubahan/regresi.
- Jangan menduplikasi workspace dock pada Topbar atau komponen lain.
- Audit dependency dan titik integrasi sebelum migrasi.
- Simpan source kanonis di repository; deploy modul ke namespace runtime K41 melalui script penyiapan terpisah.
