# Stage 5 — Desktop Customization

Peta implementasi Stage 5. Status proyek dimiliki [docs/06-STATUS.md](../../docs/06-STATUS.md); prosedur dan acceptance tiap workstream dimiliki dokumen di [Stage 5 docs](docs/README.md).

## Tujuan

Stage 5 mengembangkan dan menyesuaikan komponen desktop satu per satu. Hasil yang relevan menjadi fondasi **K41-dots**, yaitu kumpulan modul Quickshell dengan namespace K41. Tidak ada target membangun shell mandiri penuh pada tahap ini.

## Struktur K41-dots yang dituju

Source yang direview disimpan di repository. Script penyiapan mendeploy modul ke runtime user:

```text
~/.config/quickshell/k41/
└── modules/
    ├── lockscreen/
    ├── bottombar/
    ├── topbar/
    ├── launcher/
    └── ...
```

WS02 menyimpan mirror visual Lock Screen pada `~/.config/quickshell/k41/modules/lockscreen/` dan `~/.config/quickshell/caelestia/k41/modules/lockscreen/`; overlay aktif tetap `~/.config/quickshell/caelestia/modules/lock/`. Untuk Bottombar dan Topbar, lokasi import utama berada di dalam config root Caelestia.

## Alur minimum per fitur

1. Audit source/config Caelestia yang berkaitan dengan fitur yang sedang dikerjakan.
2. Catat file utama, dependency upstream, konfigurasi, dan titik integrasi yang benar-benar diperlukan.
3. Siapkan hanya file/resource relevan ke namespace K41 melalui script penyiapan.
4. Integrasikan modul ke lingkungan Quickshell yang ada dengan perubahan minimum.
5. Verifikasi hasil dan dokumentasikan dependency yang tetap dimiliki upstream.

Audit harus read-only. Penyiapan/deployment adalah langkah terpisah yang melakukan perubahan secara eksplisit. Hindari framework installer, bootstrap, service, atau abstraksi tambahan sebelum dibutuhkan.

**Workstream 01 — Boot Experience dikecualikan dari K41-dots.** Jalur boot/splash menggunakan Plymouth. Workstream 01 tetap bagian dari proyek utama.

## Prinsip

- Caelestia tetap menjadi host/runtime yang digunakan selama belum ada keputusan baru.
- Modul utama K41 yang diimpor Caelestia berada di `quickshell/caelestia/k41/modules/<feature>/`; `quickshell/k41/modules/<feature>/` dipertahankan sebagai compatibility mirror.
- Jangan menyalin seluruh source Caelestia; ambil hanya bagian fitur dan resource yang dibutuhkan.
- Dependency upstream yang masih dipakai harus diidentifikasi, bukan diduplikasi tanpa alasan.
- Repository adalah sumber kanonis source, script, test, dan dokumentasi.
- Jangan mengubah konfigurasi autentikasi atau mekanisme session-lock untuk perubahan visual.

## Status dan urutan

Lihat [docs/06-STATUS.md](../../docs/06-STATUS.md) untuk status tunggal proyek dan [indeks workstream](docs/README.md) untuk rincian tiap fitur. Workstream 08 — Clean up Caelestia merupakan pekerjaan terakhir setelah seluruh workstream komponen Stage 5 selesai dan diterima.
