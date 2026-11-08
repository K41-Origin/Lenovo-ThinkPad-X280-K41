# Proyek dan Arsitektur

## Tujuan dan cakupan
Membangun instalasi Arch Linux modular, aman, reproducible, dan testable untuk ThinkPad X280. Desktop: Hyprland, Caelestia Shell, Quickshell sesuai dependensi upstream. Installer Arch dan setup desktop pasca-instalasi adalah workflow terpisah. BlackArch opsional dan selektif.

## Keputusan
- Login manual dari TTY lalu `start-hyprland`; tanpa display manager/autologin.
- Jangan menambah autostart Caelestia duplikat.
- NetworkManager untuk jaringan; hindari power manager bersaing karena PPD telah terdeteksi aktif.
- Review AUR recipe dan build sebagai user non-root.
- Hardware, thermal, power/battery, suspend/resume, dan stability adalah tahap terakhir.

## Urutan tahap
1. **Desktop Functional Validation** — sesi, input, display, audio, jaringan, portal, lock, recovery.
2. **Desktop Customization** — minimal, elegan, premium, monochromatic dengan kontras baik.
3. **Optional Software Integration** — hanya komponen yang dipilih eksplisit.
4. **Final Hardware & System Customization** — CPU/GPU, thermal, power, battery, suspend/hibernate/resume, stability.

Jangan lanjut sebelum acceptance tahap aktif disetujui.

## Arsitektur
`installer`/`scripts/`: workflow; `lib/`: modul; `config/`: target; `tests/`: pengujian; `reports/`: bukti; `docs/`: dokumen aktif dan arsip.

Status: **PLANNED** belum dibuat; **IMPLEMENTED** tersedia; **TESTED** test dijalankan; **VERIFIED** bukti mengonfirmasi; **RELEASED** masuk rilis; **NOT TESTED** belum diuji.
