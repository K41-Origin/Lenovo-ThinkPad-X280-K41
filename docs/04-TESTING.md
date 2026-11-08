# Pengujian dan Acceptance

## Test suite
Dari root: `bash tests/run.sh`. Manifest hanya di `tests/run.sh`; detail cakupan di [tests/README.md](../tests/README.md). Suite memakai static checks, fixture, mock, disposable loop image; bukan instalasi penuh atau bukti firmware boot/hardware.

## Live validation
- Diagnostik: `bash scripts/live-validation.sh`
- Readiness Arch ISO/X280: `bash scripts/k41-live-validation.sh --readiness`
- Storage read-only: `bash scripts/validate-live-storage.sh`

Review laporan; redaksi serial, UUID, token, alamat, dan data sensitif.

## Acceptance gates
1. Installer: source review, readiness, target revalidation, physical install, firmware boot, LUKS unlock, First Boot.
2. Desktop: checklist fisik pada [03 Desktop](03-DESKTOP.md).
3. Customization: visual/interaksi diterima; before/after dan rollback.
4. Optional software: komponen terpilih; dependensi, security, uninstall/rollback.
5. Hardware final: thermal, daya, battery, suspend/hibernate/resume, stability/regression.

PASS berlaku hanya untuk test, commit, dan lingkungan tercatat. SKIP bukan PASS. Setup exit 0 bukan UI acceptance. UKI bukan bukti boot. Jangan klaim CI PASS tanpa memeriksa commit terkait.

Laporan disimpan di `reports/test-runs/`; review sebelum share. Laporkan command, commit, PASS/FAIL/SKIP, dan batas pengujian.
