# Stage 5 — Desktop Customization

Peta fisik dan ownership implementasi Stage 5. Status proyek tetap dimiliki [docs/06-STATUS.md](../../docs/06-STATUS.md); prosedur dan acceptance tiap workstream tetap dimiliki dokumen di [Stage 5 workstream docs](docs/README.md).

## Struktur kanonis

```text
stages/stage-5-desktop-customization/
├── README.md
├── docs/
├── scripts/
│   ├── k41-audit-caelestia.sh
│   └── k41-cleanup-caelestia.sh # Disable Dashboard via supported config
├── tests/
└── workstreams/
```

## Stage 5 UI direction

- Dashboard dinonaktifkan dari runtime Caelestia.
- Taskbar/Panel diarahkan menjadi **Bottombar**: dock horizontal minimal di tepi bawah, berisi indikator workspace saja.
- **Topbar** akan dibuat di tepi atas. Daftar elemen, alignment, ukuran, dan visibility harus disepakati sebelum implementasi.
- Audit Caelestia tetap tersedia melalui `scripts/k41-audit-caelestia.sh`. Cleanup berjalan langsung tanpa mode atau argumen:
  `bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

## Dashboard cleanup scope

Laporan audit `20261110T174657Z` menunjukkan:
- Global `~/.config/caelestia/shell.json` valid dan memiliki `dashboard.enabled: true`.
- Per-monitor `monitors/eDP-1/shell.json` valid tetapi tidak memiliki bagian `dashboard`; ia mewarisi konfigurasi global.
- File sumber di `modules/dashboard/` yang diinventarisasi tidak ditemukan.
- Referensi Dashboard masih ada pada Nexus (`PageRegistry.qml`, `PageCompRegistry.qml`, `PanelsPage.qml`, dan `DashboardPanel.qml`) serta drawer interaction files.
- Audit tidak menemukan candidate Hyprland keybind terkait Dashboard.

Karena itu cleanup tidak lagi menghapus properti konfigurasi (yang dapat mengembalikan default upstream `enabled: true`) dan tidak menghapus source QML. Script menetapkan `dashboard.enabled=false` pada global config dan pada file monitor yang memang memiliki override Dashboard. Semua file kandidat divalidasi sebelum perubahan; backup bertimestamp dibuat sebelum penggantian atomik. Pengaturan lain dipertahankan.

**Batasan yang diketahui:** script ini menonaktifkan Dashboard runtime melalui konfigurasi. Entry Dashboard di halaman Nexus dan referensi upstream QML tetap ada, sehingga penghapusan total dari antarmuka Nexus memerlukan refactoring source-level terpisah. Script tidak mengklaim telah menghapus entry tersebut atau mengubah file package-owned.

## Safety dan validasi

Jalankan sebagai pengguna biasa, tanpa `sudo` dan tanpa argumen. Script menolak root, path konfigurasi symlink/non-regular, JSON invalid, dan struktur Dashboard yang tidak sesuai. Ia tidak menghapus source checkout atau file package-owned.

Fixture test: `tests/test-caelestia-dashboard-cleanup.sh`. Test statis/fixture tidak membuktikan runtime visual; runtime X280 tetap perlu diverifikasi setelah cleanup.
