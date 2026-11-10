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
4. `scripts/k41-desktop-validation.sh` — validasi desktop read-only; jalankan sebagai user biasa dalam sesi Hyprland.
5. `scripts/k41-desktop-repair.sh` — remediasi terbatas berbasis bukti.

Wrapper tahap 2 dan 3 mendelegasikan ke implementasi internal. Jangan menduplikasi logika atau menjalankan wrapper dan implementasinya secara berurutan untuk pekerjaan yang sama.

## Documentation ownership

| Topik | Dokumen pemilik |
|---|---|
| Ringkasan dan alur kanonis | `README.md` |
| Instruksi AI, safety, workflow perubahan | `AGENTS.md` |
| Navigasi dan sumber kebenaran | `docs/00-START-HERE.md` |
| Tujuan, tahapan, arsitektur | `docs/01-PROJECT.md` |
| Tahap 1–3: ringkasan prosedur instalasi | `docs/02-INSTALLATION.md` |
| Stage 1: peta readiness dan ownership | `stages/stage-1-live-readiness/README.md` |
| Stage 2: peta installer dasar, storage safety, recovery, dan test | `stages/stage-2-basic-arch-install/README.md` |
| Stage 3: peta desktop installer, AUR resolver, side effects, dan test | `stages/stage-3-desktop-install/README.md` |
| Desktop tahap 3–5 dan handoff | `docs/03-DESKTOP.md` |
| Test suite dan acceptance gate | `docs/04-TESTING.md`, `tests/README.md` |
| Security, recovery, optimasi tahap 6 | `docs/05-OPERATIONS.md` |
| Status aktual dan prioritas | `docs/06-STATUS.md` |
| Design System | `docs/07-DESKTOP-DESIGN-SYSTEM.md` sebagai indeks; rincian berada di `docs/07-DESIGN-SYSTEM/` |
| Eksekusi Stage 5 | `docs/08-STAGE-5/README.md` dan dokumen workstream terkait |
| Workstream 1 | `docs/08-STAGE-5/01-BOOT-EXPERIENCE.md` |
| Workstream 2 dan gate Guest Mode | `docs/08-STAGE-5/02-LOCK-SCREEN.md`; spesifikasi Guest Mode di `03-GUEST-MODE.md` |

Jangan menduplikasi detail desain atau status implementasi ke banyak dokumen. Update dokumen pemilik dan hanya ringkasan/cross-reference yang terdampak.

## Current project decisions

- Stage 5 adalah tahap aktif. Workstream 1 — Boot Experience **COMPLETED / USER ACCEPTED pada 2026-11-10**. Jangan membuka kembali berdasarkan catatan historis yang lebih lama; evaluasi ulang hanya bila ada laporan masalah baru dari pengguna.
- Workstream 2 — Lock Screen adalah pekerjaan aktif. Status implementasi dan pengujian tercatat di `docs/06-STATUS.md`.
- Guest Mode **NOT IMPLEMENTED** dan ditunda. Jangan membuat akun, service, mount, storage policy, atau workflow Guest tanpa keputusan eksplisit baru.
- Screenshot **tidak digunakan**: jangan meminta, mengambil, mewajibkan, atau menjadikannya acceptance gate/artefak proyek. Review visual dilakukan langsung oleh pengguna pada display X280 dan hasilnya dicatat dalam teks.
- Design System adalah spesifikasi lintas-komponen; status aktual implementasi tetap dimiliki `docs/06-STATUS.md` dan dokumen workstream.
- Hasil Stage 5 akan menjadi input evaluasi tahap instalasi sebelum Stage 7. Refactoring instalasi menyeluruh belum menjadi pekerjaan aktif.

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

## Reports and generated artifacts

- Output runtime `reports/<category>/` lokal secara default dan diabaikan Git.
- Snapshot laporan historis November 2026 disimpan dalam Git history pada commit `02f6194ed04c8f13ea64eda35b7afb94f7006504`; indeks aktif: `reports/archive/2026-11/README.md`.
- Jangan enumerate atau membaca seluruh arsip laporan untuk tugas rutin. Buka hanya laporan tertentu bila diperlukan oleh dokumen pemilik.
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
