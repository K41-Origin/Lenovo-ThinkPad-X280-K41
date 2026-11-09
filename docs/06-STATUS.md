# Status Proyek

**Snapshot workflow: 2026-11-09.** Status hanya diperbarui berdasarkan bukti repository dan test yang benar-benar dijalankan.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis; default readiness mode. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer destruktif lama. Tetap perlu physical install/boot acceptance sesuai gate. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup lama. Exit 0 bukan UI acceptance. |
| 4. Desktop Functional Validation | IN PROGRESS | Instalasi desktop dan inventory diagnostik telah dijalankan; Hyprland/Quickshell/IPC terdeteksi. Validator otomatis berbasis log yang lebih lengkap telah IMPLEMENTED, tetapi belum TESTED pada X280 setelah perubahan terbaru. Gate tahap 4 kini menggunakan bukti otomatis PASS/WARN/FAIL/SKIP; interaksi visual/fisik berada di luar cakupan gate dan tidak akan diklaim VERIFIED. |
| 5. Desktop Customization | PLANNED | Menunggu gate tahap 4. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5; baseline dan tuning terukur diperlukan. |
| 7. Release | PLANNED | Menunggu seluruh gate, regression, dokumentasi, dan bukti final. |

## Entry point dan compatibility

| Canonical | Delegates to | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | — | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | `scripts/install-arch-x280.sh` | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | `scripts/setup-desktop-x280.sh` | IMPLEMENTED |
| `scripts/k41-desktop-validation.sh` | Paket, proses, konfigurasi, service, portal, audio, jaringan, baterai, thermal, journal + supplemental collectors | IMPLEMENTED; runtime test pending |

Nama implementasi lama masih ada dan tidak perlu dijalankan terpisah. Bootstrap ISO juga telah diarahkan untuk mereview entry point kanonis dan menjalankan basic-install wrapper.

## Prioritas saat ini

**CURRENT — Tahap 4: Desktop Functional Validation.**

Jangan mulai customization sebelum validator terbaru dijalankan, seluruh FAIL diselesaikan, dan WARN ditinjau/diterima berdasarkan bukti. Jangan mulai tuning daya/hardware sebelum tahap 5 selesai. Jangan menandai RELEASED sebelum seluruh acceptance dan regression gate lulus.

## Bukti historis dan batas

- First Boot historis: 14 PASS, 0 FAIL, 0 SKIP pada snapshot laporan yang tercatat; collector bukan gerbang wajib tahap 3.
- Desktop setup historis: exit 0; tidak membuktikan seluruh UI berfungsi.
- Desktop setup: TESTED — script selesai dengan exit 0 pada laporan `reports/desktop/20261108T190308Z/`; ini bukan bukti penerimaan UI.
- Hyprland/driver/PipeWire: TESTED pada inventory `reports/desktop-diagnostics/20261108T192834Z/`; konfigurasi Hyprland tidak melaporkan error pada snapshot itu.
- Caelestia/Quickshell: TESTED — proses, konfigurasi/QML, dan IPC terdeteksi pada `reports/caelestia-diagnostics/20261108T193701Z/` dan `194633Z/`; panel/UI interaktif belum VERIFIED.
- Cache ownership: VERIFIED — `~/.cache` berubah dari root-owned menjadi user-owned pada `reports/caelestia-permissions-diagnostics/20261108T194621Z/`. Tidak ada perubahan rekursif.
- Cache runtime setelah restart: NOT TESTED — runtime yang tercatat berjalan sebelum ownership repair dan tidak di-restart. Entry point validasi terpadu kini menangani pemeriksaan terarah ini.
- Manual UI dan hardware acceptance: NOT TESTED — isi `reports/desktop-validation/<timestamp>/manual-checklist.md` harus dilengkapi pada perangkat fisik.
- Bluetooth/BlueZ: NOT TESTED — BlueZ tidak tersedia pada snapshot; uji hanya jika fitur ini dibutuhkan.
- CI pada HEAD `d647cca2aa8aac1a06437d881e093da6f35d1348`: Repository Validation dan Bash Validation SUCCESS menurut audit repository terakhir; hasil ini hanya berlaku untuk commit tersebut.

