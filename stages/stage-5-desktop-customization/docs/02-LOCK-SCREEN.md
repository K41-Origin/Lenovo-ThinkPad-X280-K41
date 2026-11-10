# Workstream 02 — Lock Screen

**Status desain: COMPLETED / USER ACCEPTED.** Desain Floating Password Card telah diterima. Pemindahan source dan deployment ke struktur K41-Dots yang baru masih PLANNED.

## Tujuan dan desain

Menyesuaikan tampilan Caelestia lock screen sambil mempertahankan autentikasi upstream.

- Wallpaper dan efek blur upstream tetap menjadi latar.
- Outer lock surface transparan.
- Password input memiliki rounded surface tersendiri.
- Clock/date/password menjadi satu kelompok yang terpusat.
- PAM, password handling, fingerprint/Howdy policy, dan session-lock protocol tidak diubah untuk kosmetik.

Detail visual lintas-komponen: [Design System](../../../docs/07-DESKTOP-DESIGN-SYSTEM.md).

## K41-Dots: struktur yang dituju

Lock Screen menjadi modul K41 bernama `lockscreen`, bukan override yang tinggal di dalam namespace Caelestia.

Runtime tujuan:

```text
~/.config/quickshell/k41/modules/lockscreen/
```

Source repository untuk modul ini akan diselaraskan dengan struktur `quickshell/k41/modules/lockscreen/`. Audit harus lebih dahulu mengidentifikasi file QML, resource, konfigurasi, dependency upstream, dan titik integrasi lock screen yang benar-benar diperlukan. Script penyiapan kemudian mengambil bagian yang diperlukan ke modul K41; dependency upstream yang masih dipakai tetap dicatat dan tidak diduplikasi tanpa alasan.

## Kondisi repository saat ini

Implementasi lama masih berada di:
- Source: `workstreams/02-lock-screen/k41-dots/modules/lock/`
- Installer lama: `workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh`
- Target lama: `~/.config/quickshell/caelestia/modules/lock/`

Path dan installer tersebut adalah kondisi transisi, **bukan struktur K41-Dots yang dituju**. Jangan menjalankan installer lama sebagai langkah migrasi ke struktur baru. Source, audit, script penyiapan, dan test akan disesuaikan setelah audit fitur selesai.

## Audit dan dependency

Audit Caelestia saat ini:
`stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh`

Audit khusus lock screen yang sudah ada:
- `workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-session.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-failure.sh`
- `workstreams/02-lock-screen/scripts/k41-report-lockscreen-permissions.sh`

Audit berikutnya perlu disederhanakan agar fokus mengumpulkan source dan dependency yang terkait fitur lock screen, bukan membangun inventory shell yang luas. Audit bersifat read-only.

## Acceptance

Penerimaan desain sebelumnya tetap berlaku untuk tampilan yang diserahkan. Setelah migrasi modul, verifikasi ulang:
- Modul ditempatkan pada namespace K41 yang benar.
- Dependency upstream yang diperlukan tersedia.
- QML dimuat tanpa error kritis.
- Lock/unlock, password salah, dan wake/resume bekerja.
- PAM dan session-lock protocol tetap tidak berubah.
- Pengguna menerima hasil pada X280.

Jangan mengklaim runtime baru sudah diverifikasi sebelum pengujian perangkat benar-benar dilakukan. Screenshot bukan acceptance gate.

## Guest Mode

Guest Mode **NOT IMPLEMENTED / DEFERRED** dan bukan bagian dari acceptance lock screen.
