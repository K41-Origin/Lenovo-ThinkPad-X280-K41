# Stage 2 — Basic Arch Installation

Dokumen ini adalah sumber utama untuk pemetaan implementasi, alur instalasi, dependensi, batas keselamatan, recovery, dan test Stage 2. Stage 2 memasang sistem Arch Linux dasar pada SSD internal ThinkPad X280 dari Arch Linux Live ISO.

> **PERINGATAN — DESTRUKTIF:** installer menghapus signature dan tabel partisi pada disk target, membuat partisi baru, memformat ESP dan root terenkripsi, lalu memasang sistem. Jangan menjalankannya sebelum backup, identitas target, dan rencana instalasi diverifikasi secara manual.

## 1. Tujuan dan entry point

Entry point kanonis saat ini:

```bash
bash stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh
```

Wrapper tersebut meneruskan seluruh argumen ke implementasi:

```text
stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh
  └── stages/stage-2-basic-arch-install/scripts/install-arch-x280.sh
```

Jalankan dari root checkout pada **Arch Linux Live ISO**, sebagai root, dalam mode UEFI. Installer memverifikasi keberadaan `/run/archiso`, filesystem checkout (`overlay` atau `tmpfs`), root privilege, UEFI, profil hardware X280, dan prasyarat command.

Urutan operasional yang disarankan:
1. Boot ISO resmi Arch Linux pada ThinkPad X280 dengan UEFI.
2. Checkout repository pada filesystem live.
3. Jalankan Stage 1 readiness dan review laporan.
4. Review source installer dan target SSD.
5. Jalankan entry point Stage 2.
6. Baca seluruh storage plan; hanya konfirmasi jika target dan layout benar-benar sesuai.
7. Setelah installer selesai, periksa hasil dan lakukan unmount/close secara manual. Installer tidak reboot otomatis.

Stage 1 PASS adalah bukti readiness pada satu snapshot, bukan otorisasi menghapus disk. Stage 2 selalu memiliki gate identitas dan konfirmasi target sendiri.

## 2. Peta file dan kepemilikan

File yang eksklusif untuk Stage 2 dikelompokkan di direktori tahap ini. Modul storage bersama berada di `shared/lib/`; orchestrator lintas tahap dan test runner global tetap berada di lokasi repository bersama.

| Path | Peran | Kepemilikan |
|---|---|---|
| `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh` | Entry point kanonis yang tipis | Khusus Stage 2 |
| `stages/stage-2-basic-arch-install/scripts/install-arch-x280.sh` | Orkestrasi instalasi destruktif dari preflight sampai validasi artefak boot | Khusus Stage 2 |
| `stages/stage-2-basic-arch-install/scripts/configure-arch-x280.sh` | Helper interaktif yang disalin dan dijalankan di dalam `arch-chroot` target | Khusus Stage 2 |
| `stages/stage-2-basic-arch-install/scripts/resume-arch-x280.sh` | Utility continuation lama untuk checkpoint pasca-pacstrap | **LEGACY — bukan recovery path aktif; jangan dijalankan** |
| `stages/stage-2-basic-arch-install/lib/base-system.sh` | Validasi mount, instalasi paket dasar, dan penulisan fstab | Modul Stage 2 |
| `shared/lib/storage-plan.sh` | Perhitungan layout dan binding target/profile | Modul storage; dipakai workflow Stage 2 dan test storage |
| `shared/lib/storage-prerequisites.sh` | Snapshot prasyarat live read-only dan pengikatan evidence | Modul storage Stage 2 |
| `shared/lib/storage-confirmation.sh` | Review plan, exact confirmation, final revalidation, one-shot gate | Modul storage Stage 2 |
| `shared/lib/storage.sh`, `shared/lib/storage-topology.sh` | Discovery disk, identitas stabil, dan topology | **Bersama Stage 1 dan Stage 2; jangan dipindahkan sebagai file eksklusif** |
| `shared/lib/common.sh`, `shared/lib/preflight.sh`, `shared/lib/inventory.sh` | Logging, command/boot checks, dan hardware inventory | Modul bersama |
| `scripts/bootstrap-archiso.sh` | Clone main, verifikasi checkout, source review, readiness, lalu otorisasi peluncuran | Orkestrator Stage 1–2 |
| `scripts/x280-first-boot-check.sh` | Collector diagnostik setelah instalasi/boot pertama | Lintas tahap; bukan gate wajib Stage 2–3 |
| `tests/run.sh` | Manifest dan runner seluruh repository | Global; jangan dipindahkan |
| `tests/helpers/storage-fixtures.sh` | Fixture identitas/topology untuk test storage | Bersama |

