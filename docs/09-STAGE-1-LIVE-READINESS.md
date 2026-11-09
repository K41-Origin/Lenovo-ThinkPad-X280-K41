# Stage 1 — Live Readiness

Dokumen ini adalah peta operasional dan dokumentasi kepemilikan Stage 1. Tujuannya menjelaskan entry point, alur pemanggilan, modul pendukung, keluaran, batas keselamatan, dan test terkait. Dokumen ini bukan hasil runtime test dan bukan instruksi untuk mengubah atau menghapus file.

## 1. Tujuan dan batas tahap

Stage 1 memastikan lingkungan Arch Linux Live dan perangkat target memenuhi prasyarat sebelum Stage 2 melakukan instalasi dasar.

**Entry point kanonis:**

```bash
bash scripts/k41-live-validation.sh
```

Tanpa argumen, script memilih mode `--readiness`.

Stage 1:
- memeriksa checkout repository dan identitas commit/branch;
- memeriksa root, Arch Linux Live ISO, UEFI, identitas DMI ThinkPad X280, dan command wajib;
- mengumpulkan diagnostik host, hardware, block device, mount, swap, dan jaringan;
- memeriksa Bash syntax serta static analysis yang tersedia;
- menjalankan canonical test suite;
- dalam mode readiness, memeriksa identitas SSD X280 dan topology storage secara read-only.

Stage 1 **bukan** izin untuk menghapus disk. PASS hanya berlaku pada checkout, host, dan waktu yang tercatat di laporan. Stage 2 tetap harus mengidentifikasi target dan meminta konfirmasi tersendiri.

## 2. Mode dan entry point

| File/perintah | Peran | Status penggunaan |
|---|---|---|
| `scripts/k41-live-validation.sh` | Implementasi validator kanonis; default dan `--readiness` menjalankan gate ketat, `--diagnostics-only` menjalankan diagnostik host yang lebih luas | Entry point utama |
| `scripts/x280-install-readiness.sh` | Meneruskan argumen ke validator kanonis dengan mode `--readiness` | Compatibility wrapper |
| `scripts/live-validation.sh` | Meneruskan argumen ke validator kanonis dengan mode `--diagnostics-only` | Compatibility wrapper |
| `scripts/x280-archiso-test.sh` | Mengumpulkan inventaris tambahan dari Arch ISO, lalu mendelegasikan seluruh gate readiness ke validator kanonis | Collector tambahan, bukan gate alternatif |
| `scripts/validate-live-storage.sh` | Validasi read-only identitas SSD dan live topology; dipanggil oleh validator dalam mode readiness | Sub-komponen Stage 1 |
| `installer --preflight` | Diagnostik preflight lama yang informasional; dipanggil di akhir validator dan hasil non-zero memang diharapkan selama instalasi belum diimplementasikan | Diagnostik legacy, bukan gate readiness utama |

Untuk workflow normal, jalankan hanya `scripts/k41-live-validation.sh`. Jangan menjalankan wrapper dan implementasi kanonis secara berurutan untuk tujuan yang sama.

### Mode validator

| Mode | Pemeriksaan khusus |
|---|---|
| `--readiness` (default) | Root, Arch ISO marker, UEFI, DMI ThinkPad X280, required commands, dan validasi SSD/topology |
| `--diagnostics-only` | Diagnostik read-only dan repository checks pada host umum; tidak menerapkan seluruh gate khusus Arch ISO/X280 |

Kedua mode menjalankan repository syntax checks, static analysis jika tool tersedia, dan `tests/run.sh`.

## 3. Alur pemanggilan

### 3.1 Alur utama

```text
bash scripts/k41-live-validation.sh
  |
  +-- Repository identity and state
  |     +-- git status
  |     +-- git rev-parse
  |     +-- git branch
  |     +-- git ls-files
  |     +-- git diff
  |
  +-- Readiness-only host gates
  |     +-- root
  |     +-- /etc/arch-release and /run/archiso
  |     +-- UEFI: /sys/firmware/efi
  |     +-- DMI: Lenovo / ThinkPad X280
  |     +-- required command availability
  |
  +-- Optional host evidence
  |     +-- CPU, memory, DMI, PCI, USB
  |     +-- block devices, mounts, swap
  |     +-- network links and IP addresses
  |
  +-- Repository validation
  |     +-- bash -n over discovered shell files
  |     +-- ShellCheck when installed
  |     +-- shfmt on the explicitly listed subset when installed
  |     +-- bash tests/run.sh
  |
  +-- Readiness-only storage gate
  |     +-- scripts/validate-live-storage.sh
  |           +-- lib/storage.sh
  |           +-- lib/storage-topology.sh
  |
  +-- Informational legacy diagnostics
        +-- ./installer --help
        +-- ./installer --preflight (non-zero is expected)
```

### 3.2 Compatibility and supplemental paths

