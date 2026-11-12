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

## Audit visual dan diagnosis preflight

Sebelum deployment, jalankan audit dari checkout repository sebagai user desktop biasa:

```bash
bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh
```

Laporan dibuat di `reports/lockscreen-visual-audit/<timestamp>/lockscreen-visual-audit.log`. Selain inventaris QML dan dependency visual, audit kini memuat diagnosis empat target deployment (`LockSurface.qml`, `Content.qml`, `Center.qml`, dan `center/PasswordInput.qml`): origin dan HEAD Caelestia, status checkout, status Git per file, keberadaan/symlink/owner/mode/ukuran/checksum file terpasang dan source K41, checksum blob dari revision upstream yang dipin, hasil kesetaraan, serta unified diff antara file terpasang dengan pinned upstream dan source K41.

Bagian **DEPLOYMENT PREFLIGHT DIAGNOSTICS** ditujukan untuk mengidentifikasi apakah file yang ditolak deployment merupakan modifikasi lokal, masih versi upstream, sudah sama dengan source K41, atau tidak dapat dibandingkan. Audit bersifat read-only selain membuat laporan. Periksa dan redaksi laporan sebelum dibagikan karena laporan juga memuat source QML, path lokal, dan metadata host.

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
5. Mengganti empat file overlay di `~/.config/quickshell/caelestia/modules/lock/`.
6. Menyalin empat file yang sama ke `~/.config/quickshell/k41/modules/lockscreen/` dan `~/.config/quickshell/caelestia/k41/modules/lockscreen/`.
7. Memverifikasi ketiga set file dan menjalankan `caelestia shell -r -d` untuk memuat ulang shell.\n8. Menyimpan log privat di `~/.local/state/k41/lockscreen/deployment-logs/`; publikasi log yang telah disanitasi memakai clone sementara independen sehingga tidak mengubah branch, index, `FETCH_HEAD`, atau metadata worktree checkout pengguna. Kegagalan publikasi hanya menghasilkan peringatan dan tidak mengubah hasil deployment.

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
