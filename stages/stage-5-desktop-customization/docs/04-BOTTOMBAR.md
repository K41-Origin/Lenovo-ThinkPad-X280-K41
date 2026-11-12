# Workstream 04 — Bottombar

**Status: COMPLETED / USER CONFIRMED SUCCESS.**

Implementasi yang diterima adalah `K41Dock.qml`, dock horizontal minimal di tepi bawah untuk indikator workspace Hyprland.

## Hasil implementasi saat ini

- Source repository: `stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml`
- Runtime historis: `~/.config/quickshell/caelestia/modules/k41dock/K41Dock.qml`
- Installer: `stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh`

K41Dock menampilkan workspace pada monitor terkait, menandai workspace aktif/berisi window, mengganti workspace saat diklik, memakai trigger hover di tepi bawah, dan menghilang ketika fullscreen toplevel aktif. Komponen tidak memakai exclusive zone.

## Arah K41-Dots

K41-Dots menggunakan namespace runtime K41 yang terpisah:

`~/.config/quickshell/k41/modules/bottombar/`

Source dan deployment K41Dock akan dipindahkan/disesuaikan ke struktur tersebut pada pekerjaan migrasi terpisah. Desain dan perilaku yang telah diterima tidak berubah hanya karena perpindahan lokasi.

Caelestia tetap menjadi host. Integrasi dilakukan seperlunya; jangan menyalin seluruh source Caelestia atau membuat runtime/bootstrapping K41 mandiri.

## Batas klaim

Penerimaan pengguna menutup scope Bottombar yang diserahkan. Hal tersebut tidak membuktikan seluruh versi Quickshell, multi-monitor, semua edge-case fullscreen, atau konsumsi resource telah diuji terukur. Status runtime setelah migrasi namespace perlu diverifikasi kembali.

## Pemeliharaan

- Pertahankan perilaku K41Dock yang sudah diterima kecuali ada permintaan perubahan/regresi.
- Jangan menduplikasi workspace dock pada Topbar atau komponen lain.
- Audit dependency dan titik integrasi sebelum migrasi.
- Simpan source kanonis di repository; deploy modul ke namespace runtime K41 melalui script penyiapan terpisah.
