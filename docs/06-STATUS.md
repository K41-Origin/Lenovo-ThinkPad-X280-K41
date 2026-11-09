# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan test yang benar-benar tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer destruktif; penerimaan boot fisik tetap dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | IN PROGRESS | Laporan X280 terbaru sebelum perubahan validator saat ini (`20261109T072936Z`) menunjukkan 54 PASS, 2 WARN, 0 FAIL, 0 SKIP; hasil `PASS_WITH_WARNINGS`. Audit lanjutan menemukan false-positive pada warning startup Caelestia yang sudah stale dan query journal kosong; classifier diperketat dan diberi regression fixtures. CI repository dan Bash validation lulus pada commit `a93671071bb069019d954a10039dfc08c6893650`. Gate tetap menunggu rerun pada X280 dengan classifier terbaru. |
| 5. Desktop Customization | PLANNED | Desain sudah ditetapkan; menunggu gate tahap 4 terbaru. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5 dan baseline terukur. |
| 7. Release | PLANNED | Menunggu seluruh gate, regression, dokumentasi, dan bukti final. |

## Entry point kanonis

| Script | Fungsi | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | Live ISO readiness | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | Basic Arch installation | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | Desktop installation | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Read-only desktop health validation | IMPLEMENTED; classifier regression tests and CI pass, latest classifier still needs X280 rerun |
| `scripts/lib/k41-log-classifiers.sh` | Shared Caelestia and journal log classification | IMPLEMENTED; fixture-tested |
| `scripts/k41-desktop-repair.sh` | Scoped automatic repair and evidence collection | IMPLEMENTED; latest X280 run exists, PAM integrity evidence enhancement needs rerun |

## Prioritas saat ini

**CURRENT — Tahap 4: tutup validasi ulang otomatis.**

Perubahan terakhir:
- Caelestia classifier kini hanya mengecualikan warning scheme yang path-nya sama persis dengan file konfigurasi aktif; warning dari path lain tetap actionable. `.face` diperlakukan sebagai resource avatar opsional. BlueZ/RTKit hanya menjadi temuan jika service/package prasyaratnya tidak tersedia.
- Journal classifier kini mengorelasikan pesan boot MDS/MMIO/VMSCAPE dengan file sysfs vulnerability yang sesuai. Status `Mitigation`/`Not affected` tidak otomatis menjadi WARN; status `Vulnerable`, `SMT vulnerable`, atau bukti sysfs yang hilang/tidak dikenal tetap actionable. Regression fixtures mencakup mitigasi penuh, SMT rentan, dan status tidak diketahui.
- Validator menuliskan daftar WARN/FAIL/SKIP langsung di `summary.md`. Repair mengikat diagnosis ke path laporan yang dicetak oleh run validasi pasca-repair, membedakan PASS bersih dari PASS_WITH_WARNINGS, dan mengklasifikasikan PAM/HCI/CPU dari snapshot yang sama. Bukti journal yang tidak tersedia dicatat SKIP.
- Journal classifier membedakan query berhasil tanpa error-priority entries dari kegagalan akses/query. Warning `regulatory.db` lama tidak lagi actionable bila database saat ini sudah readable. Signature kritis dan error tak dikenal tetap diprioritaskan di atas pesan informational.
- Repair mengumpulkan `pacman -Qkk pambase`, versi paket `pambase`, dan ownership `/etc/pam.d/other` tanpa mengubah file PAM.
- `AGENTS.md` dan dokumentasi desktop diselaraskan dengan implementasi repair tanpa `--apply`.

