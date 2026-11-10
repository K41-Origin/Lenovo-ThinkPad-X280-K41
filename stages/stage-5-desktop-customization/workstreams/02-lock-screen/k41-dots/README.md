# K41-dots — Lock Screen Source

Dokumen ini menjelaskan status source Lock Screen lama dan arah migrasinya. **Tampilan saat ini sudah disetujui pengguna dan harus dipertahankan.** Pekerjaan yang direncanakan adalah audit, ekstraksi source visual, dan migrasi ownership ke modul K41-dots, bukan redesign.

## Struktur runtime tujuan

```text
~/.config/quickshell/k41/modules/lockscreen/
```

Caelestia tetap menjadi host/runtime. Dependency upstream yang diperlukan akan tetap digunakan; source visual yang telah dipisahkan menjadi milik K41-dots.

## Source legacy yang tersedia

Source visual lama berada di:

```text
k41-dots/modules/lock/
├── LockSurface.qml
├── Content.qml
├── Center.qml
└── center/PasswordInput.qml
```

Installer terdahulu menyalin overlay ke `~/.config/quickshell/caelestia/modules/lock/`. Ini bukan struktur runtime K41-dots yang dituju.

Source ini belum boleh dianggap sebagai paket lengkap atau langsung dipindahkan. Audit harus membandingkannya dengan versi/revision Caelestia yang benar-benar digunakan, termasuk komponen QML, resource, konfigurasi, API, dan dependency.

## Rencana audit dan migrasi

1. Audit read-only semua source yang memengaruhi tampilan Lock Screen yang disetujui.
2. Petakan file visual, aset, styling, animasi, konfigurasi, dependency, dan titik integrasi.
3. Pisahkan source visual milik K41 dari dependency upstream yang tetap diperlukan.
4. Ekstrak hanya file/resource yang terbukti dibutuhkan.
5. Rancang struktur dan interface modul `lockscreen`.
6. Implementasikan script migrasi/penyiapan terpisah dari script audit.
7. Test, validasi, dan tinjau hasil sebelum cleanup upstream.
8. Hapus source visual upstream yang sudah tidak diperlukan hanya setelah migrasi berfungsi dan diterima pengguna.

Rincian tahapan dan acceptance kanonis: [Workstream 02 — Lock Screen](../../../../docs/02-LOCK-SCREEN.md).

## Script audit visual

Script audit read-only:
`../scripts/k41-audit-lockscreen-visual.sh` (relative to workstream root: `workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh`).

Jalankan dari root checkout pada X280 sebagai user biasa:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh
```

Laporan bertimestamp dibuat di `reports/lockscreen-visual-audit/`. Cakupannya meliputi penemuan source Caelestia, source QML terkait lock, legacy K41 overlay, aset, hash file, import/referensi, konfigurasi visual terpilih, dan metadata integrasi autentikasi/session-lock. Isi PAM/password dan nilai environment sensitif tidak dikumpulkan. Source text yang relevan dimasukkan ke report agar dependency dapat dianalisis sebelum implementasi.

Script tidak mengubah sistem maupun Git state. Folder report di-ignore secara default; publikasi hasil memerlukan alur review/transfer yang disepakati. Report harus diperiksa karena dapat memuat source custom dan metadata mesin.

## Batas keamanan

- Jangan mengubah tampilan yang telah disetujui tanpa persetujuan baru.
- Jangan mengubah PAM, autentikasi, password handling, fingerprint/Howdy policy, atau session-lock protocol untuk pekerjaan visual.
- Jangan menyalin seluruh source Caelestia.
- Jangan menghapus dependency upstream yang masih dipakai.
- Audit harus read-only; ekstraksi, deployment, dan cleanup merupakan operasi terpisah.
- Jangan menjalankan installer lama sebagai mekanisme migrasi baru.

## Protokol kontribusi pengguna

Pengguna hanya melakukan `git pull` dan `git push`. Assistant bertanggung jawab atas audit, pembuatan script, implementasi, test otomatis, dan dokumentasi. Setiap langkah yang membutuhkan eksekusi lokal atau verifikasi perangkat harus memiliki solusi otomatisasi yang dirancang terlebih dahulu. Pull/push saja tidak menjalankan script; jika validasi runtime tidak dapat dilakukan tanpa tindakan tambahan, statusnya harus dilaporkan secara jujur sebagai belum diverifikasi.
