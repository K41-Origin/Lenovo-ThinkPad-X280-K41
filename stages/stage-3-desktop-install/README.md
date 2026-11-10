# Stage 3 — Desktop Installation

Dokumen ini adalah peta implementasi dan batas operasional Stage 3. Sumber kebenaran untuk perilaku aktual tetap script pada branch `main`; dokumen ini menjelaskan hubungan file, alur, efek samping, prasyarat, dan cakupan test tanpa mengubah implementasi.

## Tujuan dan batas tahap

Stage 3 memasang desktop dasar pada Arch Linux yang sudah terpasang di ThinkPad X280. Entry point kanonis dijalankan dari TTY sistem terpasang, sebagai user biasa melalui `sudo`.

Hasil yang disiapkan implementasi saat ini:
- Hyprland sebagai compositor Wayland;
- Quickshell, dengan pilihan paket resmi `quickshell` atau stack Caelestia berbasis AUR;
- PipeWire, WirePlumber, portal Wayland/GTK, polkit agent;
- utilitas desktop dasar, konfigurasi awal Hyprland, dan preferensi portal.

Stage 3 bukan instalasi Arch ke disk, bukan validasi fungsional desktop (Stage 4), dan bukan penerapan desain/customization (Stage 5). Keberhasilan script tidak membuktikan sesi grafis, seluruh perangkat, atau interaksi desktop bekerja dengan benar.

## Entry point dan alur pemanggilan

Jalankan hanya wrapper kanonis:

```bash
sudo bash stages/stage-3-desktop-install/scripts/k41-install-desktop.sh
```

Alur implementasi:

```text
stages/stage-3-desktop-install/scripts/k41-install-desktop.sh
  └── stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh
        └── stages/stage-3-desktop-install/lib/aur-dependency-resolver.sh  [source; hanya jika memilih Caelestia]
              ├── pacman -T / pacman -Si
              ├── git clone AUR package base
              ├── baca dan review PKGBUILD + .SRCINFO
              ├── makepkg --printsrcinfo (sebagai user biasa)
              └── makepkg --syncdeps --install (sebagai user biasa)
```

Wrapper adalah entry point, sedangkan `setup-desktop-x280.sh` memegang alur instalasi. Jangan menjalankan wrapper dan implementasi secara berurutan untuk pekerjaan yang sama.

## Peta kepemilikan file

| Path | Peran | Kepemilikan |
|---|---|---|
| `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh` | Entry point tipis yang meneruskan argumen ke implementasi | Khusus Stage 3 |
| `stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh` | Preflight, package transaction, konfigurasi awal, laporan, dan orchestration desktop | Khusus Stage 3 |
| `stages/stage-3-desktop-install/lib/aur-dependency-resolver.sh` | Resolver dependency AUR rekursif yang di-source oleh installer | Dependensi Stage 3 |
| `tests/test-desktop-setup.sh` | Static contract, syntax, dan fixture resolver untuk installer | Test global; tetap di `tests/` |
| `scripts/bootstrap-archiso.sh` | Source review lintas tahap; bukan launcher Stage 3 | Orchestrator Stage 1–2 |
| `stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh` | Pemeriksaan desktop setelah sesi berjalan | Stage 4; bukan bagian installer |
| `stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh` | Remediasi terbatas berdasarkan temuan validasi | Operasi desktop pasca-instalasi |
| `lib/desktop.sh` | Placeholder modul desktop generik | **PLANNED / UNUSED**; tidak dipanggil installer |

Script autologin, launcher TTY, Plymouth, lock-screen, dan customization berada pada workstream terpisah. Stage 3 secara eksplisit tidak mengaktifkan autologin atau display manager.

## Prasyarat dan safety gate

Installer memeriksa:
- proses berjalan sebagai root melalui `sudo` dan `SUDO_USER` menunjuk akun biasa yang sudah ada;
- akun desktop berada di grup `wheel`;
- sistem adalah Arch Linux terpasang (`/etc/arch-release` tersedia), arsitektur `x86_64`;
- tersedia TTY interaktif lokal;
- tidak dijalankan dari sesi grafis (`DISPLAY` dan `WAYLAND_DISPLAY` harus kosong);
- direktori konfigurasi Hyprland, Caelestia, dan preferensi portal target belum ada.

Jika konfigurasi target sudah ada, installer berhenti dan menolak overwrite. Jangan menghapus konfigurasi lama untuk melewati gate tanpa backup dan keputusan eksplisit.

