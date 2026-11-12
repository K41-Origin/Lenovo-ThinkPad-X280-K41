# Pengujian, Acceptance, dan Release Gates

## Automated repository tests

Dari root repository:

```bash
bash tests/run.sh
```

Manifest test dan urutannya hanya didefinisikan di `tests/run.sh`; cakupan suite ada di [tests/README.md](../tests/README.md). Suite menggunakan static checks, fixtures, mocks, dan disposable loop-backed image. Hasilnya tidak membuktikan instalasi penuh, firmware boot, atau kompatibilitas hardware.

## CI workflow

Repository menggunakan satu workflow kanonis, `.github/workflows/bash-tests.yml`, yang berjalan pada push ke `main`, pull request ke `main`, dan `workflow_dispatch`. Workflow menjalankan Bash syntax untuk seluruh file shell dan `installer`, ShellCheck seluruh file shell, shfmt pada file infrastruktur test/readiness terpilih, serta `bash tests/run.sh`.

Workflow CI tunggal menghindari duplikasi test suite. Jangan mengubah required checks atau trigger tanpa audit kebutuhan maintenance dan branch protection.

## Gate tujuh tahap

1. **Live readiness:** `bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh` berakhir PASS; laporan dan identitas target direview.
2. **Basic Arch installation:** target SSD dikonfirmasi eksplisit; instalasi fisik, firmware boot, LUKS unlock, dan sistem dasar diperiksa sesuai bukti. First-boot collector opsional.
3. **Desktop installation:** `sudo bash stages/stage-3-desktop-install/scripts/k41-install-desktop.sh` selesai. Exit 0 bukan acceptance desktop.
4. **Desktop functional validation:** jalankan `bash stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` dari sesi Hyprland sebagai user biasa. Hasil PASS/WARN/FAIL/SKIP hanya mencakup pemeriksaan otomatis yang benar-benar dijalankan. Jika perlu, tinjau [peta Stage 4](../stages/stage-4-desktop-validation/README.md) sebelum menjalankan repair yang dapat mengubah sistem.
5. **Desktop customization:** acceptance setiap workstream mengikuti dokumen pemilik di [dokumentasi Stage 5](../stages/stage-5-desktop-customization/docs/README.md) dan peta implementasi fisik [Stage 5](../stages/stage-5-desktop-customization/README.md). Test statis untuk workstream aktif Stage 5 termasuk dalam `tests/run.sh`; Workstream 01 memiliki test kontrak Plymouth-only dan static safety collector audit read-only. Keduanya tidak membuktikan firmware boot, LUKS/TPM unlock, atau recovery. Review visual dilakukan langsung pada perangkat. Screenshot bukan bagian dari workflow atau acceptance.
6. **Desktop & hardware optimization:** bandingkan CPU/GPU, thermal/fan, daya/baterai, suspend/hibernate/resume, stabilitas, dan regresi dengan baseline serta kondisi pengukuran yang sebanding.
7. **Release:** gate 1–6 ditutup, automated tests pada commit final lulus, dokumentasi/status diperbarui, bukti direview, dan release commit/tag dibuat secara eksplisit.

## Interpretasi bukti

- PASS hanya berlaku untuk test, commit, dan lingkungan yang dicatat.
- SKIP bukan PASS.
- Bash syntax check bukan runtime correctness.
- Setup exit 0 bukan UI acceptance.
- UKI yang berhasil dibuat bukan bukti firmware boot.
- Automated runtime/log validation bukan bukti interaksi fisik.
- **COMPLETED / USER ACCEPTED** berarti pengguna menutup workstream secara eksplisit; jangan mengubahnya menjadi klaim pengukuran teknis yang tidak tersedia.

Output test baru ditulis lokal ke `reports/shared/test-runs/` dan tidak dikomit otomatis. Arsip historis tersedia melalui [indeks laporan](../reports/archive/2026-11/README.md). Review dan redaksi data sensitif sebelum membagikan laporan.
