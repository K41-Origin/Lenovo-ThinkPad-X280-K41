# Stage 5 — Alur Kolaborasi dan Verifikasi

## Tujuan

Dokumen ini menetapkan alur kerja Stage 5. Hasil yang relevan menjadi fondasi **K41-dots**, kumpulan modul Quickshell milik K41. Ini bukan proyek shell mandiri pada tahap ini. Workstream 01 — Boot Experience dikecualikan karena boot/splash menggunakan Plymouth.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; mengimplementasikan source, script, test, dan dokumentasi; memverifikasi perubahan GitHub. |
| Pengguna | Menjalankan audit/test/deployment pada X280 bila diperlukan; memeriksa dampak runtime dan menerima hasil. |

Commit sukses tidak membuktikan perilaku runtime pada laptop.

## Source dan runtime

- Repository adalah sumber kanonis source yang direview, script, test, dan dokumentasi.
- Runtime modul K41 berada di `~/.config/quickshell/k41/modules/<feature>/`.
- Contoh Lock Screen: `~/.config/quickshell/k41/modules/lockscreen/`.
- Caelestia tetap menjadi host/runtime selama belum ada keputusan baru.
- Namespace K41 dipisahkan dari `~/.config/quickshell/caelestia/`; jangan menaruh source K41 di dalam direktori internal Caelestia.
- Backup runtime tidak di-commit.

## Alur minimum per fitur

1. **Audit upstream** — script read-only memeriksa source/config Caelestia yang berkaitan dengan fitur tersebut. Kumpulkan file utama, resource, dependency, konfigurasi, dan titik integrasi yang diperlukan saja.
2. **Review hasil audit** — pastikan mana source yang akan menjadi milik K41 dan mana dependency yang tetap disediakan upstream.
3. **Siapkan modul** — script terpisah menyalin source/resource yang dipilih ke `~/.config/quickshell/k41/modules/<feature>/`. Jangan gabungkan audit read-only dengan operasi tulis.
4. **Integrasikan seperlunya** — lakukan perubahan minimum agar modul K41 digunakan oleh lingkungan Quickshell yang ada.
5. **Verifikasi** — periksa file hasil, dependency, konfigurasi, pemuatan QML, dan perilaku fitur yang relevan.

Tidak perlu membuat bootstrap, service, updater, framework installer, atau runtime K41 mandiri sebelum kebutuhan nyata muncul.

## Siklus perubahan

1. Periksa branch, file terkait, konfigurasi, dan implementasi upstream.
2. Tetapkan scope dan acceptance sebelum mengubah source.
3. Periksa isi dan SHA file sebelum menulis ke GitHub.
4. Buat perubahan kecil dan verifikasi hasil write.
5. Jalankan test statis/fixture yang relevan.
6. Pengujian runtime dilakukan pada X280 bila diperlukan; laporkan hasil aktual, bukan asumsi.

## Script Stage 5

Audit Caelestia yang ada:
`bash stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh`

Script ini masih memiliki cakupan audit lama dan akan disederhanakan mengikuti alur audit per fitur. Jangan menganggap audit lama sebagai implementasi final K41-dots.

## Klasifikasi hasil

Gunakan status kanonis dari [AGENTS.md](../../../AGENTS.md): PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED. Jelaskan bukti dan batas klaim untuk setiap status.

Status keseluruhan Stage 5 hanya dicatat di [docs/06-STATUS.md](../../../docs/06-STATUS.md).
