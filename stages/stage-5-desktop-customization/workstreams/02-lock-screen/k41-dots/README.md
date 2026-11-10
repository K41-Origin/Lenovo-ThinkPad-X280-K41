# K41-Dots — Lock Screen (Legacy Source Notes)

Dokumen ini mencatat source Lock Screen yang saat ini ada di repository. Struktur ini bersifat transisi dan akan dirapikan mengikuti arsitektur K41-Dots yang telah ditetapkan di [Project Architecture](../../../../../docs/01-PROJECT.md).

## Struktur runtime tujuan

Modul K41-Dots untuk lock screen akan berada di:

```text
~/.config/quickshell/k41/modules/lockscreen/
```

Source repository yang dituju berada pada struktur Stage 5 `quickshell/k41/modules/lockscreen/`. Script audit mengidentifikasi source, resource, konfigurasi, dependency, dan titik integrasi upstream yang diperlukan. Script penyiapan mengambil bagian yang relevan saja ke runtime K41.

## Kondisi saat ini

Empat override QML yang telah dibuat masih berada di:

```text
k41-dots/modules/lock/
├── LockSurface.qml
├── Content.qml
├── Center.qml
└── center/PasswordInput.qml
```

Installer lama menyalinnya ke `~/.config/quickshell/caelestia/modules/lock/`. Ini adalah mekanisme integrasi terdahulu dan **belum sama dengan modul K41-Dots pada namespace runtime `quickshell/k41/modules/lockscreen/`**.

Jangan menganggap path lama sebagai desain final atau menjalankan installer lama untuk melakukan migrasi. Source dan script akan ditata ulang setelah audit fitur dan dependency selesai.

## Dependency dan batas keamanan

Implementasi lama menggunakan API Caelestia/Quickshell, layanan PAM, dan session-lock protocol. Komponen upstream seperti `Lock.qml`, `Pam.qml`, `Clock.qml`, `InputField.qml`, dan `StateMessage.qml` pernah diidentifikasi sebagai dependency. Audit baru harus memverifikasi ulang dependency terhadap versi/revision upstream yang benar-benar digunakan.

- Jangan menyalin seluruh source Caelestia.
- Jangan menduplikasi dependency upstream tanpa kebutuhan.
- Jangan mengubah PAM, autentikasi, fingerprint policy, atau session-lock protocol untuk perubahan visual.
- Audit bersifat read-only; penyiapan modul dilakukan oleh script terpisah.
