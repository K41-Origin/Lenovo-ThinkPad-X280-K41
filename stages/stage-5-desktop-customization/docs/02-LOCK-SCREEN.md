# Workstream 02 — Lock Screen

**Status: COMPLETED / USER ACCEPTED (12 November 2026).** Pengguna telah menyetujui penyelesaian Workstream 02. Scope mencakup audit visual dan startup, pemisahan source visual K41, helper startup/lock readiness, deployment visual dengan backup dan logging, cleanup hook legacy, serta cleanup komponen visual Caelestia yang tidak lagi digunakan.

Status COMPLETED / USER ACCEPTED adalah keputusan penutupan workstream, bukan klaim bahwa seluruh perilaku runtime telah diuji ulang atau bahwa setiap skenario lock/unlock sudah VERIFIED. Bukti historis startup masih menunjukkan beberapa event tidak teramati dan fallback Hyprlock aktif. QML rendering, lock/unlock end-to-end, suspend/resume, dan autentikasi pada X280 tidak boleh disebut VERIFIED tanpa bukti pengujian perangkat yang sesuai.

## Tujuan dan batas ownership

- Menjaga tampilan Lock Screen K41 yang disetujui dan memindahkan ownership source visual ke repository K41.
- Tetap menggunakan Caelestia/Quickshell sebagai host/runtime dan mempertahankan lock IPC serta protokol Wayland session-lock.
- Menghapus hanya komponen visual upstream yang tidak lagi digunakan oleh komposisi K41.
- Memisahkan visual customization dari PAM, password handling, fingerprint/Howdy policy, autentikasi, dan session-lock security.
- Seluruh perubahan runtime harus memiliki preflight, backup, verifikasi, dan batas target yang jelas.

## Ringkasan alur kerja

### 1. Audit dan pengumpulan bukti

Audit dilakukan bertahap dan bersifat read-only:

- `k41-audit-lockscreen-visual.sh` menginventarisasi source Caelestia dari user/system XDG roots, provenance/revision, empat target visual, hash, diff terhadap upstream dan source K41, QML entry points, dependency lokal, aset, token, konfigurasi visual, serta versi package.
- `k41-audit-desktop-startup.sh` mengumpulkan kondisi session/Hyprland, proses dan IPC Quickshell/Caelestia, helper lock, log startup, konfigurasi aktif, fallback Hyprlock, serta lifecycle timeline.
- Laporan audit startup disimpan privat secara lokal di `~/.local/state/k41/lockscreen/startup-audits/`. Script menerbitkan salinan yang telah disanitasi ke `reports/stage-5-desktop-customization/02-lock-screen/startup-audits/<timestamp>/` pada branch `main`.
- Publisher menggunakan temporary independent Git clone. Operasi fetch/commit/push tidak mengubah branch, HEAD, index, FETCH_HEAD, atau metadata worktree checkout pengguna.
- Audit visual menghasilkan laporan lokal di `reports/lockscreen-visual-audit/<timestamp>/`; script visual audit sendiri tidak melakukan push otomatis. Laporan tersebut perlu ditinjau dan dipublikasikan melalui alur Git yang disepakati.

Audit bukan operasi deployment dan tidak mengubah package, konfigurasi, service, autentikasi, atau source runtime. Laporan dapat berisi source code dan metadata host; review privasi tetap wajib sebelum publikasi.

### 2. Implementasi startup dan lock helper

Ownership helper dipusatkan di `workstreams/02-lock-screen/scripts/`:

- `k41-lock-caelestia-after-start.sh` menunggu kesiapan IPC Caelestia dengan deadline terbatas, mengirim satu lock request, memverifikasi status lock secara bounded, dan mencoba Hyprlock fallback jika jalur Caelestia tidak terverifikasi.
- `k41-update-lockscreen-startup-helper.sh` memasang helper dan konfigurasi fallback dengan backup serta memeriksa urutan startup Caelestia sebelum helper pada konfigurasi Hyprland Lua yang aktif.
- `k41-audit-desktop-startup.sh` mengumpulkan bukti setelah perubahan tanpa mengubah sistem.
- Regression tests untuk bounded timeout, keberhasilan Caelestia, fallback, fail-closed, backup, konfigurasi ambigu, dan idempotensi tersedia dalam test suite Workstream 02.

