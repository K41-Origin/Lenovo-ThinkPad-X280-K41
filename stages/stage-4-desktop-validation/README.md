# Stage 4 — Desktop Functional Validation

Dokumen ini memetakan implementasi Stage 4 pada branch `main`: entry point, alur pemanggilan, file pendukung, efek samping, bukti, test, dan batas acceptance. Implementasi tetap menjadi sumber kebenaran untuk perilaku aktual.

## Tujuan dan batas tahap

Stage 4 memeriksa kondisi software dan runtime desktop setelah Stage 3 selesai dan sesi Hyprland aktif. Fokusnya adalah mendeteksi masalah konfigurasi, proses, package, IPC, service, audio graph, jaringan/radio, perangkat, resource, thermal, serta journal.

Stage 4 memiliki dua jalur yang berbeda:

1. **Validation — read-only terhadap konfigurasi sistem:** mengumpulkan snapshot dan membuat laporan privat. Tidak memasang paket, mengubah service, menulis konfigurasi desktop, atau mengubah firmware/kernel.
2. **Repair — remediasi terbatas dan mutatif:** berdasarkan temuan, dapat memasang sejumlah paket yang spesifik, mengaktifkan service Bluetooth, membuka pairing/discoverability sementara, dan menginisialisasi scheme Caelestia. Repair bukan bagian otomatis dari validator; jalankan terpisah setelah meninjau bukti.

Stage 4 bukan:
- installer desktop (Stage 3);
- penerimaan visual atau interaksi penuh perangkat;
- customization shell (Stage 5);
- optimasi CPU/GPU, thermal/fan, baterai, power policy, atau suspend/resume (Stage 6).

## Entry point

Jalankan validator dari terminal di sesi Hyprland aktif, sebagai user biasa:

```bash
bash stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh
```

Jangan gunakan `sudo`. Script mensyaratkan `HYPRLAND_INSTANCE_SIGNATURE` dan `WAYLAND_DISPLAY`, serta menolak berjalan sebagai root.

### Kontrak package dan pilihan Stage 3

Validator saat ini memiliki daftar package wajib yang mencakup `hyprland`, `quickshell-git`, `caelestia-shell`, `caelestia-cli`, PipeWire/WirePlumber, dan portal Hyprland. Stage 3 menawarkan opsi Quickshell resmi tanpa Caelestia; opsi tersebut tidak memenuhi daftar wajib validator dan akan menghasilkan FAIL pada pemeriksaan package. Untuk workflow yang sesuai dengan kontrak Stage 4 sekarang, Caelestia harus dipilih saat instalasi Stage 3. Jalur Quickshell-only belum didukung end-to-end oleh validator; lihat [Status proyek](../../docs/06-STATUS.md).

Repair, bila memang diperlukan dan setelah laporan ditinjau, juga dijalankan sebagai user biasa di sesi Hyprland:

```bash
bash stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh
```

Repair meminta autentikasi sudo saat membutuhkan privilege. Tidak ada opsi `--apply`, `--no-validate`, atau mode simulasi; pemanggilan tanpa argumen adalah workflow repair yang benar-benar dapat mengubah sistem. Jangan menjalankannya hanya untuk menghasilkan laporan.

## Peta file dan ownership

