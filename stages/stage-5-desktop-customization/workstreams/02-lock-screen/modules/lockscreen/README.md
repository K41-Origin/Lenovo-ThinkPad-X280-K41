# Stage 5 — Lock Screen Visual Module

**Status source: IMPLEMENTED. Deployment/reload script: IMPLEMENTED. Runtime rendering: NOT VERIFIED on the ThinkPad X280.**

Desain yang dipertahankan adalah **Floating Password Card** yang telah disetujui. Empat file QML visual dikelola langsung oleh workstream Stage 5 ini.

```text
modules/lockscreen/
├── LockSurface.qml
├── Content.qml
├── Center.qml
└── center/
    └── PasswordInput.qml
```

## Deployment dan aktivasi

Satu script melakukan seluruh langkah deployment dan reload Caelestia. Tidak ada opsi `--install`, `--status`, atau `--rollback`.

Dari root checkout repository, jalankan sebagai user desktop biasa di sesi Hyprland aktif:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh
```

Script:
1. Memastikan sesi Wayland/Hyprland aktif.
2. Memastikan checkout Caelestia user-local tersedia di `~/.config/quickshell/caelestia`, berasal dari upstream yang diaudit, dan berada pada revision yang dipin.
3. Memastikan empat file target masih versi upstream asli atau sudah sama dengan source K41. Modifikasi lokal lain ditolak.
4. Membuat backup bertimestamp dari empat file visual.
5. Mengganti empat file di `~/.config/quickshell/caelestia/modules/lock/` dengan source Stage 5.
6. Memverifikasi hasil dengan checksum/perbandingan file.
7. Menjalankan `caelestia shell -r -d` untuk memuat ulang shell.\n8. Menyimpan log privat di `~/.local/state/k41/lockscreen/deployment-logs/`; publikasi log yang telah disanitasi memakai clone sementara independen sehingga tidak mengubah branch, index, `FETCH_HEAD`, atau metadata worktree checkout pengguna. Kegagalan publikasi hanya menghasilkan peringatan dan tidak mengubah hasil deployment.

Tidak perlu sudo. Script tidak membuat partial config overlay, tidak mengubah `shell.qml`, `Lock.qml`, `Pam.qml`, `InputField.qml`, PAM/authentication, session-lock protocol, Hyprland, maupun system services. Jika preflight tidak cocok, script berhenti tanpa menimpa file. Jika penyalinan atau reload gagal, empat file awal dipulihkan otomatis dari backup. Kegagalan publikasi log tidak membatalkan atau mengubah status deployment; log lokal tetap tersedia.

## Ownership dan dependency

- Folder ini adalah source visual K41 yang dikelola Stage 5.
- Caelestia tetap menjadi host/runtime dan menyediakan API serta komponen visual/runtime upstream.
- File K41 mempertahankan kontrak `lock` dan API komponen Caelestia yang sudah digunakan source.
- Hanya `LockSurface.qml`, `Content.qml`, `Center.qml`, dan `center/PasswordInput.qml` yang diganti.
- Autentikasi, PAM, password handling, fingerprint/Howdy policy, dan session-lock policy/protocol berada di luar scope visual.

## Komponen visual

| File | Tanggung jawab |
|---|---|
| `LockSurface.qml` | Background wallpaper/screencopy, blur, surface, dan transisi visual |
| `Content.qml` | Komposisi konten Lock Screen |
| `Center.qml` | Clock, tanggal, Floating Password Card, dan pesan status |
| `center/PasswordInput.qml` | Surface, radius, spacing, ikon, dan presentasi field |

## Status validasi

- Source QML dan kontrak visual: **IMPLEMENTED**.
- Deployment otomatis dan pemanggilan reload: **IMPLEMENTED**.
- Test fixture terisolasi: memeriksa provenance guard, backup, penggantian empat file, dan pemanggilan reload.
- QML runtime rendering, lock/unlock, password salah, wake/resume, dan penerimaan visual di ThinkPad X280: **NOT VERIFIED** sampai ada bukti dari perangkat aktual.
- Cleanup dependency visual upstream: **BELUM DILAKUKAN**; tunggu penerimaan runtime.
