# Workstream 2 — Lock Screen

**Status: IN PROGRESS.** Workstream 1 telah ditutup dan diterima pengguna. Workstream 2 adalah prioritas aktif Stage 5.

## Tujuan

Menyelesaikan tampilan dan interaksi Caelestia lock screen dengan desain **C — Floating Password Card**, sambil mempertahankan autentikasi upstream yang sudah bekerja.

## Keputusan desain

- Wallpaper dan efek blur upstream tetap menjadi latar.
- Surface luar/area pembungkus dibuat transparan.
- Password input mempertahankan surface rounded tersendiri.
- Kelompok clock/date/password diposisikan secara geometris di tengah area konten.
- Jangan mengubah PAM, password, fingerprint/Howdy policy, atau mekanisme autentikasi hanya untuk kosmetik.

Detail visual lintas-komponen mengacu pada [Design System](../../../docs/07-DESKTOP-DESIGN-SYSTEM.md).

## Implementasi repository

Override QML yang dikelola proyek:
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/LockSurface.qml`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/Content.qml`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/Center.qml`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/quickshell/caelestia/modules/lock/center/PasswordInput.qml`

Installer deployment:
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh`

Collector audit:
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh`
- `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh`

Test statis:
- `tests/test-lockscreen-design.sh`

**Status implementasi:** IMPLEMENTED di repository. Implementasi terbaru belum dinyatakan TESTED/VERIFIED pada ThinkPad X280. Keberadaan file atau keberhasilan installer tidak membuktikan bahwa source lokal aktif, QML berhasil dimuat, atau tampilan diterima.

## Prosedur penerapan dan pemeriksaan

Dari checkout terbaru pada perangkat:

```bash
git pull --ff-only origin main
bash -n stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh
bash tests/test-lockscreen-design.sh
sudo bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh
```

Ikuti validasi dan instruksi yang benar-benar dicetak installer. Setelah deployment:
1. Periksa source path Caelestia yang aktif; pastikan mengarah ke source tree lokal yang dikelola, bukan fallback system path.
2. Restart Caelestia dari terminal sesi Hyprland sebagai user biasa sesuai prosedur collector.
3. Pastikan runtime QML tidak menghasilkan error.
4. Uji lock, unlock dengan password benar/salah, dan wake/resume.
5. Periksa posisi clock/date/password, transparansi surface luar, dan password card.
6. Pastikan autentikasi dan session-lock tetap berfungsi.

Review visual dilakukan langsung oleh pengguna pada display X280. **Jangan meminta atau menggunakan screenshot.**

## Acceptance criteria

- Source tree lokal yang diharapkan benar-benar aktif.
- QML dimuat tanpa error kritis.
- Lock/unlock dan jalur autentikasi bekerja.
- Wake/resume tidak meninggalkan sesi terbuka atau state rusak.
- Password card terpisah dari outer surface dan layout sesuai desain yang disetujui.
- Tidak ada perubahan PAM atau kebijakan autentikasi yang tidak disetujui.
- Pengguna menyatakan tampilan/interaksi diterima.

## Rollback dan bukti

Gunakan backup/rollback yang disediakan installer. Catat versi/revision Caelestia, source path aktif, perintah, hasil runtime, skenario interaksi, isu, dan keputusan pengguna. Simpan laporan lokal; redaksi metadata sensitif sebelum dibagikan.

## Guest Mode

Guest Mode **NOT IMPLEMENTED / DEFERRED** dan bukan bagian dari acceptance lock screen. Spesifikasi konseptual terpisah ada di [03 — Guest Mode](03-GUEST-MODE.md). Jangan mengimplementasikan akun, session switch, storage, service, atau permission Guest sebelum lock screen diterima dan pengguna memberikan keputusan implementasi baru.