`shared/lib/storage-execution-dry-run.sh` dan `shared/lib/storage-execution-boundary.sh` adalah simulator/mock-only untuk pengujian desain execution boundary. Keduanya bukan jalur eksekusi yang dipanggil installer produksi. Komentar modul boundary mengaitkannya dengan Stage 7; jangan menyimpulkan installer aktual sudah menggunakan modul tersebut.

### Status utility resume

`stages/stage-2-basic-arch-install/scripts/resume-arch-x280.sh` masih ada karena kompatibilitas/histori dan memiliki test statis, tetapi dokumentasi aktif mengecualikannya dari workflow recovery fisik. Jangan menjalankannya untuk melanjutkan instalasi yang terputus. Test keberadaan atau syntax script ini bukan persetujuan untuk menggunakannya.

## 3. Alur implementasi

```text
k41-install-basic-arch.sh
  └── install-arch-x280.sh
       ├── root + Arch ISO + overlay/tmpfs + UEFI + X280 preflight
       ├── secure repository-local installer log
       ├── discover internal NVMe candidates
       ├── select target and verify X280 SSD identity
       ├── calculate GPT/ESP/root/swap layout
       ├── bind target identity and live prerequisites to plan
       ├── render plan and request exact operator confirmation
       ├── re-discover/revalidate target and consume one-shot gate
       ├── pin whole-disk and partition block descriptors
       ├── wipe old signatures and create GPT partitions
       ├── format ESP FAT32 and root LUKS2 → ext4
       ├── open cryptroot; mount root at /mnt and ESP at /mnt/efi
       ├── pacstrap -K + UUID-based fstab
       ├── arch-chroot: hostname/user/password/locale/timezone/swapfile
       ├── systemd-boot + mkinitcpio UKI
       └── validate fstab, swap, user config, and UKI artifacts
```

### 3.1 Preflight dan logging

Installer menolak kondisi berikut:
- bukan root atau bukan Arch Linux ISO;
- checkout bukan pada filesystem `overlay`/`tmpfs`;
- UEFI tidak aktif;
- hardware inventory tidak cocok dengan profil ThinkPad X280;
- `/mnt/etc` sudah ada;
- command wajib tidak tersedia.

Log dibuat di `reports/stage-2-basic-arch-install/installer/<UTC timestamp>/installer.log`, direktori permission `0700`, file `0600`. Log mencatat tahap terakhir dan exit status. Passphrase dibaca secara interaktif dan tidak sengaja dimasukkan ke log; shell xtrace tidak diaktifkan.

### 3.2 Identitas target SSD

Installer memilih dari whole-disk NVMe internal yang ditemukan. Ia memeriksa:
- transport NVMe, bukan removable, dan writable;
- model mengandung `WDC PC SN730`;
- kapasitas tepat `256060514304` byte;
- serial tepat `193839803177`;
- tersedia WWN atau serial sebagai stable identity;
- tidak ada mounted descendant atau active swap descendant;
- topology live storage lolos pemeriksaan.

Path `/dev/nvme...` saja bukan identitas yang cukup. Identitas, major:minor, kapasitas, dan atribut keselamatan dikumpulkan ulang pada tahap revalidation. Setelah konfirmasi, installer membuka dan menahan descriptor block device, lalu meneruskan path `/proc/self/fd/N` ke tool storage agar operasi mengacu pada object yang telah dipin.

**Penting:** model, kapasitas, dan serial tersebut di-hardcode dalam implementasi. Stage 1 storage validator juga memiliki pemeriksaan identitas sendiri. Jangan menganggap kedua gate membaca satu konfigurasi profil tunggal.

### 3.3 Layout disk dan konfirmasi

Planner menghitung layout dari ukuran disk dan logical/physical sector:
- GPT dengan 128 entries dan alignment 1 MiB;
- ESP 1 GiB, FAT32, GPT type EFI System Partition;
- partisi root menggunakan GPT type Linux LUKS;
- root memakai LUKS2 dan ext4;
- root mengambil sisa kapasitas yang tersedia setelah ESP;
- swapfile direncanakan sebesar RAM live saat itu + margin 2 GiB;
- planner mensyaratkan minimal 32 GiB headroom di root di luar ukuran swap.

