# K41 Obsidian Minimalism — Desktop Design Specification

## Status and purpose

- **Project:** Lenovo ThinkPad X280 K41
- **Stage:** 5 — Desktop Environment Customization
- **Design status:** APPROVED DIRECTION; Hyprland/Fuzzel foundation applied; Caelestia Graphite typography and monochrome scheme applied with runtime restart/log verified; remaining Stage 5 components pending
- **Specification version:** 1.0
- **Last updated:** 2026-11-09

Dokumen ini adalah patokan visual dan teknis untuk seluruh pekerjaan customization desktop tahap 5. Implementasi harus mengikuti prinsip dan acceptance criteria di sini. Perubahan arah desain yang material harus dibahas dan disetujui sebelum diterapkan.

## 1. Design vision

**K41 Obsidian Minimalism** adalah desktop modern, minimalis, monochromatic, elegan, dan premium.

Prinsip utama: **less elements, better details**.

Desktop harus terasa tenang dan bersih ketika tidak digunakan. Informasi dan kontrol ditampilkan ketika relevan, bukan memenuhi layar dengan widget atau dekorasi. Kesan premium dibangun melalui komposisi, tipografi, kontras, spacing, konsistensi, dan detail yang rapi—bukan efek visual berat.

### Design principles

1. Minimal, bukan kosong atau sulit digunakan.
2. Monochromatic, bukan kontras rendah.
3. Elegan dan konsisten, bukan dekoratif atau ramai.
4. Informasi penting mudah ditemukan dan dibaca.
5. Interaksi keyboard tetap cepat dan dapat diprediksi.
6. Performa dan stabilitas lebih penting daripada efek visual.
7. Gunakan fitur upstream yang didukung sebelum membuat pengganti sendiri.

## 2. Visual identity and color tokens

Arah warna yang disetujui: **Graphite Monochrome**.

| Token | Nama | Nilai awal | Penggunaan |
|---|---|---|---|
| `color.background` | Deep Black | `#0A0A0B` | Wallpaper gelap dan latar utama |
| `color.surface` | Dark Graphite | `#141416` | Panel dan permukaan utama |
| `color.surface.elevated` | Charcoal | `#1C1C20` | Popover, menu, dan elemen elevated |
| `color.border` | Dark Gray | `#29292E` | Border dan separator |
| `color.text.primary` | Off White | `#F2F2F0` | Teks utama |
| `color.text.secondary` | Soft Gray | `#A1A1A6` | Teks sekunder |
| `color.text.muted` | Dim Gray | `#68686F` | Metadata dan teks non-esensial |
| `color.accent` | Silver | `#C4C4C9` | Aksen dan state aktif secara terbatas |

Nilai ini adalah design tokens awal, bukan klaim bahwa seluruh kombinasi telah lulus pengujian kontras. Sebelum implementasi final, periksa kontras teks, status fokus, disabled state, dan indikator penting. Sesuaikan nilai bila diperlukan untuk keterbacaan dan aksesibilitas tanpa mengubah identitas Graphite Monochrome.

Warna semantik untuk error, warning, success, dan status kritis boleh digunakan secara terbatas ketika warna diperlukan untuk menyampaikan makna. Jangan memaksa seluruh informasi status menjadi abu-abu jika itu mengurangi kejelasan.

## 3. Typography and iconography

### Typography direction

Kandidat awal:
- **Inter** — antarmuka, label, dan teks umum.
- **JetBrains Mono** — terminal dan informasi teknis.
- **Noto Sans** — fallback bila dibutuhkan untuk cakupan karakter.

Pemilihan final bergantung pada ketersediaan paket, rendering aktual, keterbacaan pada display X280, dan jumlah font yang benar-benar diperlukan. Hindari memasang banyak keluarga font atau weight yang tidak digunakan.

### Typography rules

- Gunakan hirarki ukuran dan weight yang konsisten.
- Prioritaskan keterbacaan pada resolusi 1920×1080 dengan scaling yang terdeteksi 1.5.
- Jangan membuat teks metadata terlalu kecil atau terlalu redup.
- Gunakan monospace hanya untuk data teknis yang memang diuntungkan olehnya.