```text
scripts/x280-install-readiness.sh
  +-- exec k41-live-validation.sh --readiness

scripts/live-validation.sh
  +-- exec k41-live-validation.sh --diagnostics-only

scripts/x280-archiso-test.sh
  +-- collect detailed DMI / block / mount / swap evidence
  +-- exec readiness logic via k41-live-validation.sh --readiness
```

Dua wrapper tidak memiliki implementasi pemeriksaan sendiri. Collector Arch ISO menambah laporan rinci, tetapi tidak menggantikan pemeriksaan kanonis dan tidak memanggil storage validator secara terpisah.

## 4. Peta modul dan kepemilikan

| File | Tanggung jawab | Hubungan Stage 1 |
|---|---|---|
| `lib/common.sh` | Logging bersama | Di-source oleh preflight legacy |
| `lib/preflight.sh` | Root, boot mode, command, hardware profile, network-link diagnostics | Digunakan oleh `installer --preflight`; bukan library utama canonical validator |
| `lib/inventory.sh` | Membaca procfs/sysfs dan membandingkan fakta host dengan hardware profile tanpa mengeksekusi profile sebagai shell | Digunakan oleh `lib/preflight.sh` |
| `lib/storage.sh` | Discovery kandidat disk dan validasi ulang identitas target | Digunakan oleh `scripts/validate-live-storage.sh` |
| `lib/storage-topology.sh` | Menelusuri partition, holder/slave, mount, swap, loop backing, dan overlay backing | Dipanggil melalui storage validation |
| `config/hardware/thinkpad-x280.conf` | Referensi deklaratif identitas target untuk adapter inventory | Digunakan oleh `lib/inventory.sh` melalui preflight legacy; bukan sumber serial SSD untuk validator live saat ini |
| `installer` | Entry point diagnostik `--help` dan `--preflight`; instalasi belum diaktifkan | Hanya dipanggil secara informasional oleh canonical validator |

### Catatan pemisahan hardware identity

Ada dua jalur identitas perangkat yang berbeda dan harus dipahami:

1. `lib/inventory.sh` membaca vendor, product name, CPU, dan RAM dari procfs/sysfs, lalu membandingkan subset whitelist terhadap `config/hardware/thinkpad-x280.conf`.
2. `scripts/validate-live-storage.sh` saat ini menetapkan model SSD `WDC PC SN730` dan serial yang diharapkan langsung di dalam script, kemudian mencocokkan tepat satu kandidat disk.

Komentar pada hardware profile menyebut metadata SSD di profile sebagai referensi yang belum dikonsumsi adapter inventory. Karena itu, jangan menganggap semua metadata hardware sudah memiliki satu sumber konfigurasi aktif.

## 5. Pemeriksaan SSD dan batas keselamatan

`scripts/validate-live-storage.sh`:
1. Memastikan command yang dibutuhkan tersedia dan sistem boot UEFI.
2. Memanggil `storage::discover_candidates`.
3. Menampilkan kandidat whole-disk dan metadata keselamatan.
4. Memastikan tepat satu kandidat cocok dengan model dan serial SSD yang dikonfigurasi.
5. Membentuk identitas target menggunakan device path, ukuran, major:minor, dan serial.
6. Memanggil `storage::validate_target` untuk discovery ulang dan pemeriksaan topology terkini.

`lib/storage-topology.sh` membangun closure perangkat melalui sysfs, termasuk partisi dan hubungan holder/slave. Ia membandingkan major:minor dengan mountinfo dan swap, serta memeriksa backing file loop dan path overlay. Keadaan yang tidak dapat dipastikan ditolak (fail closed).

**Batas penting:** pemeriksaan ini tidak mempartisi, memformat, membuka LUKS, me-mount, atau menulis ke SSD target. Pemeriksaan topology juga bukan jaminan bahwa seluruh risiko perangkat keras atau race condition telah dihilangkan.

## 6. Laporan dan efek samping

Validator disebut read-only dalam arti tidak mengubah konfigurasi sistem dan tidak menulis ke SSD instalasi yang dipilih. Namun prosesnya **tidak bebas dari penulisan file**:

| Lokasi | Isi |
|---|---|
| `reports/live-readiness/<timestamp>/summary.md` | Ringkasan hasil readiness, commit, host, dan status check |
| `reports/live-readiness/<timestamp>/diagnostics.log` | Output diagnostik yang menjalani redaksi serial |
| `reports/live-validation/<timestamp>.md` | Laporan host lebih luas; dapat memuat serial dan metadata jaringan |
| `reports/live-validation/latest.md` | Salinan laporan live-validation terbaru |
| `reports/x280-archiso-test/<timestamp>/x280-archiso-test.log` | Laporan tambahan dari collector Arch ISO |
| `reports/test-runs/<timestamp>/` | Log individual, combined log, dan ringkasan test suite |

Laporan dibuat dengan permission terbatas (umask/chmod 600 pada file laporan yang dikelola script). `latest.md` diperbarui setiap kali validator menyelesaikan laporan. Review dan redaksi laporan sebelum membagikannya karena laporan rinci dapat mengandung hardware identifier dan metadata jaringan.

