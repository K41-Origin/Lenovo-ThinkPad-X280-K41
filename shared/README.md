# Shared Components

Direktori ini adalah lokasi kanonis untuk komponen yang digunakan oleh lebih dari satu Stage.

## Ownership

- `lib/`: fungsi dan modul bersama. Modul khusus Stage tetap berada di `stages/<stage>/lib/`.
- `config/`: profil hardware dan konfigurasi yang dikonsumsi oleh beberapa workflow. Konfigurasi khusus Stage/workstream tetap berada di Stage pemiliknya.
- `scripts/`: hanya untuk utilitas lintas Stage yang belum mempunyai owner tunggal. Skrip dengan owner jelas harus ditempatkan di Stage terkait.
- `tests/`: hanya untuk test integrasi lintas Stage; test khusus Stage berada di direktori Stage pemilik.

## Compatibility paths

Root-level `lib/` dan `config/` saat ini merupakan symlink kompatibilitas ke `shared/lib/` dan `shared/config/`. Jangan menambahkan implementasi baru melalui alias tersebut. Referensi lama akan dimigrasikan bertahap setelah seluruh consumer diaudit.

## Change rules

1. Jangan menyalin shared module ke dalam Stage.
2. Sebelum memindahkan file, cari seluruh consumer dalam skrip, test, workflow, dan dokumentasi.
3. Pertahankan antarmuka publik atau migrasikan semua consumer dalam satu perubahan yang dapat divalidasi.
4. Hindari membuat direktori kosong hanya demi keseragaman.
