# Panduan Test

Jalankan dari root: `bash tests/run.sh`. Daftar dan urutan test hanya didefinisikan di `tests/run.sh`; jangan membuat manifest duplikat.

Suite memakai static contract checks, fixture, mock (termasuk mock Caelestia IPC untuk autologin/lock startup), dan disposable loop-backed image. Workstream 01 memiliki kontrak test Plymouth-only (tanpa QML/Quickshell) serta static safety test untuk collector audit read-only; keduanya tidak membuktikan boot fisik, LUKS unlock, TPM, atau recovery. Manifest global menjalankan test integrasi lintas-stage dan memanggil test stage-owned melalui path masing-masing. Test bootstrap repository tetap global; first-boot check berada di Stage 2, sedangkan Guest Mode audit dan fixture direct Dashboard cleanup berada di Stage 5; hardware/power audit dan selector berada di Stage 6. Suite tidak menjalankan instalasi Arch penuh, tidak menguji firmware boot, dan tidak menggantikan acceptance fisik X280.

Laporan berada di `reports/shared/test-runs/<UTC timestamp>/`. SKIP bukan PASS. Review data sensitif sebelum share.

Lihat [04 — Pengujian dan Acceptance](../docs/04-TESTING.md) untuk gate, live validation, dan interpretasi bukti.
