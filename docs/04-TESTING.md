# Pengujian, Acceptance, dan Release Gates

## Automated repository tests

Dari root repository:

```bash
bash tests/run.sh
```

Manifest dan urutan test hanya didefinisikan di `tests/run.sh`; cakupan test dijelaskan di [tests/README.md](../tests/README.md). Suite menggunakan static checks, fixtures, mocks, dan disposable loop-backed image. Suite tidak membuktikan instalasi penuh, firmware boot, atau kompatibilitas hardware.

## Gate berdasarkan tujuh tahap

1. **Live readiness:** `bash scripts/k41-live-validation.sh` berakhir PASS; laporan dan identitas target direview.
2. **Basic Arch installation:** target SSD dikonfirmasi secara eksplisit; instalasi fisik selesai; firmware boot, LUKS unlock, dan sistem dasar tervalidasi sesuai bukti. First-boot collector opsional, bukan gate terpisah sebelum desktop.
3. **Desktop installation:** `sudo bash scripts/k41-install-desktop.sh` selesai. Exit 0 bukan desktop acceptance.
4. **Desktop functional validation:** jalankan `bash scripts/k41-desktop-validation.sh` dari terminal sesi Hyprland sebagai user biasa. Script menjalankan pemeriksaan otomatis atas paket, proses, konfigurasi Hyprland, IPC/runtime Caelestia, service, portal, audio graph, jaringan, radio, kapasitas filesystem, baterai, temperatur, dan journal. Hasil diklasifikasikan PASS/WARN/FAIL/SKIP di `checks.tsv`; perintah dan bukti rinci disimpan di `validation.log` serta direktori collector. Hasil PASS hanya berarti tidak ada kondisi gagal otomatis yang terdeteksi pada snapshot tersebut; log tidak dapat membuktikan interaksi visual/fisik atau fungsi hardware secara menyeluruh. Diagnosis lanjutan disimpan pada `diagnostics.tsv` dan `diagnostics.log`, mencakup kernel command line, CPU mitigations, PCI/USB dan driver, paket/firmware, properti service, hwmon/thermal, ThinkPad ACPI, serta unit gagal. Koleksi ini read-only dan sengaja tidak mengambil profil koneksi Wi-Fi, environment variables, atau command line proses lengkap. Tinjau dan redaksi seluruh laporan sebelum dibagikan. Jika ada WARN/FAIL, jalankan `bash scripts/k41-desktop-repair.sh` untuk audit remediation otomatis; mode default read-only. Opsi `--apply` hanya mengizinkan enable/start BlueZ yang sudah terpasang setelah konfirmasi interaktif. Validator dijalankan ulang otomatis kecuali diberi `--no-validate`.
5. **Desktop customization:** tampilan diterima; screenshot before/after, rollback, dan regression tahap 4 diperiksa.
6. **Desktop & hardware optimization:** CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas dan regression diuji dengan baseline dan rollback.
7. **Release:** seluruh gate 1–6 ditutup, automated tests pada commit final lulus, dokumentasi/status diperbarui, bukti direview, dan release commit/tag dibuat secara eksplisit.

## Interpretasi bukti

PASS hanya berlaku untuk test, commit, dan lingkungan yang dicatat. SKIP bukan PASS. Bash syntax check bukan runtime correctness. Setup exit 0 bukan UI acceptance. UKI bukan bukti firmware boot. Automated runtime/log validation bukan bukti interaksi visual/fisik; hasilnya hanya berlaku pada checks yang benar-benar dapat diobservasi. Jangan klaim CI PASS tanpa memeriksa workflow pada commit terkait.

Laporan test berada di `reports/test-runs/`; review dan redaksi informasi sensitif sebelum share.
