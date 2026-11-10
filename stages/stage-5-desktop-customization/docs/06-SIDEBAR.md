# Workstream 6 — Sidebar

## Tujuan

Menyediakan panel samping untuk navigasi atau quick access yang benar-benar dibutuhkan, dengan perilaku tampil/sembunyi yang jelas dan tidak menghalangi pekerjaan.

## Batas

Termasuk keberadaan/ketiadaan sidebar, konten, layout, ukuran, posisi, trigger, focus, keyboard/mouse interaction, dan integrasi upstream.

Tidak termasuk mengulang fungsi Bottombar, Topbar, launcher, atau utilities. Sidebar tidak wajib dibuat bila kebutuhan sudah dipenuhi komponen lain.

## Prosedur

1. Audit apakah sidebar sudah tersedia dalam Caelestia/Quickshell atau komponen aktif lain; verifikasi versi dan dokumentasi upstream.
2. Tentukan kebutuhan nyata yang belum dipenuhi. Jika tidak ada, ajukan status NOT APPLICABLE dengan alasan dan bukti audit.
3. Bila diperlukan, petakan isi dan tindakan yang akan disediakan; hilangkan fungsi yang sudah dimiliki komponen lain.
4. Backup konfigurasi dan implementasikan secara minimal menggunakan API upstream.
5. Uji show/hide, focus, keyboard navigation, pointer interaction, edge behavior, multi-monitor bila relevan, serta interaksi dengan window fullscreen.
6. Uji kondisi konten kosong/error dan pastikan sidebar tidak menutupi kontrol penting atau mengunci input.

## Acceptance criteria

- Sidebar memiliki fungsi berbeda dan jelas, bukan duplikasi panel lain.
- Dapat ditampilkan/disembunyikan secara konsisten.
- Tidak mengganggu fokus, input, fullscreen, atau area kerja.
- Konten mudah dipahami dan jumlahnya terbatas.
- Bila tidak diperlukan, keputusan NOT APPLICABLE disertai alasan dan hasil audit.
- Pengguna menerima perilaku dan tampilannya pada perangkat.

## Rollback dan bukti

Backup konfigurasi terkait. Catat kebutuhan yang dipenuhi, fungsi yang dihindari agar tidak duplikat, test, log, dan review pengguna.

## Gate keluar

Status VERIFIED atau NOT APPLICABLE yang disetujui harus dicatat sebelum lanjut ke [Workstream 7 — Utilities](07-UTILITIES.md).