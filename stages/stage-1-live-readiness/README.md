# Stage 1 — Live Readiness

Dokumen ini adalah sumber utama untuk struktur, penggunaan, dependensi, pengujian, dan batas keselamatan Stage 1. Script khusus tahap dan test kontraknya ditempatkan di direktori ini. Komponen bersama tetap berada di lokasi repository bersama agar Stage 2 dan tahap lain tidak memiliki salinan dependensi.

## 1. Tujuan dan entry point

Stage 1 memastikan lingkungan Arch Linux Live dan perangkat ThinkPad X280 memenuhi prasyarat sebelum instalasi dasar pada Stage 2.

Jalankan dari root checkout pada Arch Linux Live ISO:

```bash
bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh
```

Tanpa argumen, validator menjalankan mode `--readiness`. PASS hanya berlaku untuk checkout, host, dan waktu yang tercatat. PASS bukan izin menghapus disk; Stage 2 tetap memerlukan identifikasi target, review rencana, backup, dan konfirmasi tersendiri.

## 2. Struktur dan kepemilikan file

```text
stages/stage-1-live-readiness/
├── README.md
├── scripts/
│   ├── k41-live-validation.sh
│   ├── x280-install-readiness.sh
│   ├── live-validation.sh
│   ├── x280-archiso-test.sh
│   └── validate-live-storage.sh
└── tests/
    └── test-x280-install-readiness.sh
```

| File | Peran |
|---|---|
| `scripts/k41-live-validation.sh` | Validator kanonis; default/`--readiness` menjalankan gate Arch ISO/X280, `--diagnostics-only` menjalankan diagnostik host umum |
| `scripts/x280-install-readiness.sh` | Compatibility wrapper ke validator kanonis dalam mode readiness |
| `scripts/live-validation.sh` | Compatibility wrapper ke validator kanonis dalam mode diagnostics-only |
| `scripts/x280-archiso-test.sh` | Collector tambahan DMI, block-device, mount, dan swap; lalu mendelegasikan readiness |
| `scripts/validate-live-storage.sh` | Validasi read-only identitas SSD X280 dan live storage topology |
| `tests/test-x280-install-readiness.sh` | Kontrak statis dan perilaku CLI untuk validator, wrapper, collector, dan safety boundary |

Jalankan validator kanonis untuk workflow normal. Wrapper hanya dipertahankan untuk kompatibilitas. Collector tambahan bukan gate alternatif.

## 3. Komponen bersama — tidak dipindahkan

File berikut dipakai lintas tahap atau merupakan entry point umum. File tetap berada di lokasi bersama dan tidak disalin ke direktori Stage 1.

| Lokasi bersama | Fungsi dan alasan tetap di luar Stage 1 |
|---|---|
| `lib/storage.sh`, `lib/storage-topology.sh` | Discovery, stable identity, dan pemeriksaan topology; juga menjadi dependensi workflow storage Stage 2 |
| `lib/preflight.sh`, `lib/inventory.sh`, `lib/common.sh` | Preflight, inventory hardware, dan helper umum untuk diagnostic installer |
| `config/hardware/thinkpad-x280.conf` | Profil hardware deklaratif yang digunakan adapter inventory |
| `installer` | Entry point diagnostik repository `--help` dan `--preflight`; bukan milik eksklusif Stage 1 |
| `tests/run.sh` dan test storage/preflight bersama | Manifest dan runner seluruh repository; test-test terkait dipakai lintas tahap |
| `scripts/bootstrap-archiso.sh` | Orkestrator lintas Stage 1 dan Stage 2: review source, readiness, lalu otorisasi peluncuran installer |

Test khusus readiness berada di direktori Stage 1, tetapi dipanggil oleh manifest global `tests/run.sh`. Test bootstrap, inventory, preflight, dan storage tetap di `tests/` karena menguji integrasi lintas tahap atau komponen bersama.

## 4. Mode dan alur eksekusi

| Mode | Pemeriksaan |
|---|---|
| `--readiness` (default) | Root, Arch ISO marker, UEFI, DMI ThinkPad X280, command wajib, identitas SSD, dan storage topology |
| `--diagnostics-only` | Diagnostik host dan repository pada host umum; tidak menerapkan seluruh gate Arch ISO/X280 |

Kedua mode memeriksa repository, Bash syntax, static analysis bila tersedia, dan menjalankan `bash tests/run.sh`.

```text
k41-live-validation.sh
  ├── repository identity/state
  ├── readiness host gates (readiness only)
  ├── host/hardware/block/mount/swap/network evidence
  ├── bash -n seluruh file shell yang ditemukan
  ├── ShellCheck dan shfmt bila tersedia
  ├── tests/run.sh
  │     └── stages/stage-1-live-readiness/tests/test-x280-install-readiness.sh
  ├── validate-live-storage.sh (readiness only)
  │     ├── lib/storage.sh
  │     └── lib/storage-topology.sh
  └── installer --help / --preflight (informational legacy diagnostics)
```

Wrapper dan collector:

```text
x280-install-readiness.sh ──> k41-live-validation.sh --readiness
live-validation.sh        ──> k41-live-validation.sh --diagnostics-only
x280-archiso-test.sh      ──> collects evidence, then readiness validator
```

## 5. Identitas hardware dan storage

