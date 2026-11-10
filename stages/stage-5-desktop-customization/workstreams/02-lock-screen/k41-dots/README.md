# K41-dots — Lock Screen Visual Module

**Status: IMPLEMENTED (source extraction), NOT YET MIGRATED OR RUNTIME-VERIFIED.**

Desain yang dipertahankan adalah **Floating Password Card** yang sudah disetujui. Modul visual K41 sekarang memiliki namespace source sendiri: `modules/lockscreen/`.

Target runtime setelah script migrasi dibuat:

```text
~/.config/quickshell/k41/modules/lockscreen/
├── LockSurface.qml
├── Content.qml
├── Center.qml
└── center/
    └── PasswordInput.qml
```

## Batas ownership

- File dalam `modules/lockscreen/` adalah source visual yang dimiliki K41.
- Caelestia tetap menjadi host/runtime dan menyediakan API serta komponen upstream yang diimpor oleh modul.
- Modul mempertahankan kontrak `lock` dan API komponen Caelestia yang sudah digunakan source lama.
- Source ini belum dipasang dan belum dihubungkan ke runtime. Pembuatan script migrasi merupakan tahap berikutnya.
- Source lama di `modules/lock/` dipertahankan sementara sebagai pembanding/rollback. Jangan hapus sebelum migrasi berhasil dan hasil visual diterima.

## Komponen

| File | Tanggung jawab visual |
|---|---|
| `LockSurface.qml` | Wallpaper/screencopy background, blur, lock icon, komposisi permukaan dan transisi visual yang sudah ada |
| `Content.qml` | Mengisi area konten dengan komposisi K41 |
| `Center.qml` | Clock, tanggal, Floating Password Card, dan pesan status |
| `center/PasswordInput.qml` | Surface, radius, spacing, ikon, dan presentasi field input |

Komponen mempertahankan kontrak upstream yang ada. Tidak ada perubahan terhadap kebijakan autentikasi, PAM, password processing, fingerprint/Howdy policy, session-lock, atau cara lock dipanggil. File QML tetap menggunakan objek/service upstream yang diberikan Caelestia; K41 hanya mengambil ownership source tampilan.

## Dependency upstream yang dipertahankan

- Quickshell QtQuick dan Wayland session-lock surface.
- Caelestia Config/tokens, colors, animations, components, image components, time/wallpaper services.
- Komponen Caelestia `Clock`, `StateMessage`, `InputField`, `LoadingIndicator`, `MaterialIcon`, dan komponen UI terkait.
- `M3Shapes` yang sudah dipakai oleh field visual.

Daftar ini adalah dependency statis yang tampak pada source; kelengkapan dependency runtime tetap harus diuji pada instalasi Caelestia yang aktif.

## Bukan bagian dari tahap ini

- Script migrasi/deployment/rollback.
- Mengubah shell entrypoint atau konfigurasi lock runtime.
- Menghapus atau mengubah source Caelestia.
- Mengubah PAM, autentikasi, password handling, fingerprint/Howdy, session-lock policy, keybind, atau lock invocation.
- Mengklaim rendering/visual runtime sudah diverifikasi.

## Urutan berikutnya

1. Test statis tersedia di `stages/stage-5-desktop-customization/tests/test-lockscreen-visual-module.sh` dan sudah terdaftar pada `tests/run.sh`.
2. Buat script migrasi terpisah dengan preflight, backup, staging, validasi, atomic switch, dan rollback.
3. Jalankan CI untuk pemeriksaan statis.
4. Setelah migrasi/runtime terbukti dan diterima, lakukan audit dependency pascamigrasi.
5. Cleanup hanya source visual upstream yang terbukti tidak dipakai.

`LockSurface.qml` dan `center/PasswordInput.qml` mempertahankan kontrak upstream karena tampilannya dibangun di atas komponen runtime Caelestia. Jangan menganggap modul ini mandiri dari Caelestia.
