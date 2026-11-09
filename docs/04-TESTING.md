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
4. **Desktop functional validation:** checklist fisik pada [03 — Desktop](03-DESKTOP.md) diterima.
5. **Desktop customization:** tampilan diterima; screenshot before/after, rollback, dan regression tahap 4 diperiksa.
6. **Desktop & hardware optimization:** CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas dan regression diuji dengan baseline dan rollback.
7. **Release:** seluruh gate 1–6 ditutup, automated tests pada commit final lulus, dokumentasi/status diperbarui, bukti direview, dan release commit/tag dibuat secara eksplisit.

## Interpretasi bukti

PASS hanya berlaku untuk test, commit, dan lingkungan yang dicatat. SKIP bukan PASS. Bash syntax check bukan runtime correctness. Setup exit 0 bukan UI acceptance. UKI bukan bukti firmware boot. Collector bukan pengganti uji fisik. Jangan klaim CI PASS tanpa memeriksa workflow pada commit terkait.

Laporan test berada di `reports/test-runs/`; review dan redaksi informasi sensitif sebelum share.
