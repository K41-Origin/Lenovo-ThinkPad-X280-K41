# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan konfirmasi pengguna yang tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer; penerimaan boot fisik dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | **COMPLETED** | Laporan terbaru 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. WARN ditinjau dan risiko residual didokumentasikan. Pengguna mengonfirmasi pairing Bluetooth berhasil. Batas visual/fisik tetap eksplisit di luar gate. |
| 5. Desktop Customization | **IN PROGRESS** | Profil visual Caelestia/Hyprland telah diterapkan dan pengguna mengonfirmasi perubahan. Workflow opt-in autologin + Caelestia lock screen telah diperkuat agar memverifikasi status `isLocked` dan menggunakan Hyprlock sebagai fallback; belum diuji pada laptop. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5 dan baseline terukur. |
| 7. Release | PLANNED | Menunggu seluruh acceptance gate, regression, dokumentasi, dan bukti final. |

## Entry point kanonis

| Script | Fungsi | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | Live ISO readiness | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | Basic Arch installation | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | Desktop installation | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Read-only desktop health validation | IMPLEMENTED |
| `scripts/k41-desktop-repair.sh` | Scoped repair and evidence collection | IMPLEMENTED |
| `scripts/k41-enable-caelestia-autologin.sh` + `scripts/k41-lock-caelestia-after-start.sh` | Opt-in tty1 autologin + verified Caelestia lock startup + Hyprlock fallback | IMPLEMENTED — NOT TESTED ON DEVICE |
| `scripts/audit-x280-boot.sh` | Read-only boot/UKI/LUKS/TPM2/Plymouth state collector | IMPLEMENTED — REPORT COLLECTED (`reports/boot-audit/20261109T103304Z/`) |
| `scripts/k41-configure-boot-experience.sh` + `scripts/k41-plymouth-quit-after-lock.sh` | Plymouth BGRT, quiet splash, lock-aware TTY1 handoff, additive TPM2/PCR7 enrollment | IMPLEMENTED — NOT TESTED ON DEVICE |
| `tests/test-boot-experience.sh` | Static syntax and safety-invariant test for boot setup | IMPLEMENTED — NOT RUN IN THIS SESSION |

## Prioritas saat ini

**CURRENT — Tahap 5: Desktop Customization / boot experience.**

Audit fisik telah dikumpulkan dan direview. TPM2 tersedia, tetapi belum memiliki token; LUKS2 hanya memiliki passphrase keyslot 0; Plymouth belum terpasang; Secure Boot disabled. Berdasarkan bukti tersebut, ditambahkan workflow opt-in Plymouth BGRT yang menahan splash sampai Caelestia lock terverifikasi, serta TPM2 auto-unlock yang mempertahankan passphrase sebagai recovery path.

Langkah aktif berikutnya: pull commit terbaru, review script, siapkan backup header LUKS di disk fisik terpisah, jalankan `sudo bash scripts/k41-configure-boot-experience.sh`, lalu verifikasi token metadata. Setelah itu lakukan reboot fisik. Acceptance: splash muncul selama early boot dan tetap menutup proses startup; TPM membuka root tanpa prompt passphrase; lock screen Caelestia adalah tampilan pertama tanpa banner/login TTY atau desktop Hyprland terlihat; Hyprlock menjadi fallback; kegagalan lock menghentikan tty1 autologin setelah timeout; passphrase lama tetap dapat dipakai sebagai recovery jika TPM unlock gagal. Semua ini masih NOT TESTED/NOT VERIFIED pada perangkat setelah perubahan.

Jangan menghapus keyslot passphrase. Secure Boot masih disabled; PCR 7 saja bukan bukti verifikasi boot penuh. Jangan mencampur pekerjaan tahap 5 dengan optimasi daya/termal tahap 6. Hindari animasi/efek berat pada Intel UHD 620.

## Bukti tahap 4

- Validasi: `reports/desktop-validation/20261109T081724Z/` — 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; `PASS_WITH_WARNINGS`; exit code 0.
- Repair: `reports/desktop-repair/20261109T081723Z/` — 8 PASS, 4 WARN, 0 FAIL, 5 SKIP.
- BlueZ D-Bus/controller snapshot menunjukkan Powered, Pairable, dan Discoverable aktif; Pairable/Discoverable timeout 180 detik. RFKill tidak memblokir adapter dan firmware Intel berhasil dimuat.
- Pengguna mengonfirmasi pairing Bluetooth berhasil. Ini adalah uji manual yang dikonfirmasi pengguna, bukan hasil pairing otomatis dari validator.
- Caelestia lock screen sebelumnya dikonfirmasi berhasil dibuka dengan password.
- Tiga WARN journal masih ada pada validasi otomatis. HCI feature/debug messages masih tercatat di kernel log; pairing tetap berhasil setelah perbaikan readiness. CPU SMT vulnerability warnings adalah risiko residual yang secara eksplisit diterima pengguna dengan SMT tetap aktif. Tidak ada perubahan PAM, kernel parameters, SMT, atau firmware.
- Rincian konfirmasi manual: `reports/desktop-validation/20261109T081724Z/manual-acceptance.md`.
- Tahap 4 tidak mengklaim uji visual/fisik. Interaksi fisik/UI yang tidak tercakup tetap dapat diuji selama tahap 5 sebagai regression/acceptance tambahan.

## Keputusan dan batas

- Pairing Bluetooth menggunakan jendela Pairable/Discoverable sementara 180 detik; jangan menjadikannya always-discoverable.
- Repair tidak melakukan full system upgrade dan tidak mengubah PAM/kernel/SMT/firmware.
- Laporan dapat memuat username, hostname, path, identitas perangkat, status jaringan, dan journal. Review/redaksi sebelum push.
- Tahap 5 berfokus pada tema minimalis monochromatic, elegan/premium, dengan kontras dan keterbacaan terjaga serta beban animasi ringan untuk Intel UHD 620.