### Iconography

- Gunakan satu gaya icon yang konsisten.
- Hindari mencampur banyak icon pack.
- Pilih simbol yang jelas dan mudah dikenali.
- Status penting tidak boleh bergantung pada warna atau ikon saja.

## 4. Layout, surfaces, and motion

- Panel dibuat tipis dan ringkas.
- Gunakan spacing yang konsisten dan whitespace yang cukup.
- Radius sudut digunakan secara konsisten; hindari bentuk terlalu bulat yang tidak sesuai dengan karakter desain.
- Border halus lebih diutamakan daripada shadow tebal.
- Transparansi hanya digunakan bila meningkatkan hierarki visual.
- Blur harus minimal dan hanya jika hasilnya tetap responsif.
- Animasi harus singkat, subtle, dan memiliki tujuan fungsional.
- Hindari animasi dekoratif terus-menerus, parallax, dan efek yang tidak menambah kejelasan.

Nilai awal gaps, radius, border, dan efek compositor ditetapkan konservatif berdasarkan audit konfigurasi aktif. Nilai tersebut merupakan starting point dan dapat disesuaikan setelah pengguna menilai tampilan langsung pada perangkat. Jangan menebak atau menyalin angka sebelum mengetahui konfigurasi dan perilaku upstream yang berlaku.

## 5. Wallpaper direction

Wallpaper utama menggunakan abstract monochrome:
- Dominasi hitam, graphite, dan charcoal.
- Geometri atau bentuk abstrak yang sederhana.
- Gradient sangat halus bila diperlukan.
- Komposisi tenang dengan ruang visual yang cukup.
- Tidak bersaing dengan panel, teks, atau jendela.

Wallpaper alternatif boleh tersedia, tetapi harus tetap berada dalam keluarga visual yang sama. Hindari foto atau ilustrasi ramai sebagai default.

## 6. Desktop components and behavior

| Komponen | Arah customization | Prinsip |
|---|---|---|
| Caelestia panel | Ringkas, graphite, indikator jelas | Pusat kontrol desktop |
| Launcher | Satu launcher utama, keyboard-first | Cepat dan minim distraksi |
| Dashboard | Muncul sesuai kebutuhan | Tidak selalu memenuhi desktop |
| Clock/calendar | Tipografi bersih, informasi secukupnya | Mudah dipindai |
| System widgets | CPU, RAM, baterai, jaringan bila berguna | Polling hemat dan tidak redundan |
| Notifications | Hierarki jelas, ukuran terkendali | Tidak mengganggu secara berlebihan |
| Audio/brightness | Kontrol sederhana dan konsisten | Memanfaatkan integrasi yang tersedia |
| Media | Informasi dan kontrol seperlunya | Tidak membuat service duplikat |
| Lock screen | Gelap, jam/tanggal jelas, prompt sederhana | Pertahankan Hyprlock/integrasi yang bekerja |
| Terminal | Graphite, teks kontras, monospace | Pertahankan Foot |
| GTK/Qt apps | Tampilan sedekat mungkin dengan design tokens | Konsistensi tanpa patch rapuh |

### Caelestia and Quickshell strategy

Caelestia tetap menjadi fondasi utama shell dan Quickshell menjadi framework runtime sesuai stack yang telah terpasang. Prioritaskan opsi konfigurasi dan theming resmi/upstream. Custom widget hanya ditambahkan jika ada kebutuhan nyata yang belum terpenuhi.

Jangan mengganti Caelestia dengan shell buatan sendiri atau membuat ulang fitur yang sudah tersedia tanpa alasan teknis yang kuat. Hindari dua launcher atau dua komponen yang memiliki fungsi tumpang tindih.

### Hyprland appearance

Customization mencakup window border, gaps, radius, active/inactive state, workspace presentation, floating behavior, dan animasi. Perubahan visual tidak boleh merusak keybind, window rules, monitor layout, input, atau perilaku sesi yang sudah berfungsi.

## 7. Performance and reliability constraints

