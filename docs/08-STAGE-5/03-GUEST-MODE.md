# Guest Mode — Ephemeral Session

**Status: DESAIN KONSEPTUAL DISETUJUI — IMPLEMENTASI BELUM DIMULAI**  
**Tanggal keputusan: 2026-11-09**

Dokumen ini mencatat keputusan yang secara eksplisit disetujui pengguna. Dokumen ini bukan bukti implementasi, pengujian, atau jaminan bahwa data Guest saat ini sudah terhapus.

## 1. Tujuan

Menyediakan akun Guest terpisah untuk penggunaan desktop normal, dengan sasaran seluruh data lokal yang dibuat atau diubah selama sesi Guest tidak tersisa setelah reboot atau poweroff. Akun utama dan data persistent miliknya berada di luar cakupan cleanup Guest.

## 2. Keputusan yang disetujui

| Area | Keputusan |
|---|---|
| Identitas akun | Akun Linux terpisah dengan username default `guest` |
| Desktop | Menggunakan desktop environment/session yang sudah tersedia: Hyprland + Caelestia |
| Desktop kedua | Tidak membuat atau menjalankan desktop environment terpisah untuk Guest |
| Aplikasi | Menggunakan aplikasi sistem yang sudah terpasang, selama batas isolasi dapat dipenuhi |
| RAM | Tidak ada pembagian/reservasi RAM statis |
| Penyimpanan sesi | Seluruh data lokal yang dapat ditulis Guest harus ephemeral |
| Browser | Otomatis diluncurkan dalam Incognito/Private Mode |
| Browser profile | Profile Guest terpisah; tidak menggunakan atau mengakses profile akun utama |
| Hak akses | Tanpa administrator/sudo; akses ke data akun utama dan konfigurasi sistem yang dilindungi ditolak |
| Session tracking | Setiap login memiliki identitas sesi; metadata/log dipakai untuk tracking dan lifecycle |
| Logout | Mengakhiri dan menghancurkan lingkungan penyimpanan sesi |
| Reboot/poweroff | Data sesi lokal tidak boleh bertahan; boot berikutnya memverifikasi storage Guest bersih |
| Kegagalan cleanup | Guest login ditolak sampai storage berhasil dibersihkan dan diverifikasi |

## 3. Model lifecycle yang disepakati

```text
Guest Login
    |
    v
Create Session ID + Isolated Ephemeral Storage
    |
    v
Run Shared Hyprland / Caelestia Desktop
    |
    v
Guest Applications + Private Browser Session
    |
    +---- Logout ----> Destroy Session Storage
    |
    +---- Reboot / Poweroff
                |
                v
          System Startup
                |
                v
       Verify Guest Storage Is Empty
                |
          +-----+-----+
          |           |
        Empty      Residue found
          |           |
          |      Cleanup + Verify Again
          |           |
          +-----+-----+
                |
        Verification succeeds?
             /       \
           Yes        No
            |          |
      Allow Guest   Deny Guest
         Login         Login
```

Session ID/log bukan inventaris lengkap file yang harus dihapus. Penghapusan tidak boleh bergantung pada keberhasilan pencatatan setiap aktivitas atau pada logout yang bersih.

## 4. Prinsip penyimpanan dan isolasi

1. Isolasi harus diterapkan sebelum aplikasi Guest berjalan: semua lokasi writable yang dapat digunakan Guest harus diarahkan ke storage ephemeral atau ditolak.
2. Jangan hanya menghapus `/home/guest`. Audit juga `/var/tmp`, cache, runtime, logs, crash dumps, application state, browser data, dan jalur tulis lain yang relevan.
3. Storage volatile seperti tmpfs merupakan kandidat, tetapi menggunakan RAM secara dinamis. Ini bukan pembagian RAM statis; ukuran, batas, dan perilaku saat memory pressure harus diuji pada perangkat dengan RAM 8 GB.
4. Akun Guest tidak boleh dapat mengubah data akun utama atau konfigurasi sistem. Direktori bersama yang diperlukan harus dibatasi secara read-only jika memungkinkan.
5. Browser Private/Incognito mengurangi penyimpanan data browser, tetapi tidak menjamin seluruh aktivitas lokal terhapus. Browser profile Guest tetap harus terisolasi dan berada di storage ephemeral.
6. Baseline perangkat menunjukkan swapfile persistent aktif. Swap harus ditangani dalam desain sebelum klaim ephemerality dapat diterima. Enkripsi LUKS tidak sama dengan penghapusan setelah reboot.
7. Full-session OverlayFS dan selective ephemeral storage masih merupakan alternatif yang perlu dibandingkan. Belum ada pilihan implementasi final.