Sebelum operasi disk, installer menampilkan ringkasan target, identitas, ukuran, partisi, enkripsi, filesystem, swap, boot mode, dan prerequisite evidence. Konfirmasi harus persis:

```text
ERASE <device-path> <12 karakter awal review digest>
```

Digest mengikat representasi plan; digest **bukan** mekanisme autentikasi atau pengganti pemeriksaan manusia. Konfirmasi salah, perubahan plan, perubahan identitas, atau kegagalan final revalidation harus menghentikan proses.

### 3.4 Operasi disk dan filesystem

Setelah gate lolos, operasi aktual meliputi:
1. `wipefs --all --force` pada target;
2. membuat GPT, ESP, dan partisi root;
3. sinkronisasi partition table dan menunggu udev;
4. `cryptsetup luksFormat --type luks2` pada partisi root;
5. membuka mapper `cryptroot`;
6. memformat ESP FAT32 dan root ext4;
7. mount root ke `/mnt`, ESP ke `/mnt/efi`.

Ini adalah operasi destruktif terhadap seluruh disk target. Tidak ada rollback otomatis yang dapat memulihkan data lama.

### 3.5 Instalasi sistem dasar

`stages/stage-2-basic-arch-install/lib/base-system.sh` memvalidasi bahwa root adalah mount ext4 dari mapper terenkripsi dan ESP adalah mount vfat terpisah pada `/efi` di dalam target. Paket dasar dipasang dengan `pacstrap -K`:

- `base`, `linux`, `linux-firmware`
- `cryptsetup`, `networkmanager`, `sudo`
- `e2fsprogs`, `dosfstools`
- `iptables`, `mkinitcpio`
- `nano`, `man-db`, `man-pages`

Fstab dihasilkan menggunakan UUID. Writer memvalidasi tepat satu entry root dan satu entry `/efi`, mempertahankan mount lain yang tidak terkait, menolak konflik/duplikasi, dan menormalkan opsi ESP menjadi `fmask=0177,dmask=0077`. Helper ini dirancang idempotent terhadap entry yang sudah sesuai.

### 3.6 Konfigurasi target dan boot

Helper `configure-arch-x280.sh` berjalan sebagai root di dalam `arch-chroot`, dengan input melalui TTY. Default prompt:
- hostname: `thinkpad-x280`;
- username: `kai`;
- timezone: `Asia/Jakarta`;
- locale: `en_US.UTF-8`.

Nilai tetap divalidasi. Helper membuat user anggota grup `wheel`, mengatur sudo rule, meminta password interaktif, mengatur hostname/hosts/locale/timezone, membuat swapfile dengan permission `0600`, memperbarui fstab, dan enable NetworkManager. Password tidak ditulis sebagai argumen command atau log.

Intel microcode **tidak dipasang otomatis** berdasarkan keputusan proyek yang tercatat; saat ini hanya menjadi rekomendasi. Hibernation/resume juga **belum dikonfigurasi**: swapfile dibuat, tetapi resume offset dan parameter resume tidak ditambahkan.

Boot setup saat ini:
- systemd-boot;
- mkinitcpio UKI;
- systemd-based `sd-encrypt` hook;
- kernel command line memakai `rd.luks.name=<LUKS-UUID>=cryptroot root=/dev/mapper/cryptroot rw`;
- UKI di `/efi/EFI/Linux/arch-linux.efi`;
- Secure Boot dinyatakan disabled pada storage profile.

Installer menyalin `x280-first-boot-check.sh` ke target sebagai collector. Collector tersebut bukan gate wajib untuk menjalankan Stage 3. Jika dijalankan dari checkout, output default berada di `reports/stage-2-basic-arch-install/first-boot/`.

## 4. Syarat operator sebelum menjalankan

Sebelum memulai:
- backup data yang diperlukan dan pastikan backup dapat diakses;
- boot ISO resmi Arch dalam mode UEFI;
- jalankan Stage 1 readiness dan periksa laporan;
- pastikan checkout berasal dari repository/commit yang memang ingin dipasang;
- baca wrapper, implementasi installer, helper konfigurasi, dan modul storage;
- verifikasi model, serial, kapasitas, dan stable identity SSD secara independen;
- pastikan disk yang dipilih memang boleh dihapus;
- review layout dan swap size yang ditampilkan;
- jangan melanjutkan jika target, plan, atau kondisi topology tidak sepenuhnya jelas.

Jangan menebak path disk dan jangan mengandalkan nomor indeks tanpa memeriksa identitas lengkap.

