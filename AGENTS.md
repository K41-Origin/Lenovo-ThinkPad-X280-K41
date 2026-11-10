# AI Development Instructions

## Source of truth

- Branch `main` dan implementasi repository adalah sumber kebenaran kode.
- `docs/06-STATUS.md` adalah sumber status proyek terkini.
- Setiap topik memiliki satu dokumen pemilik; dokumen lain harus merangkum singkat dan menautkan pemiliknya.
- `docs/archive/` berisi histori, bukan prosedur aktif. Jangan membaca arsip untuk tugas rutin kecuali dokumen aktif secara eksplisit memerlukan bukti historis.
- Jangan menyimpulkan kondisi perangkat saat ini dari laporan lama atau percakapan sebelumnya.

## Canonical entry points

1. `stages/stage-1-live-readiness/scripts/k41-live-validation.sh` — Arch ISO readiness, read-only.
2. `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh` — instalasi dasar Arch; destruktif.
3. `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh` — setup desktop dari Arch terpasang melalui TTY.
4. `stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` — validasi desktop read-only; jalankan sebagai user biasa dalam sesi Hyprland.
5. `stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh` — remediasi terbatas yang dapat mengubah paket/service/Bluetooth; jalankan hanya setelah review bukti.

Peta implementasi Stage 4: `stages/stage-4-desktop-validation/README.md`.

Wrapper tahap 2 dan 3 mendelegasikan ke implementasi internal. Jangan menduplikasi logika atau menjalankan wrapper dan implementasinya secara berurutan untuk pekerjaan yang sama.

## Documentation ownership

| Topik | Dokumen pemilik |
|---|---|
| Ringkasan dan alur kanonis | `README.md` |
| Instruksi AI, safety, workflow perubahan | `AGENTS.md` |
| Navigasi dan sumber kebenaran | `docs/00-START-HERE.md` |
| Tujuan, tahapan, arsitektur | `docs/01-PROJECT.md` |
| Tahap 1–3: ringkasan prosedur instalasi | `docs/02-INSTALLATION.md` |
| Stage 1–4: peta implementasi | README masing-masing stage |
| Desktop tahap 3–5 dan handoff | `docs/03-DESKTOP.md` |
| Test suite dan acceptance gate | `docs/04-TESTING.md`, `tests/README.md` |
| Security, recovery, optimasi tahap 6 | `docs/05-OPERATIONS.md` |
| Status aktual dan prioritas | `docs/06-STATUS.md` |
| Design System | `docs/07-DESKTOP-DESIGN-SYSTEM.md` sebagai indeks |
| Eksekusi dan prosedur Stage 5 | `stages/stage-5-desktop-customization/docs/README.md` |
| Peta fisik implementasi Stage 5 | `stages/stage-5-desktop-customization/README.md` |
| Bottombar / K41Dock | `stages/stage-5-desktop-customization/docs/04-TASKBAR-PANEL.md` dan `04-TASKBAR-PANEL-IMPLEMENTATION.md` |
| Topbar | `stages/stage-5-desktop-customization/docs/05-TOPBAR.md` |

Jangan menduplikasi detail desain atau status implementasi ke banyak dokumen. Update dokumen pemilik dan hanya ringkasan/cross-reference yang terdampak.

## Current project decisions

- Stage 5 adalah tahap aktif. Workstream 1 — Boot Experience **COMPLETED / USER ACCEPTED pada 2026-11-10**.
- Workstream 2 — Lock Screen **COMPLETED / USER ACCEPTED pada 2026-11-10**.
- **Dashboard dihapus dari daftar workstream Stage 5 pada 2026-11-11.** Fitur runtime dinonaktifkan melalui `k41-cleanup-caelestia.sh`; jangan menghapus source QML upstream atau menambahkan dashboard kembali.
- **Workstream 04 — Bottombar / K41Dock COMPLETED / USER CONFIRMED SUCCESS.** Source kanonis berada di repository pada `workstreams/04-taskbar-panel/`; source runtime berada di bawah `~/.config/quickshell/caelestia/`. Lihat dokumen Bottombar.
- **Workstream 05 — Topbar** adalah pekerjaan Stage 5 berikutnya. Elemen, alignment, ukuran, dan visibility harus disepakati sebelum implementasi.
- Cleanup dashboard diimplementasikan melalui `stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`. Default dry-run; `--apply` mem-backup dan mengatur `dashboard.enabled=false` pada konfigurasi global serta override monitor yang relevan; `--rollback` memulihkan backup. Audit terbaru harus ditinjau sebelum apply. Script tidak menghapus source checkout upstream, keybind, package, atau service.
- Workstream 06 Launcher, 07 Sidebar, dan 08 Utilities mengikuti status di `docs/06-STATUS.md`.
- Guest Mode **NOT IMPLEMENTED** dan ditunda. Jangan membuat akun, service, mount, storage policy, atau workflow Guest tanpa keputusan eksplisit baru.
- Screenshot **tidak digunakan**: jangan meminta, mengambil, mewajibkan, atau menjadikannya acceptance gate/artefak proyek.
- Design System adalah spesifikasi lintas-komponen; status aktual implementasi tetap dimiliki `docs/06-STATUS.md` dan dokumen workstream.
- Stage 5 menjadi fondasi bertahap **k41-dots**; hindari asumsi perlu membangun shell mandiri penuh atau mengganti Caelestia.
- **Workstream 01 — Boot Experience dikecualikan dari scope k41-dots** karena boot/splash ditangani Plymouth. Jangan memasukkan komponen Quickshell boot splash lama sebagai backlog k41-dots tanpa keputusan baru.
- Source/runtime Quickshell pada laptop berada di bawah `~/.config/quickshell/`; repository menyimpan source kanonis dan installer untuk deployment.

