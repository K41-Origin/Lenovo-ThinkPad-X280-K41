# Bottombar — Historical Implementation Record

## Tujuan dokumen

Dokumen ini menyimpan catatan implementasi Bottombar sebelum audit dan refactoring Workstream 03. Isinya adalah baseline historis, bukan spesifikasi arsitektur target atau instruksi deployment yang telah disetujui.

Status dan workflow kanonis berada di [Workstream 03 — Bottombar](03-BOTTOMBAR.md), yang telah ditutup sebagai COMPLETED / USER ACCEPTED. Catatan ini hanya baseline historis; jangan menjalankan installer historis atau memigrasikan source/runtime berdasarkan dokumen ini. Penghapusan legacy K41Dock secara manual oleh pengguna bukan bukti cleanup seluruh Caelestia selesai; audit luas dijadwalkan pada [Workstream 09 — Clean up Caelestia](09-CLEAN-UP-CAELESTIA.md).

## Lokasi historis

| Jenis | Path |
|---|---|
| Source repository historis | `stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml` |
| Runtime target installer historis | `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml` |
| Entry point Caelestia yang dimodifikasi | `~/.config/quickshell/caelestia/shell.qml` |
| Runtime config yang dimodifikasi | `~/.config/caelestia/shell.json` |
| Backup dan log historis | `~/.local/state/k41/backups/caelestia-dock/<timestamp>/` |

Path tersebut menjelaskan implementasi lama yang ditemukan pada source installer. Keberadaan path tidak membuktikan kondisi runtime laptop saat ini.

## Perilaku historis K41Dock

- Menampilkan workspace pada monitor yang sesuai.
- Workspace aktif memiliki indikator lebih menonjol; workspace berisi window memiliki penanda berbeda.
- Klik indikator memanggil `Hypr.focusWorkspace()`.
- Trigger hover selebar layar berada di tepi bawah.
- Dock tetap terlihat ketika pointer berada di dock dan disembunyikan setelah pointer meninggalkannya.
- Menggunakan `exclusiveZone: 0`.
- Dock disembunyikan ketika monitor memiliki fullscreen toplevel aktif.
- Menggunakan `PanelWindow`, `WlrLayershell`, dan API Hyprland melalui Quickshell.

Perilaku di atas adalah deskripsi source QML historis, bukan hasil regression test terbaru.

## Installer historis

Entry point:

`stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`

Mode yang tersedia:

- `--check`: memeriksa beberapa precondition struktur source/runtime.
- `--install`: membuat backup target, menyalin QML, memodifikasi `shell.qml`, dan mengubah `bar.entries` pada `shell.json`.
- `--rollback BACKUP_DIRECTORY`: memulihkan target dari manifest backup.

Batas yang diketahui dari inspeksi statis:

- Tidak menggunakan sudo atau memasang paket.
- Tidak me-restart service atau me-reload Quickshell secara otomatis.
- Rollback dijalankan manual.
- Tidak ditemukan automatic rollback untuk kegagalan parsial dalam source yang diperiksa.
- Validasi source dan hasil perubahan belum membuktikan QML compile atau runtime behavior.

Jangan gunakan perintah install/rollback di dokumen lama ini sebelum audit dan refactoring menghasilkan prosedur baru yang disetujui.

## Catatan penerimaan historis

Pengguna sebelumnya mengonfirmasi Bottombar berhasil digunakan. Catatan ini dipertahankan sebagai histori penerimaan desain/implementasi terdahulu. Hal itu tidak membuktikan seluruh skenario multi-monitor, fullscreen, dependency compatibility, resource usage, atau regression telah diuji.

## Perubahan yang menunggu audit

- Konsolidasi identitas direktori menjadi Workstream 03.
- Pemisahan source K41 dan integrasi host Caelestia.
- Deployment modul K41 dengan nama file `.qml` dan relative directory import dari Caelestia.
- Perbaikan preflight, staging, atomic deployment, failure handling, rollback, logging, dan idempotensi.
- Automated tests dan runtime verification.
- Penetapan acceptance criteria dan dokumentasi operasional baru.

Catatan historis ini tidak lagi menjadi instruksi implementasi. Status aktual, target canonical, dan prosedur deployment berada di `03-BOTTOMBAR.md`.
