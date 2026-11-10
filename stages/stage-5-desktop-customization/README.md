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
│   ├── 04-TASKBAR-PANEL.md      # Bottombar
│   ├── 05-TOPBAR.md
│   └── ...
├── scripts/
│   ├── k41-audit-caelestia.sh
│   └── k41-cleanup-caelestia.sh # Direct Dashboard cleanup
├── tests/
└── workstreams/
    ├── 01-boot-experience/
    └── 02-lock-screen/
```

## Stage 5 UI direction

- Dashboard dihapus dari implementasi.
- Taskbar/Panel diarahkan menjadi **Bottombar**: dock horizontal minimal di tepi bawah, berisi indikator workspace saja.
- **Topbar** akan dibuat di tepi atas. Daftar elemen, alignment, ukuran, dan visibility harus disepakati sebelum implementasi.
- Audit Caelestia tetap tersedia melalui `scripts/k41-audit-caelestia.sh`. Script cleanup terpisah dan berjalan langsung tanpa mode atau argumen:
  `bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

## Existing implementation ownership

Workstream 1–2 dan artefak implementasinya tetap berada pada direktori yang sudah ada. Stage 5 support scripts dan audit tetap canonical di `scripts/`; output runtime berada di `reports/stage-5-desktop-customization/`.

## Safety dan validasi

Cleanup hanya menghapus properti `dashboard` dari Caelestia `shell.json` dan direktori `modules/dashboard`. Script menolak root, argumen, symlink, serta direktori Dashboard di source checkout Git yang memiliki perubahan lokal. Jalankan sebagai pengguna biasa. Modul lain tidak menjadi target.

Test statis dan fixture tidak membuktikan runtime visual. Setelah menjalankan cleanup, validasi konfigurasi dan sesi Caelestia pada X280.
