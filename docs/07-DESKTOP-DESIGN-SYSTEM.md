# K41 Obsidian Minimalism — Desktop Design Specification

## Status and purpose

- **Project:** Lenovo ThinkPad X280 K41
- **Stage:** 5 — Desktop Environment Customization
- **Design status:** APPROVED DIRECTION; active configuration audited; baseline visual capture pending
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

Nilai numerik gaps, radius, ukuran panel, durasi animasi, dan opacity akan ditetapkan setelah audit konfigurasi aktif serta review screenshot baseline. Jangan menebak atau menyalin angka sebelum mengetahui konfigurasi dan perilaku upstream yang berlaku.

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
- Screenshot comparison, visual review, functional regression, and rollback.

### Out of scope — Stage 5

- CPU/GPU tuning.
- Thermal/fan tuning.
- Battery and power policy optimization.
- Suspend/hibernate/resume optimization campaign.
- Major changes to kernel, firmware, or system services.
- Replacing the desktop shell architecture.

Pekerjaan tersebut berada pada tahap 6 atau memerlukan keputusan arsitektur terpisah.

## 10. Implementation workflow

1. Audit konfigurasi aktif Hyprland, Caelestia, Quickshell, GTK, Qt, fonts, icons, cursor, dan wallpaper.
2. Catat baseline screenshot dan kondisi runtime/performa yang relevan.
3. Petakan konfigurasi upstream versus konfigurasi pengguna.
4. Tetapkan design tokens final dan struktur konfigurasi.
5. Backup konfigurasi serta siapkan rollback.
6. Implementasikan perubahan kecil per komponen.
7. Validasi syntax/configuration dan runtime setelah setiap kelompok perubahan.
8. Periksa regresi fungsi desktop dan dampak performa.
9. Ambil screenshot before/after dan lakukan review visual pada perangkat X280.
10. Catat hasil, isu tersisa, dan keputusan penerimaan.

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
- [ ] Screenshot before/after ditinjau pada display fisik X280.
- [ ] Performa dibandingkan dengan baseline dalam kondisi yang sebanding; tidak ada regresi yang tidak dapat diterima.
- [ ] Backup dan rollback telah diuji atau setidaknya langkah pemulihannya diverifikasi.
- [ ] Dokumentasi dan bukti pengujian diperbarui.

Automated validation saja tidak cukup untuk menyatakan visual acceptance. Persetujuan visual akhir memerlukan review pengguna pada perangkat.

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
- Launcher: satu launcher utama.
- Dashboard: sesuai kebutuhan, bukan selalu tampil.
- Motion: subtle.
- Transparency: selective.
- Blur: minimal.
- Performance: prioritas tinggi; hindari efek dan polling yang tidak perlu.
- Tahap 5 tidak mencakup optimasi hardware tahap 6.

Hal yang belum diputuskan dan harus diverifikasi:
- Mekanisme override Caelestia/Quickshell dan opsi theming upstream yang tepat.
- Launcher final berdasarkan kemampuan dan integrasi aktual.
- Icon dan cursor theme final.
- Nilai final spacing, radius, ukuran panel, opacity, dan durasi animasi.
- Paket font/theme yang diperlukan.
- Susunan direktori konfigurasi final.

---

**Status keseluruhan: DESIGN DIRECTION APPROVED — IMPLEMENTATION NOT STARTED.**

Dokumen ini menjadi acuan utama untuk keputusan desain dan review perubahan selama tahap 5. Setiap penyimpangan material harus memiliki alasan teknis dan persetujuan sebelum implementasi.