Target perangkat memiliki Intel UHD Graphics 620 dan panel internal 1920×1080 yang terdeteksi berjalan pada 60 Hz, scaling 1.5. Karena itu:

- Hindari blur besar atau berlapis.
- Hindari shadow kompleks dan transparansi berlebihan.
- Hindari widget dengan polling agresif.
- Hindari proses latar belakang dan daemon duplikat.
- Hindari dependency tambahan tanpa kebutuhan yang jelas.
- Jangan menambah animasi yang terus berjalan tanpa manfaat.
- Pertahankan fungsi desktop, audio, portal, jaringan, input, lock screen, dan recovery path.

Tidak ada klaim angka penggunaan RAM/CPU atau dampak performa sebelum baseline dan pengukuran setelah perubahan dikumpulkan. Pengukuran dilakukan dengan metode dan kondisi yang sebanding.

## 8. Configuration and repository strategy

Semua konfigurasi yang dikelola proyek harus reproducible, modular, dan dapat di-rollback. Struktur final ditetapkan setelah audit konfigurasi aktif.

Arah pengelolaan:
- Pisahkan konfigurasi Hyprland, Caelestia/Quickshell, terminal, GTK/Qt, dan aset.
- Simpan design tokens di satu sumber yang sesuai dengan kemampuan konfigurasi upstream.
- Hindari nilai warna, spacing, dan radius yang diduplikasi tanpa alasan.
- Jangan menimpa konfigurasi pengguna atau file upstream secara membabi buta.
- Backup sebelum perubahan; sediakan rollback yang terdokumentasi.
- Jangan memasukkan cache, log privat, atau data runtime ke konfigurasi yang dikomit.
- Jangan mengasumsikan path konfigurasi final sebelum audit selesai.

## 9. Scope and exclusions

### In scope — Stage 5

- Art direction dan design tokens.
- Wallpaper dan typography.
- Icon/cursor direction.
- Caelestia panel, launcher, dashboard, widgets, dan notifications.
- Hyprland visual appearance.
- Lock screen appearance.
- Foot terminal appearance.
- GTK/Qt consistency where maintainable.
- On-device visual review by the user, functional regression, and rollback; screenshots are not required.

### Out of scope — Stage 5

- CPU/GPU tuning.
- Thermal/fan tuning.
- Battery and power policy optimization.
- Suspend/hibernate/resume optimization campaign.
- Major changes to kernel, firmware, or system services.
- Replacing the desktop shell architecture.

Pekerjaan tersebut berada pada tahap 6 atau memerlukan keputusan arsitektur terpisah.

## 10. Audit findings — 2026-11-09

Audit terbaru berasal dari `reports/desktop-customization-audit/20261109T084605Z/` pada commit `73158954b132ad43f3830b10e414df41ab6c8f6d`.

### Hyprland configuration source

- Perangkat menjalankan Hyprland **0.57.1**.
- Pada Hyprland 0.57+, konfigurasi utama menggunakan Lua; path default adalah `~/.config/hypr/hyprland.lua`.
- Runtime option values cocok dengan `hyprland.lua`: `gaps_in=5`, `gaps_out=20`, `border_size=2`, `rounding=10`, `active_opacity=1.0`, `inactive_opacity=1.0`, blur enabled, animations enabled.
- `~/.config/hypr/hyprland.conf` berisi nilai lama yang berbeda dan merupakan konfigurasi legacy yang tidak dipakai oleh Hyprland 0.57.1. Jangan jadikan file `.conf` sebagai target customization.
- `hyprland.lua` tampak sebagai upstream autogenerated example config. Pertahankan seluruh keybind, device, workspace, dan window-rule behavior saat mengubah bagian visual.
- `hyprland.lua` menetapkan `misc.force_default_wallpaper=-1` dan `misc.disable_hyprland_logo=false`; wallpaper internal/default Hyprland perlu ditangani melalui opsi compositor, bukan diasumsikan berasal dari daemon wallpaper eksternal.
- `hyprctl configerrors` tidak melaporkan error pada snapshot audit.

### Shell, launcher, and appearance

