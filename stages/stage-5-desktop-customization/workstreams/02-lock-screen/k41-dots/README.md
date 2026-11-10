# K41-Dots — Lock Screen

## Ownership

Direktori ini adalah source repository kanonis untuk empat override QML lock screen yang dimiliki K41. Source K41 dipisahkan dari source upstream Caelestia agar perubahan, review, dan deployment memiliki batas ownership yang jelas.

## Struktur source

```text
k41-dots/
└── modules/lock/
    ├── LockSurface.qml
    ├── Content.qml
    ├── Center.qml
    └── center/
        └── PasswordInput.qml
```

## Integrasi runtime

Installer menyalin file tersebut ke source tree Caelestia yang dipin:

`~/.config/quickshell/caelestia/modules/lock/`

File QML tetap menggunakan API Caelestia/Quickshell dan komponen upstream (`qs.*`, `Caelestia.Config`, objek layanan PAM, serta session-lock protocol). Artinya ini adalah komponen milik K41 yang terintegrasi dengan Caelestia, **bukan lock manager mandiri atau shell independen**.

Installer harus mempertahankan source upstream yang dipin, alur autentikasi, kebijakan PAM, kebijakan fingerprint/Howdy, dan session-lock protocol. Installer hanya mengganti empat override QML yang dikelola secara eksplisit setelah preflight dan backup.

## Kontrak desain

- Pertahankan wallpaper/screencopy background dan blur upstream.
- Buat outer lock surface transparan.
- Pertahankan password input sebagai surface rounded tersendiri.
- Posisikan clock, date, password input, dan state message sebagai satu kelompok yang terpusat.
- Pertahankan PAM serta keyboard/focus handling upstream.
- Jangan mengubah kebijakan autentikasi demi perubahan visual.

## Validasi

Jalankan test statis Stage 5:

```bash
bash stages/stage-5-desktop-customization/tests/test-lockscreen-design.sh
```

Jalankan audit Caelestia secara read-only sebagai user desktop biasa:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh
```

Audit membandingkan empat source kanonis dengan modul lock screen runtime Caelestia dan mencatat status `MATCH`, `MISMATCH`, atau `MISSING`. Audit tidak melakukan deployment, mengubah konfigurasi, me-restart shell, atau membuka kunci layar.

Pemuatan QML, lock/unlock, penanganan password salah, wake/resume, dan penerimaan visual tetap harus divalidasi pada X280.
