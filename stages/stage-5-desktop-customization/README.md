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
│   ├── 04-TASKBAR-PANEL.md
│   ├── 04-TASKBAR-PANEL-IMPLEMENTATION.md
│   ├── 05-TOPBAR.md
│   └── ...
├── scripts/
│   ├── k41-audit-caelestia.sh
│   ├── k41-cleanup-caelestia.sh
│   └── k41-install-caelestia-dock.sh
├── tests/
└── workstreams/
    ├── 01-boot-experience/
    ├── 02-lock-screen/
    └── 04-taskbar-panel/
        └── config/quickshell/caelestia/modules/k41dock/K41Dock.qml
```

## Prinsip Stage 5

- Setiap workstream dikerjakan bertahap dan terisolasi.
- Source kanonis, installer, test, dan dokumentasi disimpan di repository.
- Source/runtime Quickshell pada laptop berada di bawah `~/.config/quickshell/`. Integrasi Caelestia saat ini menggunakan `~/.config/quickshell/caelestia/`.
- Komponen K41 ditempatkan pada namespace milik K41, misalnya `modules/k41dock/K41Dock.qml`, dan bukan dengan mengubah source package-owned upstream yang tidak diperlukan.
- Hasil Stage 5 akan menjadi basis komponen, pola integrasi, deployment, dan pengujian untuk proyek lanjutan **k41-shell**. Stage 5 belum berarti proyek k41-shell mandiri sudah dibuat.

## Arah UI

- Dashboard dinonaktifkan dari runtime Caelestia; halaman Nexus belum dihapus dari source upstream.
- Bottombar menggunakan K41Dock dan hanya menampilkan indikator workspace.
- Topbar akan dibuat di tepi atas setelah elemen, alignment, ukuran, dan visibility disepakati.
- Launcher, Sidebar, dan Utilities mengikuti urutan pada [indeks workstream](docs/README.md).

## Audit dan cleanup

Audit Caelestia tetap tersedia melalui `scripts/k41-audit-caelestia.sh`. Cleanup Dashboard berjalan tanpa argumen:
`bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

Cleanup menetapkan `dashboard.enabled=false` pada konfigurasi global dan override monitor yang relevan, membuat backup, dan tidak menghapus source QML atau file package-owned. Runtime X280 harus dinilai dari hasil aktual, bukan dari keberadaan script.

## Validasi

Installer Bottombar mendukung `--check`, `--install`, dan `--rollback`. Lihat [dokumen implementasi K41Dock](docs/04-TASKBAR-PANEL-IMPLEMENTATION.md). Test statis/fixture tidak menggantikan pemeriksaan runtime dan penerimaan pengguna pada X280.