- Audit terbaru (`reports/caelestia-audit/20261109T091310Z/`) mengonfirmasi Caelestia Shell 2.5.0-1, CLI 1.1.3-1, dan Quickshell 0.3.2 aktif (`qs -c caelestia -n -d`).
- `shell.json` valid dan hanya memiliki konfigurasi `bar` serta `dashboard`; `shell-tokens.json` tidak ada.
- Rubik, CaskaydiaCove Nerd Font, dan Material Symbols Rounded terdeteksi tersedia. Inter/JetBrains Mono tidak diperlukan untuk profil ini.
- Launcher variable di `hyprland.lua` mengarah ke `hyprlauncher`; executable availability belum diverifikasi. Wofi dan Fuzzel terpasang, tetapi belum ada proses launcher aktif pada saat audit.
- Fuzzel config berisi dua blok `[colors]` dan nilai tema lama teal serta tema sebelumnya. File perlu dirapikan setelah launcher utama ditetapkan.
- Rubik dan CaskaydiaCove Nerd Font tersedia. Inter dan JetBrains Mono tidak tersedia pada hasil `fc-match` dan fallback masing-masing adalah Noto Sans serta Noto Sans Mono.
- GTK3 dan Thunar memiliki custom CSS bernuansa teal; GTK/Thunar perlu dipetakan sebelum token Graphite diterapkan.
- Tidak ditemukan proses `swww`, `hyprpaper`, `mpvpaper`, atau `swaybg`. Karena Hyprland dikonfigurasi memakai default wallpaper/logo internal, tidak ada dasar untuk memasang daemon wallpaper baru sebelum tampilan baseline diperiksa.

### Performance snapshot — not a benchmark

- RAM total 7.5 GiB; RAM available 6.0 GiB; swap terpakai 0 pada snapshot.
- Quickshell menggunakan sekitar 12.3% RAM dan Hyprland sekitar 3.3% RAM pada satu pengambilan.
- Nilai CPU tidak digunakan sebagai baseline karena proses `ps` milik audit sendiri tampil sebagai proses CPU tertinggi. Pengukuran komparatif perlu dilakukan setelah baseline visual dan dengan metode yang tidak mengukur collector itu sendiri.

### Status setelah audit dan batch Caelestia pertama diterapkan

- Hyprland/Fuzzel apply sukses pada run `20261109T090739Z`; pengguna mengonfirmasi `SUPER + R` berfungsi.
- Audit Caelestia read-only selesai pada run `20261109T091310Z`; konfigurasi valid dan runtime aktif.
- Profil tipografi Graphite dan scheme upstream `caelestia/dark/monochrome` telah diterapkan pada perangkat.
- Laporan `reports/caelestia-customization/20261109T093038Z/`: SUCCESS; restart CONFIRMED; runtime log OK; 3 entri Configuration Loaded; 1 proses Quickshell teramati; 0 WARN, 0 ERROR, 0 FATAL.
- `shell-tokens.json` tetap tidak dibuat karena upstream menandai token internal sebagai advanced/unstable.
- Visual review, wallpaper, icon/cursor, Foot, GTK/Thunar, Qt, dan lock screen masih PENDING.
- Audit GTK menunjukkan CSS GTK3/GTK4 dan Thunar masih memakai aksen teal lama; icon theme Adwaita tersedia; cursor theme saat audit masih `default`; tidak ada wallpaper daemon aktif. Tidak ada daemon wallpaper baru yang perlu dipasang sebelum memakai integrasi wallpaper Caelestia/upstream.
- Jangan menghapus `hyprland.conf` secara otomatis; perlakukan sebagai file legacy yang tidak aktif.

## 11. Implementation workflow

1. Audit konfigurasi aktif Hyprland, Caelestia, Quickshell, GTK, Qt, fonts, icons, cursor, dan wallpaper.
2. Petakan konfigurasi upstream versus konfigurasi pengguna.
3. Tetapkan design tokens dan struktur konfigurasi.
4. Backup konfigurasi serta siapkan rollback.
5. Implementasikan perubahan kecil per komponen.
6. Validasi syntax/configuration dan runtime setelah setiap kelompok perubahan.
7. Periksa regresi fungsi desktop dan dampak performa.
8. Pengguna menilai tampilan langsung pada perangkat X280; screenshot tidak diwajibkan.
9. Catat hasil, isu tersisa, dan keputusan penerimaan.