| Path saat ini | Peran | Ownership / catatan |
|---|---|---|
| `stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` | Orkestrator validasi otomatis, klasifikasi hasil, dan ringkasan | Implementasi utama Stage 4 |
| `stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh` | Remediasi terbatas, pemeriksaan integritas PAM, validasi pasca-repair, dan ringkasan tindakan | Implementasi repair Stage 4; mutatif |
| `stages/stage-4-desktop-validation/scripts/test-desktop-x280.sh` | Collector read-only untuk paket, executable, Hyprland, perangkat, audio, jaringan, power, thermal, dan journal | Collector Stage 4 |
| `stages/stage-4-desktop-validation/scripts/test-caelestia-x280.sh` | Collector proses, CLI/IPC, log, dan package Caelestia/Quickshell | Collector Stage 4; jika dipanggil sendiri, dapat mencoba memulai Caelestia bila belum berjalan |
| `stages/stage-4-desktop-validation/lib/k41-log-classifiers.sh` | Klasifikasi log Caelestia dan journal | Library khusus Stage 4; di-source validator dan test Stage 4 |
| `stages/stage-4-desktop-validation/tests/test-desktop-validation.sh` | Syntax, read-only contract, report permissions/order, serta fixture classifier | Test milik Stage 4 |
| `stages/stage-4-desktop-validation/tests/test-desktop-repair.sh` | Syntax, batas mutasi, dan kontrak repair | Test milik Stage 4; canonical di `stages/stage-4-desktop-validation/tests/` |
| `stages/stage-3-desktop-install/tests/test-desktop-setup.sh` | Memeriksa keberadaan dan syntax validator sebagai kontrak integrasi Stage 3 | Test milik Stage 3; canonical di `stages/stage-3-desktop-install/tests/` |
| `tests/run.sh` | Manifest test repository | Shared; jangan dipindah |
| (workflow lama, sudah dikonsolidasikan) | Bash syntax, ShellCheck pada daftar script terpilih, dan suite test | CI repository; bukan milik eksklusif Stage 4 |
| `.github/workflows/bash-tests.yml` | Bash syntax dan ShellCheck seluruh file shell, shfmt terpilih, dan suite test | CI repository; bukan milik eksklusif Stage 4 |

**Struktur kanonis:** implementasi Stage 4 telah ditempatkan di `stages/stage-4-desktop-validation/scripts/` dan library khususnya di `stages/stage-4-desktop-validation/lib/`. Test khusus Stage 4 berada di `stages/stage-4-desktop-validation/tests/`; CI dan test runner tetap di lokasi bersama. Reorganisasi ini hanya mengubah lokasi dan referensi path, bukan perilaku runtime.

## Alur validator

```text
stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh
  ├── guard: non-root + sesi Hyprland/Wayland aktif
  ├── source stages/stage-4-desktop-validation/lib/k41-log-classifiers.sh
  ├── buat reports/stage-4-desktop-validation/desktop-validation/<UTC timestamp>/
  ├── cek platform, package, Hyprland, Quickshell, Caelestia
  ├── cek service, portal, audio, network, radio, GPU/backlight
  ├── snapshot memory, filesystem, battery, thermal
  ├── jalankan stages/stage-4-desktop-validation/scripts/test-desktop-x280.sh
  ├── jalankan stages/stage-4-desktop-validation/scripts/test-caelestia-x280.sh hanya jika proses Caelestia sudah terdeteksi
  ├── kumpulkan journal user/system/kernel
  ├── kumpulkan diagnostics terarah: CPU, PCI/USB, firmware, Bluetooth, PAM, service
  ├── klasifikasikan Caelestia log dan journal
  └── tulis checks.tsv + summary.md + log/diagnostic captures
```

Validator membuat direktori laporan privat mode 0700 dan file laporan mode 0600 (umask 077). Direktori sementara dihapus melalui trap. Tidak ada perubahan konfigurasi sistem yang dimaksudkan; penulisan dibatasi pada laporan di repository.

### Cakupan pemeriksaan otomatis

- Platform: marker Arch Linux, arsitektur x86_64, session Wayland, executable Hyprland/Quickshell/Caelestia.
- Package: paket desktop wajib dan paket utilitas opsional.
- Hyprland: `configerrors`, monitor, input device, process.
- Caelestia/Quickshell: process, IPC target discovery, runtime log; classifier membedakan error nyata dari beberapa warning yang diketahui kondisional.
- Services: PipeWire, WirePlumber, portal, NetworkManager, failed system/user units.
- Audio/network/radio: `wpctl`, `pactl`, `nmcli`, `rfkill`.
- Hardware/resource snapshot: Intel i915 binding, backlight, memory, filesystem usage, battery charge/health estimate, thermal zones.
- Diagnostic evidence: kernel command line, CPU topology/vulnerability/SMT/microcode, PCI/USB, modules, firmware/package ownership, Bluetooth controller/BlueZ/HCI, thermal hwmon, ThinkPad ACPI, PAM metadata/integrity, relevant package versions, dan journal.

Hasil adalah snapshot pada saat perintah berjalan. Status service yang tidak aktif dapat bersifat kondisional (misalnya socket/D-Bus activation); WARN harus dibaca bersama detail log, bukan dianggap otomatis sebagai kerusakan.

## Interpretasi hasil

Validator menulis `checks.tsv` dengan status per pemeriksaan: `PASS`, `WARN`, `FAIL`, atau `SKIP`.