## Required change process

Sebelum mengubah repository:
1. Periksa branch, HEAD, tree, dan file yang akan disentuh.
2. Baca dokumen pemilik, implementasi, dan test relevan.
3. Tetapkan tujuan, acceptance criteria, interface, dan batas safety.
4. Pertahankan pekerjaan yang tidak terkait; jangan menghapus file hanya karena tidak ditemukan referensi langsung.
5. Gunakan perubahan kecil dan fokus. Tanyakan hanya bila ambiguitas memengaruhi safety atau arsitektur.

Setelah perubahan:
1. Baca ulang semua file yang diubah untuk memverifikasi hasil.
2. Jalankan pemeriksaan aman yang relevan dan laporkan perintah serta hasil sebenarnya.
3. Periksa tautan, path, status, dan konsistensi lintas-dokumen.
4. Perbarui `docs/06-STATUS.md` bila status proyek berubah.
5. Laporkan file, commit, validasi, hal yang belum diuji, risiko, dan langkah berikutnya.

## Shared components and compatibility paths

- Canonical shared code/configuration: `shared/lib/` and `shared/config/`.
- Root `lib/` and `config/` are compatibility symlinks only; new references must use `shared/`.

## Reports and generated artifacts

- Output runtime dikelompokkan di `reports/<stage>/<category>/`; artefak lintas-stage berada di `reports/shared/<category>/`. Semua output runtime lokal secara default dan diabaikan Git.
- Snapshot laporan historis November 2026 disimpan dalam Git history pada commit `02f6194ed04c8f13ea64eda35b7afb94f7006504`; indeks aktif: `reports/archive/2026-11/README.md`.
- Jangan enumerate atau membaca seluruh arsip laporan untuk tugas rutin. Buka hanya laporan tertentu bila diperlukan oleh dokumen aktif.
- Laporan dapat memuat serial, username, path, journal, dan metadata jaringan. Redaksi sebelum dibagikan. Jangan pernah menyimpan password, passphrase LUKS, recovery key, token, cookie, atau credential.

## Status vocabulary

- **PLANNED** — belum diimplementasikan.
- **IMPLEMENTED** — kode/perubahan tersedia di repository.
- **TESTED** — test yang disebutkan benar-benar dijalankan.
- **VERIFIED** — perilaku dibuktikan dengan metode yang sesuai.
- **COMPLETED / USER ACCEPTED** — pengguna secara eksplisit menerima dan menutup workstream; tidak otomatis mengklaim setiap detail teknis telah diukur.
- **RELEASED** — masuk rilis yang ditetapkan.
- **NOT TESTED** — belum ada pengujian memadai.
- **BLOCKED** — prasyarat menghalangi pekerjaan.

Jangan menyamakan keberadaan file, exit code 0, syntax check, automated fixture, atau konfirmasi satu fungsi dengan verifikasi seluruh sistem.

## Safety and engineering

- Jangan melakukan operasi disk destruktif tanpa izin eksplisit dan identifikasi target yang terverifikasi.
- Storage operation harus fail-closed.
- Stage 1 readiness read-only; Stage 2 dapat menghapus SSD target.
- Stage 3 desktop setup dijalankan dari Arch terpasang, TTY, sebagai user biasa melalui sudo; bukan dari ISO, chroot, atau sesi grafis.
- First-boot diagnostics opsional, bukan gate wajib.
- Jangan menonaktifkan signature/integrity verification atau pipe script remote langsung ke shell.
- Build AUR sebagai user non-root setelah meninjau PKGBUILD.
- Jangan menjalankan privileged operation atau mengubah sistem nyata hanya untuk memvalidasi rancangan.
- VM tidak digunakan untuk validasi proyek.
- Gunakan Bash kecuali bahasa lain memiliki alasan teknis yang jelas. Quote ekspansi, validasi input, error handling, privilege minimal, dan ShellCheck.
- Verifikasi package/dependency/version terhadap dokumentasi upstream resmi.

## Scope and reporting

Kerjakan hanya permintaan yang diberikan. Jangan merge PR, membuat release/tag, atau melakukan tindakan consequential lain tanpa izin eksplisit. Jangan mengklaim test atau operasi berhasil jika tidak dilakukan.