Jangan melakukan bulk rewrite sebelum langkah audit dan desain selesai.

## 12. Acceptance criteria

Tahap 5 dapat diterima jika:

- [ ] Identitas Graphite Monochrome konsisten di seluruh komponen utama.
- [ ] Teks, ikon, focus state, dan indikator status mudah dibaca.
- [ ] Panel dan launcher ringkas serta mudah digunakan dengan keyboard.
- [ ] Dashboard dan widget tidak memenuhi desktop tanpa kebutuhan.
- [ ] Wallpaper mendukung, bukan mengganggu, konten.
- [ ] Caelestia dan Hyprland berjalan tanpa regresi konfigurasi/runtime baru yang kritis.
- [ ] Audio, brightness, media, notification, lock screen, portal, dan interaksi utama tetap berfungsi sesuai cakupan perangkat.
- [ ] Tidak ada service, launcher, atau widget duplikat yang tidak diperlukan.
- [ ] Pengguna telah menilai tampilan langsung pada display fisik X280.
- [ ] Performa dibandingkan dengan baseline dalam kondisi yang sebanding; tidak ada regresi yang tidak dapat diterima.
- [ ] Backup dan rollback telah diuji atau setidaknya langkah pemulihannya diverifikasi.
- [ ] Dokumentasi dan bukti pengujian diperbarui.

Automated validation saja tidak cukup untuk menyatakan visual acceptance. Persetujuan visual akhir memerlukan review pengguna pada perangkat.

## 12A. First implementation — repository state

Committed implementation files:
- `config/desktop-customization/palette.json` — canonical Graphite Monochrome tokens.
- `config/desktop-customization/hyprland-appearance.lua` — low-cost visual overlay.
- `config/desktop-customization/fuzzel.ini` — single-block Fuzzel palette and layout.
- `scripts/k41-apply-desktop-customization.sh` — guarded apply and explicit rollback workflow.

The apply script modifies only the active Hyprland Lua file and Fuzzel config. It backs up both before writing. It changes the audited launcher declaration from missing `hyprlauncher` to installed `fuzzel`, appends an appearance-only block, disables compositor blur to limit GPU cost, and disables the default Hyprland logo/wallpaper behavior. It does not rewrite keybinds, input, monitor layout, workspace rules, window rules, or autostart.

**Validation status:** repository files committed. The user ran the apply script successfully (report `20261109T090739Z`) and confirmed `SUPER + R` works. This verifies the launcher path only; no claim is made that all appearance settings or the full desktop are visually accepted.

## 13. Decision log

Keputusan yang telah disetujui:
- Nama arah desain: **K41 Obsidian Minimalism**.
- Palet: **Graphite Monochrome**.
- Karakter: modern, minimalis, monoton/monochromatic, elegan, premium.
- Shell utama: Caelestia.
- Runtime shell: Quickshell.
- Compositor: Hyprland.
- Typography candidates: Inter dan JetBrains Mono; Noto Sans sebagai fallback bila diperlukan.
- Wallpaper: abstract monochrome.
- Launcher: Fuzzel sebagai satu launcher utama (pengguna telah mengonfirmasi `SUPER + R` berfungsi).
- Dashboard: sesuai kebutuhan, bukan selalu tampil.
- Motion: subtle.
- Transparency: selective.
- Blur: minimal.
- Performance: prioritas tinggi; hindari efek dan polling yang tidak perlu.
- Tahap 5 tidak mencakup optimasi hardware tahap 6.

Hal yang belum diputuskan dan harus diverifikasi:
- Mekanisme override Caelestia/Quickshell dan opsi theming upstream yang tepat.
- Hasil runtime Fuzzel setelah bind `SUPER + R` dialihkan.
- Icon dan cursor theme final.
- Nilai final spacing, radius, ukuran panel, opacity, dan durasi animasi.
- Paket font/theme yang diperlukan.
- Susunan direktori konfigurasi final.