- `PASS`: kondisi otomatis yang diperiksa memenuhi aturan script pada snapshot tersebut.
- `WARN`: ada temuan yang perlu ditinjau, bukti tidak lengkap, atau kondisi mungkin disengaja.
- `FAIL`: pemeriksaan wajib gagal atau mendeteksi kondisi kritis sesuai aturan script.
- `SKIP`: pemeriksaan tidak dijalankan atau bukti tidak tersedia; bukan PASS.

Hasil keseluruhan:
- `PASS` jika tidak ada WARN/FAIL.
- `PASS_WITH_WARNINGS` jika ada WARN dan tidak ada FAIL.
- `FAIL` jika ada FAIL; exit status non-zero.

Exit 0 dapat berarti `PASS_WITH_WARNINGS`, bukan bukti semua fungsi desktop sempurna. Periksa `summary.md`, `checks.tsv`, dan bagian relevan di log sebelum menentukan tindakan.

## Repair: batas dan efek samping

Repair bukan validator read-only. Source saat ini membatasi tindakan, antara lain:

- Membuat scheme Caelestia melalui `caelestia scheme set -n caelestia` hanya bila file scheme belum tersedia; tidak membuat file sintetis.
- Jika controller `hci0` terdeteksi, memeriksa BlueZ dan dapat memasang `bluez` serta `bluez-utils` yang belum ada.
- Dapat memasang `wireless-regdb` bila regulatory database tidak tersedia, serta `rtkit` bila PipeWire terpasang dan RTKit belum ada.
- Mengaktifkan dan memulai `bluetooth.service` bila controller dan paket BlueZ tersedia.
- Mengatur BlueZ `Pairable` dan `Discoverable` menjadi true dengan timeout 180 detik; ini adalah jendela sementara, bukan konfigurasi always-discoverable permanen.
- Mengumpulkan versi, ownership, dan integritas `pambase` serta `/etc/pam.d/other`; kebijakan PAM tidak ditulis ulang.
- Menjalankan validator lagi dan mengklasifikasikan bukti dari laporan post-repair yang persis dihasilkan oleh run tersebut.

Repair tidak mengubah PAM policy, kernel parameters, SMT policy, desktop configuration, firmware controller, atau gambar profil opsional. Tidak melakukan full system upgrade (`pacman -Syu`), menghapus paket, menonaktifkan service, atau melakukan operasi disk.

**Risiko operasional:** pemasangan paket memakai `pacman -S --needed --noconfirm` melalui sudo; service Bluetooth dapat di-enable/start; adapter Bluetooth sementara dapat terlihat dan menerima pairing selama jendela 180 detik. Tinjau kondisi jaringan dan pairing sebelum menjalankan. Repair tidak menawarkan konfirmasi per tindakan.

Jika repair gagal di tengah jalan, jangan menganggap rollback terjadi. Periksa `actions.tsv`, `repair.log`, dan bukti post-repair. Jangan mengubah PAM, kernel, SMT, firmware, atau konfigurasi lain secara manual hanya untuk menghilangkan WARN tanpa diagnosis.

## Laporan dan privasi

Validator membuat:

`reports/stage-4-desktop-validation/desktop-validation/<UTC timestamp>/`

Artefak utama:
- `summary.md` — hasil agregat dan interpretasi.
- `checks.tsv` — hasil mesin per pemeriksaan.
- `validation.log` — command/output dan detail orkestrasi.
- `diagnostics.tsv`, `diagnostics.log`, serta file `*.txt` — bukti hardware, package, service, CPU, Bluetooth, PAM, dan journal.
- `environment.txt` — metadata host/session.
- `desktop/` dan `caelestia/` — output collector pendukung.
- `*-journal*.txt` — journal yang mungkin terbatas oleh permission.

Repair membuat:

`reports/stage-4-desktop-validation/desktop-repair/<UTC timestamp>/`

Artefak utama:
- `repair.log`, `actions.tsv`, `summary.md`;
- `post-repair-state.txt`, bukti integritas/ownership PAM dan regulatory database;
- `validation-output.log`, `validation-result.txt`, dan laporan validator post-repair.

Laporan dapat berisi username, hostname, device identity, package versions, filesystem paths, PCI/USB inventory, Bluetooth metadata, service state, dan pesan journal. Jangan commit atau membagikan laporan mentah tanpa review/redaksi. Output runtime baru lokal secara default.