Pada mode readiness ketika `/run/archiso` tersedia, validator memeriksa filesystem checkout dan hanya mengizinkan report checkout pada `overlay` atau `tmpfs`. Collector `x280-archiso-test.sh` mensyaratkan Arch ISO dan pemeriksaan filesystem tersebut sebelum menulis laporannya.

## 7. Test yang terkait

Manifest dan urutan resmi berada hanya di `tests/run.sh`. Saat dokumentasi ini ditulis, manifest berisi 29 test script. `tests/README.md` menjelaskan bahwa suite memakai static contract checks, fixtures, mocks, dan disposable loop-backed image.

| Test | Fokus yang relevan |
|---|---|
| `tests/test-x280-install-readiness.sh` | Syntax/kontrak canonical validator, wrapper, supplemental collector, opsi, laporan, dan batas tanpa operasi instalasi |
| `tests/test-bootstrap-archiso.sh` | Bootstrap, review source, readiness gate, dan otorisasi peluncuran |
| `tests/test-common-preflight.sh` | Common/preflight helper |
| `tests/test-preflight-gate.sh` | Urutan preflight dan fail-closed behavior pada installer diagnostik |
| `tests/test-inventory.sh` | Fixture procfs/sysfs, hardware profile, fakta hilang/konflik, dan penolakan profile malformed |
| `tests/test-storage-discovery.sh` | Discovery kandidat, stable identity, dan kondisi keselamatan |
| `tests/test-storage-prerequisites.sh` | Bukti prasyarat live yang diikat pada storage plan |
| `tests/test-storage-topology.sh` | Fixture mountinfo/sysfs, partition/dependency, swap, loop, overlay, dan keadaan tidak terurai |
| `tests/test-pinned-device-path.sh` | Integrasi core disk tools terhadap disposable loop-backed image |

**Efek test suite:** `test-pinned-device-path.sh` dapat menggunakan loop device dan menjalankan wipefs, sgdisk, mkfs, cryptsetup, mount, dan unmount terhadap image sementara. Ini bukan operasi pada SSD instalasi yang dipilih, tetapi tetap merupakan operasi block-device pada perangkat loop sementara. Karena itu, jangan menyamakan keseluruhan test suite dengan pemeriksaan tanpa efek samping sama sekali.

Test manifest memiliki 29 entries, tetapi tidak semuanya eksklusif Stage 1; suite juga menguji installer, desktop, boot, dan hardware workflow dari tahap lain.

## 8. Cara menjalankan dan membaca hasil

Dari root checkout yang sudah tersedia pada Arch Linux Live ISO:

```bash
bash scripts/k41-live-validation.sh
```

Setelah selesai:
1. Periksa hasil akhir PASS/FAIL dan exit code.
2. Baca `summary.md` pada direktori `reports/live-readiness/` terbaru.
3. Baca laporan `reports/live-validation/` terkait untuk konteks host dan perangkat.
4. Periksa laporan storage dan pastikan identitas SSD sesuai perangkat yang memang akan digunakan.
5. Jangan menafsirkan PASS sebagai otorisasi penghapusan disk; Stage 2 memiliki konfirmasi target dan rencana tersendiri.

Mode diagnostik umum:

```bash
bash scripts/k41-live-validation.sh --diagnostics-only
```

Mode ini bukan pengganti readiness gate pada Arch ISO/X280.

## 9. Batas klaim dan status dokumentasi

- Keberadaan script dan test bukan bukti bahwa script/test telah berhasil dijalankan pada perangkat.
- `bash -n`, ShellCheck, dan shfmt adalah pemeriksaan statis, bukan bukti runtime.
- PASS readiness hanya mencakup pemeriksaan yang benar-benar dijalankan pada snapshot yang dilaporkan.
- Network link/IP inventory tidak membuktikan koneksi internet, DNS, atau akses mirror Arch.
- Test fixture dan loop-backed image tidak membuktikan firmware boot atau instalasi fisik berhasil.
- Laporan yang dibuat oleh validator bukan bukti bahwa Stage 2 aman dijalankan tanpa pemeriksaan target dan konfirmasi tersendiri.

Dokumentasi ini disusun dari inspeksi statis source code dan manifest test pada branch `main`. Tidak ada script atau test yang dijalankan selama penyusunan dokumen ini.

## 10. Referensi source

- `scripts/k41-live-validation.sh`
- `scripts/live-validation.sh`
- `scripts/x280-install-readiness.sh`
- `scripts/x280-archiso-test.sh`
- `scripts/validate-live-storage.sh`
- `installer`
- `lib/common.sh`
- `lib/preflight.sh`
- `lib/inventory.sh`
- `lib/storage.sh`
- `lib/storage-topology.sh`
- `config/hardware/thinkpad-x280.conf`
- `tests/run.sh`
- `tests/README.md`
