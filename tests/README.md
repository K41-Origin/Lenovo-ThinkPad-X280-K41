# Panduan Test

Jalankan dari root: `bash tests/run.sh`. Daftar dan urutan test hanya didefinisikan di `tests/run.sh`; jangan membuat manifest duplikat.

Suite memakai static contract checks, fixture, mock (termasuk mock Caelestia IPC untuk autologin/lock startup), dan disposable loop-backed image. Manifest global juga menjalankan test Stage 5 untuk boot experience, Plymouth theme, animated splash, autologin, dan lock-screen design. Suite tidak menjalankan instalasi Arch penuh, tidak menguji firmware boot, dan tidak menggantikan acceptance fisik X280.

Laporan berada di `reports/test-runs/<UTC timestamp>/`. SKIP bukan PASS. Review data sensitif sebelum share.

Lihat [04 — Pengujian dan Acceptance](../docs/04-TESTING.md) untuk gate, live validation, dan interpretasi bukti.