## Test dan CI

Test utama Stage 4:
- `bash stages/stage-4-desktop-validation/tests/test-desktop-validation.sh` — syntax, read-only contract, report initialization/permissions, coverage token, classifier fixtures Caelestia dan journal (termasuk empty/access-limited journal, firmware warning, critical kernel signature, CPU mitigation correlation).
- `bash stages/stage-4-desktop-validation/tests/test-desktop-repair.sh` — syntax, larangan opsi/operasi berbahaya, batas package/service/PAM, laporan privat, dan penilaian hasil validator post-repair.
- `bash tests/run.sh` — suite repository penuh; manifest dimiliki `tests/run.sh`.

Integrasi tambahan:
- `stages/stage-3-desktop-install/tests/test-desktop-setup.sh` memeriksa validator Stage 4 sebagai bagian dari kontrak desktop setup Stage 3.
- (workflow lama, sudah dikonsolidasikan) menjalankan syntax, ShellCheck pada daftar terpilih, dan suite.
- `.github/workflows/bash-tests.yml` menjalankan syntax/ShellCheck seluruh file shell, shfmt terpilih, dan suite.
- Workflow tunggal `.github/workflows/bash-tests.yml` menjalankan syntax, ShellCheck, shfmt terpilih, dan suite pada push/PR; lihat [Testing dan CI](../../docs/04-TESTING.md).

Static/fixture tests tidak menjalankan validator terhadap X280 aktual, tidak menjalankan repair pada host, dan tidak membuktikan UI/physical acceptance.

## Acceptance dan bukti historis

Stage 4 tercatat **COMPLETED / USER ACCEPTED** berdasarkan snapshot historis berikut:

- Validator pada 2026-11-09: **54 PASS, 3 WARN, 0 FAIL, 0 SKIP**, hasil `PASS_WITH_WARNINGS`, exit 0.
- Tiga WARN berasal dari klasifikasi journal user, system, dan kernel sebagai actionable findings. Ini bukan clean PASS; laporan perlu dibaca bersama detail log.
- Repair historis: **8 PASS, 4 WARN, 0 FAIL, 5 SKIP**.
- Pengguna mengonfirmasi Bluetooth berhasil dipair setelah repair membuka Pairable/Discoverable sementara selama 180 detik. Bukti tidak menyatakan arah pairing, model perangkat pasangan, atau pengujian semua perangkat.
- Warning HCI feature/debug masih tercatat; keberhasilan pairing yang dilaporkan tidak membuktikan akar warning tersebut telah diselesaikan.

Snapshot tersebut terikat pada commit historis dan bukan pengukuran kondisi perangkat hari ini. Lihat bukti di [Status proyek](../../docs/06-STATUS.md) dan arsip commit `02f6194ed04c8f13ea64eda35b7afb94f7006504`.

### Batas acceptance yang tidak boleh dilebihkan

Automated validation tidak membuktikan:
- tampilan panel, launcher, dashboard, widget, notifikasi, wallpaper;
- input keyboard, TrackPoint, touchpad, brightness/media keys;
- output speaker dan input microphone secara nyata;
- Wi-Fi reconnect, screenshot flow, portal UI, atau lock/unlock;
- pairing Bluetooth di luar transaksi manual yang secara eksplisit tercatat;
- performa/thermal saat beban terkontrol, battery runtime, suspend/hibernate/resume.

Review visual/interaksi langsung oleh pengguna tetap dilakukan pada perangkat; screenshot bukan artefak atau acceptance gate proyek. Stage 5 dan Stage 6 memiliki gate masing-masing.

## Handoff

- Setelah Stage 4 diterima, lanjutkan customization secara berurutan melalui [Stage 5 workstreams](../../stages/stage-5-desktop-customization/docs/README.md).
- Jangan menganggap hasil Stage 4 sebagai izin untuk menerapkan tuning hardware; Stage 6 membutuhkan baseline dan prosedur tersendiri.
- Bila kode validator, classifier, collector, atau repair berubah, perbarui test dan dokumen ini bersama perubahan implementasi.

## Tests and reports

Stage 4 contract tests live in `stages/stage-4-desktop-validation/tests/`. Validation and repair reports are written under `reports/stage-4-desktop-validation/` and are invoked through the canonical root test manifest.