## 5. Boot verification dan fail-closed behavior

Pada setiap startup sebelum Guest dapat login, mekanisme pemeriksaan harus:
1. Memeriksa lokasi storage Guest yang ditetapkan.
2. Memastikan tidak ada data sesi sebelumnya.
3. Membersihkan residu yang ditemukan dengan cakupan yang sudah ditentukan.
4. Memverifikasi ulang bahwa storage bersih.
5. Mengizinkan Guest login hanya jika seluruh pemeriksaan berhasil.

Jika cleanup atau verifikasi gagal, akses Guest harus tetap terkunci dan kegagalan dicatat tanpa membocorkan isi data pribadi. Boot verification merupakan pertahanan tambahan; mekanisme utama tetap storage isolation yang mencegah data Guest ditulis ke lokasi persistent sejak awal.

## 6. Batas jaminan

Target penghapusan hanya dapat berlaku untuk data lokal yang berada di bawah kendali sistem. Tidak ada jaminan penghapusan data yang telah dikirim ke website/server, router, DNS resolver, layanan cloud, perangkat eksternal, atau media yang dilepas.

Jangan mengklaim secure erasure absolut pada SSD flash. Tujuan desain adalah mencegah data Guest tersimpan secara persisten dan memastikan storage sesi lokal kosong sebelum Guest login berikutnya.

## 7. Audit dan acceptance criteria — belum dikerjakan

Sebelum implementasi:
- Audit seluruh jalur write yang dapat dijangkau proses/aplikasi Guest.
- Tentukan model isolasi dan lifecycle storage yang paling sederhana serta dapat diuji.
- Selesaikan kebijakan swap/hibernation agar data Guest tidak tertulis ke swap persistent.
- Verifikasi kompatibilitas Hyprland, Caelestia, browser, portal, file picker, dan aplikasi desktop.
- Tentukan batas penggunaan storage volatile dan uji memory pressure pada X280.
- Pastikan akun Guest tidak dapat membaca/menulis home akun utama, mengakses kredensial, memperoleh privilege, atau mengubah konfigurasi sistem.

Acceptance tests minimal:
- Login/logout berulang dan pembuatan file di seluruh lokasi writable yang diizinkan.
- Browser: history, cookies, cache, downloads, profile, dan sesi login.
- Aplikasi GUI lain: dokumen, cache, recent files, thumbnail, dan application state.
- Reboot normal dan poweroff normal.
- Forced poweroff/crash dan reboot setelah sesi aktif.
- Boot verification: storage kosong, cleanup residu, verifikasi ulang, dan fail-closed ketika cleanup gagal.
- Pemeriksaan bahwa data akun utama dan konfigurasi persistent tidak berubah akibat Guest.
- Pemeriksaan swap/hibernation dan pencarian residu setelah reboot.

Tidak ada hasil acceptance test yang diklaim dalam dokumen ini.

## 8. Batas implementasi dan perubahan sistem

- Guest Mode belum dibuat; akun `guest` belum dinyatakan ada pada perangkat.
- Belum ada perubahan pada user/group, sudoers, PAM, systemd units, mount, fstab, swap, browser config, desktop config, atau filesystem.
- Audit collector `scripts/k41-guest-storage-audit.sh` bersifat read-only dan hanya menjadi baseline.
- Sesuai gate proyek, implementasi Guest Mode belum dimulai dan menunggu custom lock screen diterima pengguna serta audit/desain teknis diselesaikan.

## 9. Riwayat keputusan

- 2026-11-09: pengguna menyetujui akun terpisah `guest`, desktop bersama Hyprland + Caelestia, tanpa RAM statis, browser otomatis Incognito/Private, session tracking, ephemeral storage, serta boot-time verification dan cleanup dengan fail-closed behavior.
