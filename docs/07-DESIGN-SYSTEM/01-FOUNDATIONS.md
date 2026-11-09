# Foundations — K41 Obsidian Minimalism

## Design vision

K41 Obsidian Minimalism adalah desktop modern, minimalis, monochromatic, elegan, dan premium.

Prinsip utama: **less elements, better details**. Desktop harus tenang ketika tidak digunakan. Informasi dan kontrol muncul saat relevan. Kesan premium dibangun melalui komposisi, tipografi, kontras, spacing, konsistensi, dan detail rapi, bukan efek berat.

## Prinsip desain

1. Minimal, bukan kosong atau sulit digunakan.
2. Monochromatic, bukan kontras rendah.
3. Elegan dan konsisten, bukan dekoratif atau ramai.
4. Informasi penting mudah ditemukan dan dibaca.
5. Interaksi keyboard cepat dan dapat diprediksi.
6. Performa dan stabilitas lebih penting daripada efek visual.
7. Gunakan fitur upstream yang didukung sebelum membuat pengganti.

## Color tokens — Graphite Monochrome

| Token | Nama | Nilai | Penggunaan |
|---|---|---|---|
| `color.background` | Deep Black | `#0A0A0B` | Latar utama dan wallpaper |
| `color.surface` | Dark Graphite | `#141416` | Panel dan permukaan utama |
| `color.surface.elevated` | Charcoal | `#1C1C20` | Popover, menu, elevated surface |
| `color.border` | Dark Gray | `#29292E` | Border dan separator |
| `color.text.primary` | Off White | `#F2F2F0` | Teks utama |
| `color.text.secondary` | Soft Gray | `#A1A1A6` | Teks sekunder |
| `color.text.muted` | Dim Gray | `#68686F` | Metadata non-esensial |
| `color.accent` | Silver | `#C4C4C9` | Aksen dan state aktif secara terbatas |

Token ini adalah nilai desain awal. Jangan menganggap seluruh pasangan warna sudah lulus contrast testing. Pastikan teks, fokus, disabled state, dan indikator penting tetap terbaca. Warna semantik error/warning/success boleh dipakai secara terbatas bila membantu menyampaikan makna.

## Typography

Arah tipografi yang digunakan dalam profil Graphite repository:
- UI: Rubik.
- Monospace: CaskaydiaCove Nerd Font.
- Icon font: Material Symbols Rounded.
- Fallback karakter: Noto Sans/Noto Sans Mono bila diperlukan.

Gunakan hanya font dan weight yang benar-benar dibutuhkan. Pertahankan hirarki ukuran dan weight. Jangan membuat metadata terlalu kecil/redup. Monospace dipakai untuk data teknis.

## Iconography and cursor

- Gunakan satu keluarga ikon konsisten.
- Utamakan simbol yang jelas dan mudah dikenali.
- Status penting tidak boleh hanya dibedakan oleh warna atau ikon.
- Jangan mencampur banyak icon pack tanpa alasan.
- Pilihan final icon/cursor tetap dicatat sebagai keputusan bila berubah dari baseline Adwaita/Material Symbols yang ada.

## Layout and surfaces

- Panel ringkas dengan whitespace cukup.
- Spacing konsisten.
- Radius sudut konsisten; hindari bentuk terlalu bulat tanpa tujuan.
- Border halus lebih diutamakan daripada shadow tebal.
- Transparansi selektif, hanya bila memperjelas hierarki.
- Blur minimal dan hanya bila tetap responsif.
- Komponen tidak boleh menutupi area kerja secara tidak wajar.

Nilai akhir gaps, radius, border, opacity, dan ukuran ditetapkan setelah memeriksa konfigurasi aktif dan review perangkat; jangan menebak nilai dari spesifikasi ini.

## Motion

- Animasi singkat, subtle, dan memiliki tujuan fungsional.
- Hindari animasi dekoratif terus-menerus, parallax, dan efek tanpa manfaat.
- Hindari polling agresif untuk widget.
- Utamakan respons dan stabilitas dibanding efek visual.

## Wallpaper

- Abstract monochrome, dominasi hitam/graphite/charcoal.
- Geometri sederhana; gradient sangat halus bila diperlukan.
- Komposisi tenang dengan ruang visual cukup.
- Wallpaper tidak boleh bersaing dengan panel, teks, atau jendela.
- Wallpaper alternatif harus tetap berada dalam keluarga visual yang sama.

## Performance and reliability

Target perangkat memiliki Intel UHD Graphics 620. Hindari blur besar/berlapis, shadow kompleks, transparansi berlebihan, polling agresif, daemon duplikat, animasi terus berjalan, dan dependency tanpa kebutuhan jelas.

Pertahankan fungsi desktop, audio, portal, jaringan, input, lock screen, dan recovery. Jangan membuat klaim dampak CPU/RAM tanpa baseline dan pengukuran yang sebanding.