---

**Status keseluruhan: DESIGN DIRECTION APPROVED — HYPRLAND/FUZZEL FOUNDATION APPLIED; CAELESTIA GRAPHITE PROFILE APPLIED AND RUNTIME VERIFIED; REMAINING STAGE 5 COMPONENTS PENDING.**

Dokumen ini menjadi acuan utama untuk keputusan desain dan review perubahan selama tahap 5. Setiap penyimpangan material harus memiliki alasan teknis dan persetujuan sebelum implementasi.

## 11. Implemented Graphite profile — 2026-11-09

The approved direction has now been translated into project-owned configuration files. This implementation targets the installed Caelestia Shell **v2.5.0** configuration schema and deliberately avoids internal shell-tokens.json overrides.

### Caelestia components

- **Bar/taskbar:** persistent compact layout; workspace shapes; active-window label; compact tray; date-enabled clock; network, Bluetooth, battery, audio and lock indicators. Decorative logo entry removed.
- **Dashboard:** media and performance modules enabled; weather disabled until a location is intentionally configured. Resource polling interval set to 2500 ms and media interval to 2000 ms to reduce unnecessary update frequency.
- **Launcher:** 9 visible results, fuzzy app/action matching, existing safe actions retained, dangerous actions disabled.
- **Lock screen:** wallpaper enabled and lock notifications hidden. Fingerprint and Howdy settings remain enabled with their previous retry limits; password/PAM/authentication configuration is not modified.
- **Sidebar:** enabled and not hover-only.
- **Utilities:** quick toggles for Wi-Fi, Bluetooth, microphone, settings, game mode and DND; VPN toggle remains disabled.
- **Notifications/OSD:** smaller notification preview group and short OSD duration.
- **Appearance:** Rubik UI, CaskaydiaCove NF monospace, Material Symbols Rounded, reduced spacing/padding and animation scale, no shell transparency/blur assumptions.

### Application integration

- GTK3/GTK4 use Adwaita-dark preferences and Graphite color definitions.
- Thunar retains the audited layout intent but drops the previous teal palette and entrance animation.
- Foot uses the CaskaydiaCove NF font, Graphite background, high-contrast foreground, restrained semantic ANSI colors, and a non-blinking beam cursor.
- Caelestia CLI is configured to generate GTK and Qt themes with the Adwaita icon theme. Hyprland, Fuzzel and Foot are managed by project-owned settings to avoid competing generators.
- GTK icon/cursor preferences use Adwaita, which was present in the prior device audit. This is a conservative fallback, not a custom monochrome icon pack.

### Wallpaper and rollback

The editable vector source is assets/wallpapers/k41-obsidian-1920x1080.svg. The applied wallpaper is stored as base64 text at assets/wallpapers/k41-obsidian-1280x720.jpg.base64; the script decodes it to a 1280x720 JPEG and activates it with Caelestia CLI. Upstream CLI source accepts JPEG, PNG, WebP, TIFF and GIF image extensions. The device-side visual quality of scaling this 1280x720 abstract wallpaper to the 1920x1080 panel remains part of acceptance.

Two scripts separate the shell profile from cross-application integration:
- scripts/k41-apply-full-desktop-profile.sh
- scripts/k41-apply-desktop-integration.sh

Both create timestamped backups before applying configuration. Their rollback commands and limitations are documented in docs/03-DESKTOP.md. Neither script installs packages, changes system services, modifies PAM, or edits internal Caelestia tokens.

### Validation status

Repository implementation is **IMPLEMENTED**, not yet device-verified. JSON profile syntax was parsed before commit and the chosen Caelestia option names are grounded in the upstream v2.5.0 README. No Bash syntax check, ShellCheck, GTK CSS parser, Foot config parser, shell runtime restart, wallpaper decoder check, performance measurement, or on-device visual acceptance has yet been executed for this batch.

Stage 5 remains open until the user runs both scripts and confirms lock screen authentication, bar/taskbar, dashboard, launcher, sidebar, utilities, notifications, Thunar, Foot, and general desktop stability.
