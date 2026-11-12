# Guest Mode — Arsip Artefak Perencanaan

**Status: DIARSIPKAN — BUKAN BAGIAN DARI PROYEK AKTIF.**

Guest Mode telah dikeluarkan secara eksplisit dari scope proyek aktif. File di direktori ini dipertahankan hanya sebagai artefak historis perencanaan/audit; bukan workstream, item roadmap, target implementasi, atau acceptance gate.

## Isi arsip

- `scripts/k41-guest-storage-audit.sh`: satu salinan konsolidasi dari collector audit read-only terdahulu. Dua salinan identik yang sebelumnya berada di root `scripts/` dan Stage 5 telah digabungkan menjadi satu.
- `tests/test-guest-storage-audit.sh`: test kontrak dan safety statis historis. Test ini sengaja tidak dimasukkan ke `tests/run.sh`.

Test arsip mengacu ke collector di direktori arsip ini dan hanya dapat dijalankan manual dari root repository bila diperlukan untuk review historis. Test tersebut bukan bagian dari test suite yang didukung.

Repository ini tidak memasang atau memelihara akun Guest, service, mount, storage policy, maupun workflow runtime Guest.