Audit menemukan bahwa konfigurasi aktif Hyprland adalah `~/.config/hypr/hyprland.lua`; directive startup pada `hyprland.conf` saja tidak menjamin Caelestia dimulai. Helper lama memiliki nested retry yang berpotensi melampaui timeout handoff. Implementasi baru membatasi total readiness wait dan jumlah verifikasi.

### 3. Source visual K41

Source visual kanonis disimpan di:

`workstreams/02-lock-screen/modules/lockscreen/`

Empat file overlay yang dikelola deployment:

- `LockSurface.qml`
- `Content.qml`
- `Center.qml`
- `center/PasswordInput.qml`

Source K41 menggantikan empat file visual terpilih di user runtime:

`~/.config/quickshell/caelestia/modules/lock/`

Caelestia tetap menyediakan host/runtime, lock object, PAM object, dan session-lock integration. Source visual K41 tidak mengambil alih autentikasi atau protokol lock.

### 4. Deployment, backup, log, dan automated push

Entry point:

`workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh`

Urutan operasi:

1. Memastikan script dijalankan oleh user desktop biasa pada sesi Hyprland/Wayland aktif.
2. Memverifikasi repository Caelestia user, upstream origin, dan revision yang dipin.
3. Memastikan target file adalah regular file yang dikenal: pristine upstream, K41 current, atau hash legacy yang secara eksplisit diizinkan.
4. Memeriksa dependency runtime Caelestia, termasuk `Lock.qml`, `Pam.qml`, `center/InputField.qml`, `center/Clock.qml`, dan `center/StateMessage.qml`.
5. Membuat backup empat file target dan checksum manifest.
6. Menyiapkan file di staging directory, memverifikasi checksum, lalu mengganti target.
7. Memverifikasi hasil penyalinan dan menjalankan `caelestia shell -r -d`.
8. Jika deployment atau reload gagal, mencoba memulihkan empat file dari backup.
9. Menyimpan log lokal privat di `~/.local/state/k41/lockscreen/deployment-logs/`.
10. Menerbitkan log tersanitasi ke `reports/lockscreen-deployment/` melalui temporary independent clone dan push non-force ke `main`.

Kegagalan publikasi log dilaporkan sebagai warning dan tidak mengubah hasil deployment. Log lokal tetap tersedia. Publisher tidak menggunakan metadata Git checkout utama untuk fetch/worktree. Preflight deployment tidak mengubah `Lock.qml`, `Pam.qml`, `shell.qml`, PAM, keybind, Hyprland config, atau system services.

