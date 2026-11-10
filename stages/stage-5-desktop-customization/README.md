# Stage 5 — Desktop Customization

Peta fisik dan ownership implementasi Stage 5. Status proyek tetap dimiliki [docs/06-STATUS.md](../../docs/06-STATUS.md); prosedur dan acceptance tiap workstream tetap dimiliki dokumen di [Stage 5 workstream docs](docs/README.md).

## Struktur kanonis

```text
stages/stage-5-desktop-customization/
├── README.md
├── docs/
│   ├── 00-COLLABORATION-WORKFLOW.md
│   ├── 01-BOOT-EXPERIENCE.md
│   ├── 02-LOCK-SCREEN.md
│   ├── 03-DASHBOARD.md          # retired decision record
│   ├── 04-TASKBAR-PANEL.md      # Bottombar
│   ├── 05-TOPBAR.md
│   └── ...
├── scripts/
│   └── k41-cleanup-caelestia.sh # planned; not implemented
├── tests/
└── workstreams/
    ├── 01-boot-experience/
    └── 02-lock-screen/
```

## Stage 5 UI direction

- Dashboard dihentikan karena tidak diperlukan. Tidak ada dashboard baru yang akan dibuat.
- Taskbar/Panel diarahkan menjadi **Bottombar**: dock horizontal minimal di tepi bawah, berisi indikator workspace saja.
- **Topbar** akan dibuat di tepi atas. Daftar elemen, alignment, ukuran, dan visibility harus disepakati sebelum implementasi.
- Cleanup konfigurasi Caelestia akan menggunakan entry point `scripts/k41-cleanup-caelestia.sh`; script ini masih PLANNED dan belum tersedia.

## Existing implementation ownership

Workstream 1–2 dan artefak implementasinya tetap berada pada direktori yang sudah ada. Stage 5 support scripts dan audit tetap canonical di `scripts/`; output runtime berada di `reports/stage-5-desktop-customization/`.

## Safety dan validasi

Cleanup harus dimulai dengan audit read-only dan backup. Jangan menghapus source checkout upstream, file konfigurasi yang kepemilikannya tidak jelas, atau perubahan pengguna yang tidak terkait. Sediakan rollback dan lakukan validasi config/QML/runtime setelah perubahan. Jangan menjalankan privileged operation atau mengubah sistem nyata hanya untuk memvalidasi rancangan.

Test statis tidak membuktikan runtime visual. Review visual/interaksi dilakukan langsung oleh pengguna pada X280; screenshot bukan acceptance gate.