Installer membuat direktori laporan privat sebelum sebagian besar preflight berjalan. Karena itu, kegagalan awal pun dapat menghasilkan laporan.

## Alur instalasi

1. Membuat direktori laporan unik di `reports/desktop/<UTC timestamp>/`, mode direktori 0700 dan file laporan 0600.
2. Menyimpan snapshot sistem dan daftar paket sebelum instalasi.
3. Meminta persetujuan untuk instalasi paket desktop.
4. Meminta pilihan terpisah untuk memasang Caelestia Shell.
5. Menjalankan `pacman -Syu --needed` untuk paket dari repository resmi yang dikonfigurasi.
6. Bila Caelestia dipilih, menyelesaikan dependency AUR dan memasang stack Caelestia.
7. Menulis konfigurasi awal Hyprland dan preferensi XDG portal secara atomik melalui temporary file.
8. Memastikan executable utama dan file konfigurasi tersedia, lalu mencatat snapshot paket setelah proses.
9. Menampilkan instruksi memulai sesi secara manual dari TTY.

### Paket dan pilihan Caelestia

Paket repository resmi yang diminta installer meliputi:
- `hyprland`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`;
- `pipewire`, `pipewire-audio`, `pipewire-pulse`, `wireplumber`;
- `polkit`, `hyprpolkitagent`, `hyprlock`;
- `wofi`, `foot`, `thunar`, `firefox`;
- utilitas screenshot/clipboard/brightness/media, XWayland, Mesa, Intel Vulkan, dan font.

Jika Caelestia tidak dipilih, installer menambahkan paket resmi `quickshell`.

Jika Caelestia dipilih, installer menambahkan build/runtime tools dan utilitas yang dinyatakan dalam array paket, kemudian meminta resolver memproses root package `quickshell-git`, `python-materialyoucolor3`, `caelestia-cli`, dan `caelestia-shell`.

**Keterbatasan integrasi Stage 3 → Stage 4:** validator Stage 4 saat ini mewajibkan package `quickshell-git`, `caelestia-shell`, dan `caelestia-cli`. Karena itu, pilihan memasang Quickshell resmi tanpa Caelestia tidak memenuhi kontrak package Stage 4 dan akan menghasilkan FAIL pada pemeriksaan package tersebut. Untuk alur proyek yang sekarang, pilih pemasangan Caelestia. Dukungan validator untuk jalur Quickshell-only belum diimplementasikan; lihat [Status proyek](../../docs/06-STATUS.md).

Daftar di atas mencerminkan source installer saat ini, bukan jaminan bahwa package repository/AUR akan selalu menyediakan versi atau dependency yang sama. Verifikasi transaksi aktual sebelum menyetujui perubahan.

### Batas keamanan AUR

Resolver:
- memeriksa dependency yang sudah terpasang dengan `pacman -T` dan package resmi yang tersedia dengan `pacman -Si`;
- meng-clone AUR package base yang belum tersedia dari repository resmi;
- memeriksa `.SRCINFO`, nama package/provider, dan dukungan `x86_64` atau `any`;
- membaca `depends` dan `makedepends` yang relevan, menyelesaikan dependency secara rekursif, serta mendeteksi siklus;
- menampilkan exact `PKGBUILD` dan `.SRCINFO` beserta commit checkout untuk review dan persetujuan satu per satu;
- menjalankan `makepkg --printsrcinfo` sebagai user biasa setelah persetujuan dan menolak build bila hasil metadata berbeda dari `.SRCINFO` yang direview;
- menjalankan build `makepkg --syncdeps --install` sebagai user biasa, bukan root.

AUR adalah sumber bergerak, bukan dependency yang dipin oleh proyek. Review setiap recipe dan metadata pada checkout aktual. Jangan menyetujui PKGBUILD secara otomatis atau menjalankan build AUR sebagai root.

## Efek samping dan yang tidak dilakukan

Installer dapat:
- memperbarui database/paket sistem melalui `pacman -Syu`;
- clone dan membangun AUR packages jika Caelestia dipilih;
- membuat konfigurasi awal di home akun desktop;
- membuat laporan lokal dan snapshot paket.

Installer menolak overwrite konfigurasi target yang sudah ada. Implementasi menyatakan secara eksplisit bahwa ia tidak:
- mempartisi, memformat, atau mengubah disk;
- mengubah bootloader atau kernel boot settings;
- mengaktifkan display manager atau autologin;
- mengubah firewall;
- mengaktifkan Bluetooth;
- mengonfigurasi hibernation;
- memulai sesi grafis secara otomatis.

Konfigurasi awal memasang autostart PipeWire/WirePlumber dan polkit agent di konfigurasi Hyprland. Caelestia ditambahkan sebagai autostart hanya bila opsi instalasinya dipilih.

Setelah selesai, keluar ke TTY, login sebagai user biasa, lalu jalankan `start-hyprland` secara manual. Installer tidak membuktikan bahwa sesi tersebut berhasil.

## Laporan dan kegagalan

Lokasi laporan: `reports/desktop/<UTC timestamp>/`.

Artefak yang dibuat:
- `setup.log`
- `system-info.txt`
- `packages-before.txt`
- `packages-after.txt`
- `summary.md`

Direktori laporan dibuat mode 0700 dan file mode 0600. Laporan dapat memuat hostname, metadata sistem, daftar paket, path, dan commit repository. Redaksi sebelum dibagikan.

Jika installer gagal:
1. baca `summary.md` dan `setup.log`;
2. periksa transaksi paket dan kondisi konfigurasi target;
3. jangan mengasumsikan rollback otomatis telah dilakukan;
4. jangan menghapus konfigurasi atau cache AUR secara membabi buta;
5. buat rencana pemulihan terpisah berdasarkan kondisi aktual.

Installer tidak menyediakan rollback transaksional atas package upgrade/installation. Penolakan atau kegagalan setelah sebagian transaksi dapat meninggalkan paket yang sudah terpasang.

## Test coverage

Test Stage 3 yang relevan:
- `tests/test-desktop-setup.sh` — syntax, keberadaan entry point/installer/resolver, delegasi wrapper, kontrak package dan safety, guard terhadap display manager/autologin, serta fixture parsing metadata AUR.
- `tests/test-bootstrap-archiso.sh` — pemeriksaan integrasi source-review dan kontrak wrapper desktop sebagai bagian dari bootstrap lintas tahap.
- `tests/run.sh` — manifest global; jalankan dari root dengan `bash tests/run.sh`.

Dua workflow CI aktif:
- `.github/workflows/ci.yml`: Bash syntax, ShellCheck `--severity=error` pada daftar script terpilih, dan suite test; trigger pull request serta push ke `main`, `feature/**`, dan `fix/**`.
- `.github/workflows/bash-tests.yml`: Bash syntax dan ShellCheck seluruh file shell, shfmt pada infrastruktur test/readiness terpilih, dan suite test; trigger pull request/push ke `main` serta manual.

Keduanya tumpang tindih pada perubahan `main` dan pull request ke `main`. Perbedaan trigger/cakupan dan alasan mempertahankan dua workflow dicatat di [Testing dan CI](../../docs/04-TESTING.md); jangan menghapus salah satunya sebelum required checks ditinjau.

Batas bukti:
- Fixture resolver bukan build AUR aktual.
- Static contract test bukan instalasi desktop penuh.
- CI bukan validasi sesi Hyprland pada ThinkPad X280.
- Tidak ada klaim uji fisik Stage 3 yang dibuat oleh dokumentasi ini.

## Handoff ke tahap berikutnya

Setelah installer selesai dan sesi Hyprland dimulai secara manual, lanjutkan ke Stage 4 melalui:

```bash
bash stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh
```

Validasi Stage 4 dijalankan sebagai user biasa di sesi Hyprland. Exit 0 dari Stage 3 tidak menggantikan gate Stage 4.

## Batas dokumentasi

Dokumen ini memetakan implementasi yang ada. Ia tidak mengubah paket, dependency, kebijakan AUR, konfigurasi desktop, atau prosedur runtime. Perubahan implementasi di masa depan harus memperbarui dokumen ini dan test terkait.

## Tests and reports

The Stage 3 contract test is `stages/stage-3-desktop-install/tests/test-desktop-setup.sh`. It is invoked through the canonical root `bash tests/run.sh` manifest. Desktop installation reports are written under `reports/stage-3-desktop-install/desktop/`.

## Stage-owned support scripts

Caelestia cache diagnostics and the narrowly scoped cache-permission repair are owned by Stage 3 and stored in `stages/stage-3-desktop-install/scripts/`. Root-level `scripts/fix-caelestia-cache-permissions-x280.sh` and `scripts/test-caelestia-permissions-x280.sh` remain compatibility symlinks.
