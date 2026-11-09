# Status Proyek

**Snapshot workflow: 2026-11-09.** Status hanya diperbarui berdasarkan bukti repository dan test yang benar-benar dijalankan.

## Tahapan proyek

| Tahap | Status | Bukti / batas |
|---|---|---|
| 1. Arch ISO — Live Readiness | IMPLEMENTED | `scripts/k41-live-validation.sh` adalah entry point kanonis; default readiness mode. |
| 2. Arch ISO — Basic Arch Installation | IMPLEMENTED | Entry point `k41-install-basic-arch.sh` mendelegasikan ke installer destruktif lama. Tetap perlu physical install/boot acceptance sesuai gate. |
| 3. Basic Arch — Desktop Installation | IMPLEMENTED | Entry point `k41-install-desktop.sh` mendelegasikan ke desktop setup lama. Exit 0 bukan UI acceptance. |
| 4. Desktop Functional Validation | IN PROGRESS / NOT ACCEPTED | Tahap aktif. Bukti diagnostik tersedia; checklist penerimaan fisik belum disetujui. |
| 5. Desktop Customization | PLANNED | Menunggu gate tahap 4. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu tahap 5; baseline dan tuning terukur diperlukan. |
| 7. Release | PLANNED | Menunggu seluruh gate, regression, dokumentasi, dan bukti final. |

## Entry point dan compatibility

| Canonical | Delegates to | Status |
|---|---|---|
| `scripts/k41-live-validation.sh` | — | IMPLEMENTED |
| `scripts/k41-install-basic-arch.sh` | `scripts/install-arch-x280.sh` | IMPLEMENTED |
| `scripts/k41-install-desktop.sh` | `scripts/setup-desktop-x280.sh` | IMPLEMENTED |

Nama implementasi lama masih ada dan tidak perlu dijalankan terpisah. Bootstrap ISO juga telah diarahkan untuk mereview entry point kanonis dan menjalankan basic-install wrapper.

## Prioritas saat ini

**CURRENT — Tahap 4: Desktop Functional Validation.**

Jangan mulai customization sebelum checklist tahap 4 diterima. Jangan mulai tuning daya/hardware sebelum tahap 5 selesai. Jangan menandai RELEASED sebelum seluruh acceptance dan regression gate lulus.

## Bukti historis dan batas

- First Boot historis: 14 PASS, 0 FAIL, 0 SKIP pada snapshot laporan yang tercatat; collector bukan gerbang wajib tahap 3.
- Desktop setup historis: exit 0; tidak membuktikan seluruh UI berfungsi.
- Hyprland/driver/PipeWire terdeteksi pada snapshot diagnostik sebelumnya; Caelestia/Quickshell UI acceptance belum dibuktikan secara penuh.
- Bluetooth dan beberapa fungsi fisik tetap perlu diuji sesuai kebutuhan.
- Status CI untuk commit terbaru tidak dinyatakan di sini; periksa workflow run pada commit yang relevan.