Perintah dari root checkout, pada sesi Hyprland aktif:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh
```

### 5. Cleanup hook startup legacy

Script:

`workstreams/02-lock-screen/scripts/k41-cleanup-caelestia-lock-hooks.sh`

Script ini membersihkan hanya directive legacy boot-splash dalam bounded K41 block pada `~/.config/hypr/hyprland.lua`. Default `--dry-run`; `--apply` membuat backup privat dan memverifikasi bahwa startup Caelestia serta pemanggilan K41 lock helper tetap ada. Script tidak menghapus startup Caelestia atau dukungan lock IPC.

### 6. Audit dependency dan cleanup visual Caelestia

Setelah komposisi K41 diperiksa, ditemukan sembilan komponen visual upstream yang tidak lagi diinstansiasi oleh K41 `Content.qml` dan `Center.qml`:

- `Fetch.qml`
- `Media.qml`
- `Resources.qml`
- `NotifDock.qml`
- `NotifGroup.qml`
- `WeatherInfo.qml`
- `weather/BriefInfo.qml`
- `weather/Forecast.qml`
- `center/ProfilePic.qml`

Script cleanup:

`workstreams/02-lock-screen/scripts/k41-cleanup-caelestia-lock-visuals.sh`

Perilaku dan guard:

- Default `--dry-run`; penghapusan memerlukan `--apply`.
- Hanya menargetkan user-local checkout `~/.config/quickshell/caelestia/modules/lock/`.
- Memastikan upstream origin dan revision sama dengan hasil audit.
- Menolak kandidat yang tidak tracked, hilang, symlink, kosong, atau memiliki perubahan lokal.
- Membandingkan setiap file dengan blob pada pinned upstream revision.
- Memeriksa referensi langsung komponen pada QML/JS lock module yang tersisa.
- Membuat backup eksternal di `~/.local/state/k41/lockscreen/caelestia-visual-cleanup/` dan manifest SHA-256 sebelum menghapus.
- Memverifikasi file target benar-benar tidak ada setelah penghapusan dan mencoba rollback jika proses gagal.

File yang dipertahankan meliputi `Lock.qml`, `Pam.qml`, `LockSurface.qml`, `Content.qml`, `Center.qml`, `center/PasswordInput.qml`, `center/InputField.qml`, `center/Clock.qml`, dan `center/StateMessage.qml`.

**Konsekuensi update:** penghapusan sembilan file upstream menghasilkan tracked deletions pada checkout Caelestia. Jangan menjalankan `git pull` atau update checkout tersebut tanpa memulihkan file atau menggunakan prosedur update yang secara eksplisit menangani deletions. System XDG tree tidak disentuh. Static reference scan bukan linker QML lengkap; dynamic Loader URL, plugin, singleton, dan referensi eksternal masih merupakan batasan audit.

## Daftar script utama

| Script | Peran |
|---|---|
| `k41-audit-lockscreen-visual.sh` | Audit read-only source visual, dependency, provenance, hash dan diff |
| `k41-audit-desktop-startup.sh` | Audit startup/session/runtime; publikasi report tersanitasi otomatis |
| `k41-lock-caelestia-after-start.sh` | Lock readiness, lock request, bounded verification, fallback |
| `k41-update-lockscreen-startup-helper.sh` | Update helper dan fallback dengan backup |
| `k41-deploy-lockscreen-visual.sh` | Deploy empat file QML K41, reload, backup, logging dan automated log push |
| `k41-cleanup-caelestia-lock-hooks.sh` | Hapus directive startup/boot-splash legacy yang dibatasi marker |
| `k41-cleanup-caelestia-lock-visuals.sh` | Hapus sembilan komponen visual upstream yang tidak digunakan |

## Batas keamanan

Tidak ada script cleanup visual yang boleh menghapus atau memodifikasi PAM, password handling, fingerprint/Howdy, `Lock.qml`, lock IPC, Wayland session-lock protocol, atau system XDG modules. Tidak ada operasi destruktif disk atau perubahan package/service dalam scope ini.

## Validasi dan bukti

- Source, script, dan dokumen berada di repository; perubahan GitHub diverifikasi dengan fetch ulang.
- CI historis pada commit `5c55fd2` dilaporkan lulus 39/39 test scripts beserta Bash syntax, embedded Python syntax, ShellCheck, dan formatting checks untuk perubahan startup saat itu.
- Perbaikan dependency preflight deployment menambahkan `center/Clock.qml` dan `center/StateMessage.qml`.
- Script cleanup visual telah ditambahkan dan diperiksa ulang dari GitHub. Pemeriksaan runtime/dry-run pada perangkat dan Bash/ShellCheck test khusus versi final script cleanup tidak diklaim telah dijalankan dalam sesi dokumentasi ini.
- Report startup `20261112T041236Z` tidak mengamati kesiapan Caelestia IPC atau lock request, sedangkan Hyprlock fallback dan autentikasi Hyprlock teramati. Itu adalah snapshot historis dan bukan pengukuran ulang kondisi perangkat saat ini.

## Acceptance dan penutupan

Pengguna secara eksplisit menerima Workstream 02 sebagai selesai pada 12 November 2026. Karena itu status workstream adalah **COMPLETED / USER ACCEPTED**. Penutupan ini menerima implementasi dan dokumentasi dalam scope yang disepakati; tidak mengubah status bukti runtime yang belum tersedia menjadi VERIFIED.
