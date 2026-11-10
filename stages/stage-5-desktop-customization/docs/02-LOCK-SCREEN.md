# Workstream 02 — Lock Screen

**Status desain: COMPLETED / USER ACCEPTED.** Tampilan Lock Screen saat ini, dengan konsep Floating Password Card, sudah disetujui pengguna. Pekerjaan berikutnya bukan redesign: tujuannya mengaudit, mengambil, dan memisahkan source tampilan yang sudah disetujui, lalu memigrasikannya menjadi modul visual langsung di workstream Stage 5.

**Status audit visual: COMPLETED FOR SOURCE EXTRACTION. Status implementasi source K41: IMPLEMENTED. Status migrasi/runtime: PLANNED / NOT VERIFIED.** Source visual Floating Password Card sekarang berada langsung di `workstreams/02-lock-screen/modules/lockscreen/`. Folder `k41-dots/` tidak digunakan dan telah dihapus dari struktur project.

## Tujuan dan batas scope

- Pertahankan tampilan Lock Screen yang saat ini telah disetujui. Jangan mengubah desain, layout, warna, typography, animasi, atau perilaku visual tanpa persetujuan baru.
- Identifikasi dan ambil hanya source visual serta resource yang benar-benar diperlukan.
- Pisahkan ownership source K41 dari source upstream Caelestia.
- Pertahankan Caelestia sebagai host/runtime selama belum ada keputusan arsitektur baru.
- Jangan mengubah autentikasi, PAM, password handling, fingerprint/Howdy policy, atau session-lock protocol sebagai bagian dari pekerjaan visual.

Detail bahasa visual lintas-komponen: [Design System](../../../docs/07-DESKTOP-DESIGN-SYSTEM.md).

## Protokol kolaborasi

Pengguna menetapkan batas partisipasi: **pengguna tidak ingin melakukan pekerjaan teknis selain `git pull` dan `git push`.**

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Audit repository dan upstream; membuat serta memelihara script audit, ekstraksi/penyiapan, migrasi, implementasi, test, dan dokumentasi; memeriksa perubahan repository dan melaporkan bukti serta keterbatasannya. |
| Pengguna | Hanya melakukan `git pull` dan `git push` untuk sinkronisasi perubahan sesuai alur yang disepakati. Tidak diminta mengedit file, menulis kode, menjalankan perintah manual, atau mengubah konfigurasi secara manual. |

**Batasan eksekusi:** pull/push Git tidak menjalankan script dan tidak membuktikan perilaku runtime pada laptop. Karena pengguna membatasi aktivitasnya pada pull/push, rancangan alur otomatisasi harus memperhitungkan cara menjalankan dan mengumpulkan hasil pengujian tanpa membebankan langkah manual tambahan. Jangan mengklaim test lokal, deployment, atau runtime berhasil sebelum ada bukti nyata. Jika suatu validasi tidak dapat dilakukan dalam batasan ini, laporkan sebagai BLOCKED/NOT VERIFIED dan jelaskan alasan teknisnya; jangan diam-diam mengubah pembagian tanggung jawab.

## Urutan pengerjaan wajib

1. **Audit visual read-only — COMPLETED.** Audit source visual pada report 20261110T192941Z telah menyediakan source QML, dependency visual, aset, dan konfigurasi terpilih. Report mengandung satu file di luar scope; file itu tidak dipakai sebagai input implementasi. Screenshot/runtime capture belum tersedia.
2. **Audit dependency dan batas ownership — PARTIAL.** Dependency statis yang tampak pada QML dicatat di `workstreams/02-lock-screen/modules/lockscreen/README.md`. Kelengkapan dependency runtime masih menunggu pemeriksaan setelah modul dipasang.
3. **Ekstraksi source terpilih — IMPLEMENTED.** Empat file QML visual tersedia langsung di `workstreams/02-lock-screen/modules/lockscreen/`.
4. **Struktur modul visual Stage 5 — IMPLEMENTED.** Struktur dan kontrak komponen didokumentasikan di `workstreams/02-lock-screen/modules/lockscreen/README.md`; integrasi runtime, backup, validasi deployment, dan rollback belum diimplementasikan.
5. **Migrasi dan implementasi runtime — PLANNED.** Berikutnya buat script migrasi terpisah dengan preflight, validasi input/path, backup, staging, verifikasi pascaperubahan, dan rollback. Jangan gunakan installer lama.
6. **Testing dan validasi.** Jalankan pemeriksaan statis dan test otomatis yang dapat dilakukan di repository/CI. Runtime, lock/unlock, password salah, wake/resume, dan perilaku perangkat hanya boleh dinyatakan VERIFIED bila benar-benar diuji dengan bukti.
7. **Audit pascamigrasi.** Pastikan modul K41 tidak lagi bergantung pada source visual Caelestia yang akan dibersihkan, sementara dependency upstream yang masih diperlukan tetap tersedia dan tercatat.
8. **Cleanup source visual upstream.** Hanya setelah migrasi terbukti berfungsi dan pengguna menerima hasilnya, identifikasi serta hapus source visual upstream yang sudah tidak digunakan. Cleanup harus sempit, berdasarkan dependency graph, dan memiliki rencana rollback. Jangan menghapus komponen autentikasi atau dependency bersama.
9. **Penerimaan.** Hasil akhir harus mempertahankan desain yang disetujui dan memenuhi acceptance di bawah.

