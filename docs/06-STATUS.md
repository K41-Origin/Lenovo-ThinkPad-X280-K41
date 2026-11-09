# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan test yang benar-benar tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer destruktif; penerimaan boot fisik tetap dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | IN PROGRESS | Laporan X280 terbaru menunjukkan 52 PASS, 4 WARN, 0 FAIL, 0 SKIP. Repair aktual berhasil menginisialisasi scheme, memasang paket yang hilang, mengaktifkan Bluetooth, dan menjalankan validator. Validator/repair kemudian diperbaiki untuk menghindari false-positive dari log Caelestia lama dan selalu mengumpulkan integritas PAM. Perubahan terakhir belum diuji ulang pada X280; gate menunggu satu run otomatis terbaru. |
| 5. Desktop Customization | PLANNED | Desain sudah ditetapkan; menunggu gate tahap 4 terbaru. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5 dan baseline terukur. |
| 7. Release | PLANNED | Menunggu seluruh gate, regression, dokumentasi, dan bukti final. |

## Entry point kanonis

| Script | Fungsi | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | Live ISO readiness | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | Basic Arch installation | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | Desktop installation | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Read-only desktop health validation | IMPLEMENTED; latest X280 evidence exists, but latest classifier change needs rerun |
| `scripts/k41-desktop-repair.sh` | Scoped automatic repair and evidence collection | IMPLEMENTED; latest X280 run exists, PAM integrity evidence enhancement needs rerun |

## Prioritas saat ini

**CURRENT — Tahap 4: tutup validasi ulang otomatis.**

Perubahan terakhir:
- Caelestia validator membedakan error QML/resource yang belum terselesaikan dari warning opsional `.face` dan peringatan service yang sudah dipulihkan.
- Repair mengumpulkan `pacman -Qkk pambase`, versi paket `pambase`, dan ownership `/etc/pam.d/other` tanpa mengubah file PAM.
- `AGENTS.md` dan dokumentasi desktop diselaraskan dengan implementasi repair tanpa `--apply`.

Langkah penutup: tarik `main`, jalankan `bash scripts/k41-desktop-repair.sh` dari terminal sesi Hyprland sebagai user biasa, lalu push laporan baru di `reports/desktop-repair/` dan `reports/desktop-validation/`. Tidak perlu pemeriksaan visual/fisik manual untuk gate tahap 4; gate ini memang dibatasi pada bukti otomatis. Laporan harus menunjukkan tidak ada FAIL, Caelestia tidak memiliki error QML/resource aktif yang belum terselesaikan, dan temuan PAM disertai hasil integritas serta ownership. WARN kernel/firmware yang tidak dapat diperbaiki secara aman dapat diterima sebagai risiko terdokumentasi; jangan mengubah SMT, kernel parameters, PAM, atau firmware hanya untuk menghilangkan warning.

**Stage 5 tetap PLANNED sampai laporan otomatis setelah perubahan ini diaudit.** Tidak ada klaim bahwa perubahan terakhir telah dijalankan pada X280.

## Bukti terbaru yang tersedia

- Desktop validation `reports/desktop-validation/20261109T064511Z/`: 52 PASS, 4 WARN, 0 FAIL, 0 SKIP; hasil `PASS_WITH_WARNINGS`.
- Repair `reports/desktop-repair/20261109T064428Z/`: 10 PASS, 3 WARN, 0 FAIL, 5 SKIP. Scheme Caelestia berhasil dibuat; BlueZ, bluez-utils, wireless-regdb, dan rtkit terpasang; `bluetooth.service` enabled/running; `regulatory.db` tersedia.
- Caelestia scheme ada pada post-repair snapshot. Runtime log validator lama masih membaca warning yang tercatat sebelum scheme dibuat, serta `.face` opsional; classifier baru ditujukan untuk menghindari false-positive tersebut dan perlu dikonfirmasi dengan rerun.
- PAM `/etc/pam.d/other` terdeteksi readable, tetapi laporan lama tidak memuat hasil `pacman -Qkk pambase` atau ownership file. Penyebab warning PAM runtime belum terbukti; jangan menulis ulang PAM. Repair terbaru kini menyimpan bukti tersebut.
- Bluetooth HCI negotiation dan CPU mitigation MDS/MMIO/VMSCAPE tetap diagnostik-only. Log tidak membuktikan fungsi fisik Bluetooth atau efektivitas setiap mitigasi.
- Tidak ada visual/physical acceptance yang diklaim. Log/runtime validation tidak dapat membuktikan tampilan panel, input fisik, audio output, microphone, suspend/resume, atau interaksi UI.
- CI **SUCCESS** pada commit `d5a477fbd680c55968a623027b11cfa928b63ce0`: Repository validation (run `42575977645`) dan Bash validation (run `42575977590`) selesai sukses. Ini memvalidasi seluruh perubahan script, test, dan dokumentasi sampai commit tersebut.

## Keputusan dan batas

- Repair tidak melakukan full system upgrade, tidak mengubah PAM/kernel/SMT/firmware, dan tidak membuat placeholder profil.
- Laporan dapat memuat username, hostname, path, identitas perangkat, status jaringan, dan journal. Review/redaksi sebelum push.
- Stage 4 tidak mencakup uji visual/fisik sesuai keputusan proyek; status tersebut tidak boleh ditandai VERIFIED.
- Stage 5 berfokus pada tema minimalis monochromatic, elegan/premium, dengan kontras dan keterbacaan terjaga serta beban animasi ringan untuk Intel UHD 620.
