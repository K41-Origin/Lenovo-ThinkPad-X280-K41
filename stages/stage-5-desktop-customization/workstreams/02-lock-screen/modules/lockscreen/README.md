# Stage 5 — Lock Screen Visual Module

**Status: IMPLEMENTED (source placement and user-local deployment script), HOST INTEGRATION / RUNTIME NOT VERIFIED.**

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
- Script deployment tersedia di `workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh`; script menyalin modul ke namespace K41 dengan backup, staging, checksum, idempotency, dan rollback.
- Deployment file tidak sama dengan aktivasi: integrasi ke entrypoint Caelestia sengaja belum diubah karena titik integrasi host belum diverifikasi.
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

1. **Deployment source — IMPLEMENTED.** Jalankan script `workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh --install` sebagai user biasa (tanpa sudo) untuk menyalin empat file visual ke `~/.config/quickshell/k41/modules/lockscreen/`.
2. **Static/isolated test — IMPLEMENTED.** Test `stages/stage-5-desktop-customization/tests/test-lockscreen-visual-deploy.sh` mencakup syntax, install di HOME sementara, checksum, idempotency, status, rollback, dan proteksi target unmanaged.
3. **Host integration — BLOCKED / NOT VERIFIED.** Script deployment tidak mengedit `caelestia/shell.qml`. Titik import/integrasi yang didukung harus diverifikasi terhadap host Caelestia yang benar-benar terpasang sebelum modul diaktifkan.
4. Verifikasi runtime pada target sebelum cleanup dependency visual upstream.
5. Cleanup hanya source visual upstream yang terbukti tidak lagi dipakai.

### Deploy pada laptop

Dari root checkout repository, jalankan sebagai user desktop biasa:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh --install
```

Periksa status dengan `--status`. Script mencetak lokasi backup untuk rollback. Jangan gunakan installer lama `k41-apply-lockscreen-design.sh`.

Deployment hanya menyalin file visual. Quickshell belum diarahkan untuk memuat modul ini sampai host integration Caelestia diverifikasi.

Tidak ada klaim runtime rendering atau penerimaan perangkat pada tahap ini.
