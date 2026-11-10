# Workstream 3 — Bottombar

## Tujuan

Mempertahankan panel workspace horizontal yang ringkas di tepi bawah layar. Komponen ini menjadi **Bottombar**, terpisah dari Topbar.

## Target desain

- Posisi horizontal di tepi bawah layar.
- Menampilkan indikator workspace saja; tidak menampilkan active window, tray, clock, status icons, atau power entry.
- Floating/minimal dan auto-hide; muncul ketika pointer menyentuh area trigger bawah.
- Menandai workspace aktif dan workspace yang berisi window; klik indikator berpindah ke workspace terkait.
- Tidak mengambil exclusive workspace area secara permanen.
- Latar gelap/transparan secukupnya, sudut membulat, dan transisi halus mengikuti Design System.
- Tidak mengganggu fullscreen, fokus window, input, atau perpindahan workspace.

Target ini meneruskan konsep dock yang sebelumnya diterima sebagai Taskbar/Panel. Perubahan nama menjadi Bottombar adalah keputusan terminologi; setiap perubahan implementasi lanjutan tetap harus diuji pada X280.

## Batas

Termasuk posisi, ukuran, workspace indicator, trigger edge, visibility, click-through, fullscreen behavior, dan integrasi Caelestia/Quickshell.

Tidak termasuk clock, tray, system status, launcher, utilities, atau informasi yang menjadi tanggung jawab Topbar.

## Prosedur

1. Audit konfigurasi dan source aktif, versi Quickshell/Caelestia, monitor/scaling, panel yang berjalan, dan keybind terkait.
2. Verifikasi apakah implementasi dock yang ada masih sesuai target; jangan mengasumsikan konfigurasi lokal belum berubah.
3. Backup semua file yang akan disentuh dan siapkan rollback.
4. Terapkan perubahan minimal. Gunakan API upstream yang terverifikasi; custom QML harus terlacak dan mudah dipelihara.
5. Uji active/occupied workspace, klik, hover trigger, click-through, fullscreen, fokus, multi-window, dan shell restart.
6. Periksa error QML/runtime dan konsumsi resource.

## Acceptance criteria

- Bottombar berada di tepi bawah dan hanya menampilkan indikator workspace.
- Workspace aktif/terisi ditampilkan benar dan klik berpindah ke workspace yang dipilih.
- Bottombar tersembunyi saat idle dan muncul melalui trigger bawah.
- Tidak ada exclusive zone permanen atau penghalangan input di luar area dock.
- Fullscreen, fokus window, keybind, dan workspace switching tetap berfungsi.
- Tidak ada error runtime kritis atau konsumsi resource yang tidak wajar.
- Pengguna menerima perilaku langsung pada X280.

## Rollback dan bukti

Backup konfigurasi dan source custom sebelum perubahan. Catat file, versi, test interaksi, log, dan hasil review pengguna. Jangan memasukkan data sensitif ke laporan.

## Status

Implementasi dock sebelumnya telah **COMPLETED / USER ACCEPTED pada 2026-11-11** sebagai Taskbar/Panel. Workstream ini dibuka kembali secara terbatas untuk perubahan nama/penyesuaian yang diperlukan menjadi Bottombar; jangan mengklaim penerimaan baru sampai pengguna memeriksa hasil perubahan tersebut.