Setiap tahap menghasilkan artefak dan bukti yang dapat ditinjau sebelum tahap berikutnya. Jangan melewati audit atau menggabungkan audit read-only dengan operasi tulis.

## Struktur runtime tujuan

```text
~/.config/quickshell/
├── caelestia/                    # host/runtime dan dependency upstream
└── k41/
    └── modules/
        └── lockscreen/
            ├── ...
            └── assets/
```

Source visual berada langsung di workstream `workstreams/02-lock-screen/modules/lockscreen/`; tidak ada subproject atau namespace `K41-dots`.

## Kondisi repository saat ini

Implementasi terdahulu masih berada di:
- Source sebelumnya: `workstreams/02-lock-screen/k41-dots/modules/lock/` (sudah dihapus setelah pemindahan source visual ke folder Stage 5).
- Installer lama: `workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh`
- Target lama: `~/.config/quickshell/caelestia/modules/lock/`

Path dan installer tersebut adalah kondisi lama/transisi. **Jangan menjalankan installer lama sebagai migrasi ke struktur baru.** Source lama harus diaudit dan dibandingkan dengan upstream aktif sebelum diputuskan untuk dipertahankan, diekstrak, atau diganti.

## Script audit visual baru

Script khusus audit visual telah ditambahkan:

`workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh`

Jalankan dari checkout repository pada ThinkPad X280 sebagai user desktop biasa (tanpa sudo):

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh
```

Script menghasilkan direktori laporan bertimestamp di `reports/lockscreen-visual-audit/`. Laporan mencakup metadata host/session, versi dan provenance package/source Caelestia, inventory serta SHA-256 file terkait, source QML/JS lock yang ditemukan, teks source visual legacy/upstream terpilih, aset visual, referensi/import/resource, resolusi dependency QML lokal secara rekursif, field konfigurasi lock/wallpaper terpilih, user systemd units, identitas executable proses tanpa command-line/environment, serta metadata integrasi Hyprland/PAM tanpa mengambil isi lengkap file PAM. Filter keybind Hyprland menghindari properti generik `locked` agar tidak salah mengumpulkan seluruh keybind.

Audit tidak melakukan deployment, cleanup, perubahan konfigurasi, instalasi package, restart service, atau perubahan autentikasi. Binary asset dicatat melalui path/ukuran/hash, bukan disalin ke log. Report dapat memuat source custom dan metadata host; periksa/redaksi sebelum dipublikasikan. `.gitignore` saat ini tidak mengecualikan `reports/`; laporan baru dapat ikut di-commit/push bila di-stage. Jangan publikasikan sebelum review privasi dan kepemilikan source.

Script mengandalkan path umum Caelestia. Jika instalasi menggunakan source root nonstandar, hasil audit akan menunjukkan root yang tidak ditemukan; jangan menganggap inventory lengkap sampai path aktual diketahui.

## Artefak audit terdahulu

Script berikut sudah ada di repository dan perlu diperiksa sebelum digunakan atau diganti:
- `workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh`

Keberadaan script tidak membuktikan audit terbaru sudah dilakukan. Audit baru harus memverifikasi source/revision Caelestia yang benar-benar digunakan dan berfokus pada tampilan serta dependency terkait. Audit bersifat read-only dan harus menghasilkan laporan yang dapat ditinjau.

## Acceptance criteria

- Tampilan hasil migrasi tetap sesuai desain Lock Screen yang telah disetujui; tidak ada perubahan visual tanpa persetujuan.
- Source visual K41 berada pada namespace K41, terpisah dari direktori internal Caelestia.
- Seluruh file, aset, dependency, konfigurasi, dan titik integrasi yang diperlukan telah diidentifikasi.
- Tidak ada dependency tersembunyi pada source visual upstream yang dihapus.
- PAM, autentikasi, password handling, fingerprint/Howdy policy, dan session-lock protocol tidak diubah oleh migrasi visual.
- Script audit read-only; script migrasi/implementasi terpisah, aman, dapat diulang, dan menyediakan backup/recovery.
- Pemeriksaan statis/otomatis lulus sesuai cakupan yang dilaporkan.
- Runtime dan perilaku pada ThinkPad X280 hanya dinyatakan VERIFIED setelah ada bukti pengujian aktual.
- Pengguna menerima hasil akhir.

Screenshot bukan acceptance gate.

## Status Guest Mode

Guest Mode (ID 03) **NOT IMPLEMENTED / DEFERRED** dan bukan bagian dari scope atau acceptance Lock Screen.
