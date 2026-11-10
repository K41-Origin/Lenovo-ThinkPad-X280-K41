# Stage 5 — Lock Screen Visual Module

**Status: IMPLEMENTED (source placement), NOT YET MIGRATED OR RUNTIME-VERIFIED.**

Desain yang dipertahankan adalah **Floating Password Card** yang telah disetujui. Source visual K41 ditempatkan langsung di workstream Stage 5 ini, bukan di project/folder terpisah.

```text
workstreams/02-lock-screen/modules/lockscreen/
├── LockSurface.qml
├── Content.qml
├── Center.qml
└── center/
    └── PasswordInput.qml
```

## Batas ownership

- Folder ini adalah source visual Lock Screen yang dikelola langsung oleh Stage 5.
- Caelestia tetap menjadi host/runtime dan menyediakan API serta komponen upstream yang diimpor modul.
- Source mempertahankan kontrak `lock` dan API komponen Caelestia yang telah digunakan implementasi visual sebelumnya.
- Source belum dipasang atau dihubungkan ke runtime. Script migrasi dibuat pada tahap berikutnya.
- Jangan mengubah desain yang disetujui tanpa persetujuan.

## Komponen visual

| File | Tanggung jawab |
|---|---|
| `LockSurface.qml` | Wallpaper/screencopy background, blur, lock icon, dan transisi visual |
| `Content.qml` | Komposisi konten Lock Screen |
| `Center.qml` | Clock, tanggal, Floating Password Card, dan pesan status |
| `center/PasswordInput.qml` | Surface, radius, spacing, ikon, dan presentasi field |

## Batas scope

Pekerjaan ini hanya mengambil ownership source tampilan. Tidak ada perubahan terhadap autentikasi, PAM, password processing, fingerprint/Howdy policy, session-lock policy/protocol, keybind, atau cara Lock Screen dipanggil.

## Dependency

Modul memakai komponen dan API visual/runtime Caelestia yang sudah ada, termasuk Config/tokens, colors, animations, Clock, StateMessage, InputField, LoadingIndicator, MaterialIcon, wallpaper/image services, serta M3Shapes. Dependency runtime final harus diperiksa setelah migrasi.

## Status berikutnya

1. Buat script migrasi dengan preflight, backup, staging, validasi, atomic switch, dan rollback.
2. Uji pemeriksaan statis melalui CI.
3. Verifikasi runtime pada target sebelum cleanup dependency visual upstream.
4. Cleanup hanya source visual upstream yang terbukti tidak lagi dipakai.

Tidak ada klaim runtime rendering atau penerimaan perangkat pada tahap ini.
