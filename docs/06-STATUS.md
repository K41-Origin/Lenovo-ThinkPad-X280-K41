# Status Proyek

**Snapshot: 2026-11-09.** Status dibatasi pada bukti repository, laporan perangkat, dan konfirmasi pengguna yang tersedia.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer; penerimaan boot fisik dibuktikan terpisah. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup; exit 0 bukan penerimaan UI. |
| 4. Desktop Functional Validation | **COMPLETED** | Laporan terbaru 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. WARN ditinjau dan risiko residual didokumentasikan. Pengguna mengonfirmasi pairing Bluetooth berhasil. Batas visual/fisik tetap eksplisit di luar gate. |
| 5. Desktop Customization | **IN PROGRESS** | Profil visual Caelestia/Hyprland telah diterapkan dan pengguna mengonfirmasi perubahan. Workflow opt-in autologin + Caelestia lock screen baru diimplementasikan di repository; belum diuji pada laptop. |
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
| `scripts/k41-enable-caelestia-autologin.sh` | Opt-in tty1 autologin + Hyprland + Caelestia lock startup | IMPLEMENTED — NOT TESTED ON DEVICE |

## Prioritas saat ini

**CURRENT — Tahap 5: Desktop Customization.**

Arah desain telah disetujui dan perubahan tampilan utama telah diterapkan pada perangkat. Langkah aktif berikutnya adalah uji workflow boot otomatis: pull commit, review script, jalankan installer opt-in, reboot, pastikan Caelestia langsung terkunci, uji password unlock, dan validasi rollback. Workflow baru berstatus IMPLEMENTED, belum TESTED/VERIFIED pada perangkat.

Jangan mencampur pekerjaan tahap 5 dengan optimasi daya/termal tahap 6. Hindari animasi/efek berat pada Intel UHD 620.

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