Langkah penutup: tarik `main`, jalankan `bash scripts/k41-desktop-repair.sh` dari terminal sesi Hyprland sebagai user biasa, lalu push laporan baru di `reports/desktop-repair/` dan `reports/desktop-validation/`. Tidak perlu pemeriksaan visual/fisik manual untuk gate tahap 4; gate ini memang dibatasi pada bukti otomatis. Laporan harus menunjukkan tidak ada FAIL, Caelestia tidak memiliki error QML/resource aktif yang belum terselesaikan, dan temuan PAM disertai hasil integritas serta ownership. WARN kernel/firmware yang tidak dapat diperbaiki secara aman dapat diterima sebagai risiko terdokumentasi; jangan mengubah SMT, kernel parameters, PAM, atau firmware hanya untuk menghilangkan warning.

**Stage 5 tetap PLANNED sampai laporan otomatis setelah perubahan ini diaudit.** Tidak ada klaim bahwa perubahan terakhir telah dijalankan pada X280.

## Bukti terbaru yang tersedia

- Desktop validation terbaru yang tersedia `reports/desktop-validation/20261109T072936Z/`: 54 PASS, 2 WARN, 0 FAIL, 0 SKIP; hasil `PASS_WITH_WARNINGS`. Laporan dibuat pada commit `a5330ab6bbc089b9b3d59184e27a8e13b7bab54b`, sebelum perubahan validator/repair pada sesi ini.
- Repair terbaru `reports/desktop-repair/20261109T065932Z/`: 7 PASS, 3 WARN, 0 FAIL, 5 SKIP. Scheme Caelestia sudah ada; BlueZ, bluez-utils, wireless-regdb, dan rtkit terpasang; `bluetooth.service` aktif; `regulatory.db` tersedia.
- Pada laporan `072936Z`, Caelestia runtime berstatus PASS; warning scheme startup dan `.face` tidak lagi menjadi WARN. Ini mengonfirmasi classifier yang ada pada commit laporan tersebut, bukan perubahan baru sesi ini.
- PAM `/etc/pam.d/other` terdeteksi readable, dimiliki `pambase`, dan pemeriksaan `pacman -Qkk pambase` pada repair `065932Z` lulus. User journal pada validasi `072936Z` berisi `-- No entries --`; warning PAM runtime sebelumnya tidak terulang pada snapshot ini, tetapi itu belum membuktikan akar masalahnya telah diperbaiki. Jangan menulis ulang PAM.
- Bluetooth HCI negotiation masih menghasilkan signature `Reading supported features failed (-16)` dan unsupported HCI LE Coded PHY. CPU sysfs pada `072936Z` menunjukkan MDS dan MMIO Stale Data dengan `SMT vulnerable`; VMSCAPE menunjukkan `Mitigation: IBPB before exit to userspace`. MDS/MMIO tetap temuan actionable; VMSCAPE tidak boleh otomatis diperlakukan sebagai vulnerability aktif. Jangan mengubah SMT/kernel parameters hanya untuk menghilangkan pesan.
- Tidak ada visual/physical acceptance yang diklaim. Log/runtime validation tidak dapat membuktikan tampilan panel, input fisik, audio output, microphone, suspend/resume, atau interaksi UI.
- CI **SUCCESS** pada commit `a1881b76363b9dcfa1ba43920cedad7eff506ff5`: Repository validation (run `42578669696`) dan Bash validation (run `42578669698`) selesai sukses untuk kode saat itu. Perubahan classifier/repair/tests pada sesi ini belum memiliki hasil CI yang dapat diverifikasi dari bukti yang tersedia; jangan anggap sudah TESTED sampai workflow terbaru selesai.

## Keputusan dan batas

- Repair tidak melakukan full system upgrade, tidak mengubah PAM/kernel/SMT/firmware, dan tidak membuat placeholder profil.
- Laporan dapat memuat username, hostname, path, identitas perangkat, status jaringan, dan journal. Review/redaksi sebelum push.
- Stage 4 tidak mencakup uji visual/fisik sesuai keputusan proyek; status tersebut tidak boleh ditandai VERIFIED.
- Stage 5 berfokus pada tema minimalis monochromatic, elegan/premium, dengan kontras dan keterbacaan terjaga serta beban animasi ringan untuk Intel UHD 620.