## 5. Kegagalan dan recovery

Installer tidak menyediakan rollback otomatis. Jika gagal atau terputus:
1. Jangan langsung menjalankan ulang installer.
2. Jangan menjalankan `stages/stage-2-basic-arch-install/scripts/resume-arch-x280.sh`; utility itu bukan recovery path yang disetujui.
3. Simpan dan periksa log terakhir di `reports/stage-2-basic-arch-install/installer/`.
4. Boot/pertahankan lingkungan recovery yang sesuai dan periksa kondisi aktual partition table, LUKS, mapper, filesystem, mount, fstab, dan UKI tanpa melakukan write tambahan.
5. Jangan meng-unmount, menutup mapper, memformat, atau mengulang langkah secara otomatis jika kondisi belum dipahami.
6. Tentukan prosedur recovery baru berdasarkan kondisi aktual dan persetujuan operator.

Kegagalan setelah sebagian operasi dapat meninggalkan disk dalam keadaan parsial. Exit code non-zero tidak menjelaskan sendiri operasi terakhir yang benar-benar selesai; gunakan log dan inspeksi read-only. Jangan menganggap seluruh operasi sebelumnya berhasil atau gagal hanya dari pesan tahap.

## 6. Test dan batas bukti

Test relevan yang terdaftar di manifest global `tests/run.sh`:

| Test | Cakupan |
|---|---|
| `stages/stage-2-basic-arch-install/tests/test-arch-installer-script.sh` | Kontrak statis installer, urutan guard, target, confirmation, descriptor pinning, operasi, dan postcondition |
| `stages/stage-2-basic-arch-install/tests/test-base-system-fstab.sh` | Fstab: preserve entry lain, permission mask ESP, idempotency, konflik, package arguments |
| `tests/test-storage-plan.sh` | Perhitungan layout, alignment, overflow, profile binding, digest, validasi plan |
| `tests/test-storage-prerequisites.sh` | Mock discovery, UEFI/tool/topology prerequisite, stable identity |
| `tests/test-storage-confirmation.sh` | Exact confirmation, digest binding, final revalidation, one-shot gate |
| `tests/test-pinned-device-path.sh` | Integrasi tool storage pada disposable loop-backed image; membutuhkan root dan tool terkait |
| `stages/stage-2-basic-arch-install/tests/test-resume-arch-installer.sh` | Kontrak statis utility resume legacy; bukan validasi recovery fisik |
| `tests/test-bootstrap-archiso.sh` | Integrasi statis orkestrator Stage 1–2 |

`tests/test-storage-execution-dry-run.sh` dan `tests/test-storage-execution-boundary.sh` menguji simulator/mock boundary. Mereka tidak mengeksekusi disk target dan tidak membuktikan installer produksi memakai boundary tersebut.

Jalankan seluruh suite dari root repository:

```bash
bash tests/run.sh
```

Test statis, fixture, mock, dan loop-device bukan bukti bahwa instalasi penuh berhasil pada ThinkPad X280. Belum ada klaim verifikasi fisik Stage 2 dari dokumentasi ini. VM bukan metode validasi proyek berdasarkan keputusan yang berlaku.

## 7. Batas hasil Stage 2

Jika installer menyelesaikan exit 0, artefak yang diharapkan telah diperiksa secara otomatis: fstab, swapfile entry, hostname, locale, timezone symlink, dan UKI. Ini belum membuktikan firmware benar-benar boot dari UKI atau sistem dapat membuka LUKS dan login secara fisik.

Stage 2 hanya menyediakan base Arch. Komponen berikut berada di tahap berikutnya atau belum diimplementasikan:
- Hyprland, Quickshell, dan Caelestia Shell;
- tuning hardware, thermal, dan power X280;
- hibernation/resume;
- pengelolaan recovery key;
- selective BlackArch;
- Secure Boot.

Tidak ada reboot otomatis. Periksa hasil sebelum melakukan unmount `/mnt/efi`, unmount `/mnt`, dan menutup mapper `cryptroot` secara manual.

## Catatan

Pengembangan Custom Arch ISO dicatat sebagai ide di [dokumen proyek](../../docs/01-PROJECT.md). Ide tersebut belum menjadi bagian dari scope atau acceptance Stage 2.

## Tests and reports

Stage-owned tests live in `stages/stage-2-basic-arch-install/tests/` and are invoked by the root `tests/run.sh` manifest. Installer and resume evidence is written under `reports/stage-2-basic-arch-install/installer/`.