Terdapat dua jalur identitas yang berbeda:

1. `lib/inventory.sh` membaca vendor, product name, CPU, dan RAM dari procfs/sysfs lalu membandingkan subset whitelist terhadap `config/hardware/thinkpad-x280.conf`.
2. `scripts/validate-live-storage.sh` menetapkan model SSD `WDC PC SN730` dan serial target langsung di script, kemudian mensyaratkan tepat satu kandidat disk cocok.

Metadata SSD pada hardware profile belum menjadi sumber serial aktif bagi live storage validator. Jangan menganggap seluruh metadata hardware telah dikonsolidasikan ke satu sumber konfigurasi.

Storage validator menemukan kandidat whole-disk, memeriksa identitas dan atribut keselamatan, lalu melakukan discovery ulang sebelum validasi topology. `lib/storage-topology.sh` menelusuri partisi dan hubungan holder/slave melalui sysfs, membandingkan major:minor dengan mountinfo dan swap, serta memeriksa loop backing dan overlay backing. Keadaan yang tidak dapat dibuktikan ditolak (fail closed).

**Batas operasi:** Stage 1 tidak mempartisi, memformat, membuka LUKS, me-mount, memasang paket, mengubah service/firmware, atau menulis ke SSD instalasi target. Pemeriksaan topology tidak menghilangkan seluruh risiko race condition atau kegagalan perangkat keras.

## 6. Laporan dan efek samping

Validator bersifat read-only terhadap konfigurasi sistem dan SSD target, tetapi tetap menulis laporan lokal:

| Lokasi | Isi |
|---|---|
| `reports/live-readiness/<timestamp>/` | Ringkasan readiness dan diagnostik dengan serial yang disamarkan |
| `reports/live-validation/<timestamp>.md`, `latest.md` | Diagnostik host lebih luas; dapat memuat serial dan metadata jaringan |
| `reports/x280-archiso-test/<timestamp>/` | Bukti tambahan collector Arch ISO |
| `reports/test-runs/<timestamp>/` | Log dan ringkasan seluruh test suite |

File laporan dikelola dengan permission terbatas (umask/chmod 600). Review dan redaksi laporan sebelum dibagikan karena diagnostik rinci dapat memuat hardware identifier dan metadata jaringan.

Pada Arch ISO, validator readiness dan collector tambahan mensyaratkan checkout berada pada filesystem `overlay` atau `tmpfs` sebelum menulis laporan.

**Catatan test suite:** manifest global berisi 29 test script. Suite memakai static checks, fixtures, mocks, dan disposable loop-backed image. `test-pinned-device-path.sh` dapat menjalankan wipefs, sgdisk, mkfs, cryptsetup, mount, dan unmount terhadap image sementara pada loop device. Itu bukan SSD target, tetapi suite secara keseluruhan tidak bebas dari operasi block-device.

## 7. Test dan validasi

| Test | Kepemilikan |
|---|---|
| `stages/stage-1-live-readiness/tests/test-x280-install-readiness.sh` | Kontrak khusus Stage 1 |
| `tests/test-bootstrap-archiso.sh` | Integrasi bootstrap Stage 1–2 |
| `tests/test-common-preflight.sh`, `tests/test-preflight-gate.sh` | Komponen preflight bersama |
| `tests/test-inventory.sh` | Adapter inventory dan hardware profile |
| `tests/test-storage-discovery.sh`, `tests/test-storage-topology.sh` | Storage identity dan topology bersama |
| `tests/test-storage-prerequisites.sh` | Prasyarat storage yang juga dipakai Stage 2 |
| `tests/test-pinned-device-path.sh` | Integrasi tool disk pada disposable loop-backed image |

Jalankan test suite dari root repository:

```bash
bash tests/run.sh
```

Keberadaan test atau syntax check bukan bukti bahwa readiness berhasil pada ThinkPad X280 fisik. PASS harus berasal dari eksekusi aktual dan laporan untuk snapshot yang relevan.

## 8. Cara menjalankan

Readiness Arch ISO/X280:

```bash
bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh
```

Diagnostik host umum (bukan pengganti readiness gate):

```bash
bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh --diagnostics-only
```

Collector bukti tambahan (opsional):

```bash
bash stages/stage-1-live-readiness/scripts/x280-archiso-test.sh
```

Setelah readiness:
1. Periksa exit code dan hasil PASS/FAIL.
2. Review `summary.md` terbaru di `reports/live-readiness/`.
3. Review laporan `reports/live-validation/` untuk konteks host.
4. Pastikan identitas SSD yang dilaporkan sesuai perangkat target.
5. Lanjutkan ke Stage 2 hanya setelah target, backup, dan rencana instalasi diperiksa secara terpisah.

## 9. Status bukti

Pemetaan ini berdasarkan inspeksi statis source, manifest, workflow CI, dan referensi aktif pada branch `main`. Tidak ada script, test, atau readiness gate yang dijalankan dalam perubahan pemindahan ini. Bash syntax, ShellCheck, shfmt, test suite, dan validasi fisik tetap perlu dijalankan pada tahap verifikasi berikutnya.

## Catatan

Pengembangan Custom Arch ISO dicatat sebagai ide di [dokumen proyek](../../docs/01-PROJECT.md). Ide tersebut belum menjadi bagian dari scope atau acceptance Stage 1.
