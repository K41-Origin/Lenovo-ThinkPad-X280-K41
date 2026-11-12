# Status Proyek

**Terakhir diperbarui: 2026-11-12.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: stages/stage-1-live-readiness/scripts/k41-live-validation.sh. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh; operasi destruktif. |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: stages/stage-3-desktop-install/scripts/k41-install-desktop.sh. |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. |
| 5. Desktop Customization | **IN PROGRESS — WORKSTREAM 01 PAUSED** | Plymouth boot splash sedang diinvestigasi; Workstream lain mengikuti prioritas dan acceptance masing-masing. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu Stage 5 dan baseline X280 terbaru. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Prioritas dan status Stage 5

1. **Workstream 01 — Boot Experience: PAUSED — INVESTIGATION PENDING.** Implementasi Plymouth-only, theme K41, installer, dan handoff helper tersedia di repository. Audit read-only X280 20261112T051447Z mencatat plymouth-start.service dan switch-root berhasil, UKI berisi komponen Plymouth, theme default dilaporkan k41, serta k41-plymouth-release.service menjalankan plymouth quit --retain-splash sekitar detik ke-15. Journal juga mencatat fbcon mengambil alih console sekitar detik ke-16 dan Plymouth quit selesai sekitar detik ke-22. Fakta ini menunjukkan lifecycle service berjalan, tetapi tidak membuktikan splash terlihat. Display handoff, renderer/theme, dan interaksi VT masih hipotesis; penyebab belum VERIFIED. Belum ada bukti repair script Caelestia menyebabkan masalah. Jangan menjalankan installer, rebuild UKI, atau mengubah boot/system services sampai audit read-only selesai dan rencana perubahan disetujui. Lihat stages/stage-5-desktop-customization/docs/01-BOOT-EXPERIENCE.md.
2. **Workstream 02 — Lock Screen: DESIGN ACCEPTED; STARTUP REPAIR PREPARED; X280 RUNTIME VALIDATION PENDING.** Audit terbaru `reports/stage-5-desktop-customization/02-lock-screen/startup-audits/20261112T040241Z/report.txt` menunjukkan sesi yang direkam berada di TTY1 tanpa `WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE`, atau proses Hyprland aktif; karena itu laporan tersebut bukan bukti keberhasilan runtime lock. Analisis konfigurasi pada audit mengidentifikasi `hyprland.lua` sebagai konfigurasi aktif, sedangkan `caelestia shell -d` hanya dideklarasikan di `hyprland.conf`; helper lock pada hook Lua dapat berjalan sebelum Caelestia IPC siap sehingga fallback Hyprlock mengambil alih. Updater `workstreams/02-lock-screen/scripts/k41-update-lockscreen-startup-helper.sh` kini disiapkan untuk memasang helper dan konfigurasi Hyprlock terkelola, membuat backup, serta memastikan startup Caelestia berada sebelum helper pada blok K41 di Lua aktif. **Keberadaan updater di repository tidak membuktikan updater sudah dijalankan pada X280.** Regression suite untuk bounded timeout, Caelestia success, Hyprlock fallback, fail-closed, backup, penolakan konfigurasi ambigu, dan idempotensi telah ditambahkan; CI pada commit `5c55fd2` dilaporkan PASS untuk 39/39 test scripts beserta Bash syntax, embedded Python syntax, ShellCheck, dan formatting checks. Validasi runtime X280 tetap PENDING. Visual deployment dan cleanup source upstream tetap PAUSED sampai startup/lock readiness terbukti stabil. Jangan ubah PAM, autentikasi, session-lock protocol, Plymouth, getty, atau system services.
3. **Workstream 04 — Bottombar / K41Dock: COMPLETED / USER CONFIRMED SUCCESS.** Komponen telah berhasil digunakan. Source dan deployment saat ini masih berada pada struktur Caelestia lama; penyesuaian ke namespace K41 dilakukan sebagai bagian dari penyelarasan fondasi, tanpa mengubah desain yang sudah diterima.
4. **Fondasi K41-dots: PLANNED.** Menyusun audit fitur upstream yang read-only dan script penyiapan modul ke ~/.config/quickshell/k41/modules/<feature>/.
5. **Workstream 05 — Topbar: PLANNED.** Posisi atas dan orientasi horizontal telah diputuskan; elemen, alignment, ukuran, dan visibility harus ditentukan sebelum implementasi.
6. **Workstream 06 — Launcher: PLANNED.**
7. **Workstream 07 — Sidebar: PLANNED.**
8. **Workstream 08 — Utilities: PLANNED.**
9. Guest Mode (ID 03) **NOT IMPLEMENTED / DEFERRED** dan bukan pekerjaan aktif.

## Prinsip Stage 5 dan K41-dots

- K41-dots adalah kumpulan modul Quickshell milik K41, bukan shell mandiri pada tahap ini.
- Runtime tujuan modul adalah ~/.config/quickshell/k41/modules/<feature>/, misalnya lockscreen/.
- Script audit mengumpulkan informasi source, dependency, konfigurasi, dan titik integrasi yang relevan untuk satu fitur; audit tidak mengubah sistem.
- Script penyiapan mengambil hanya source/resource yang diperlukan dan menempatkannya pada namespace K41. Audit dan penyiapan adalah dua operasi terpisah.
- Caelestia tetap menjadi host/runtime; integrasi dilakukan seperlunya.
- Workstream 01 — Boot Experience dikecualikan dari K41-dots. Boot splash wajib hanya menggunakan Plymouth; QML/Quickshell tidak boleh menjadi bagian dari boot path.
- Jangan membangun bootstrap, runtime, service, atau framework deployment mandiri tanpa kebutuhan yang terbukti.
- Status implementasi modul, runtime laptop, dan penerimaan pengguna harus dibedakan. Dokumentasi rencana tidak berarti migrasi sudah dilakukan.

## Keputusan proyek yang masih berlaku

1. Dashboard dinonaktifkan melalui konfigurasi runtime Caelestia; halaman Dashboard Nexus upstream belum dihapus.
2. Hasil Stage 5 menjadi input evaluasi/perbaikan tahap instalasi sebelumnya.
3. Refactoring integrasi instalasi dilakukan setelah Stage 5 cukup matang dan sebelum Stage 7 — Release.
4. Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.
5. Design System menjadi spesifikasi visual lintas-komponen; status implementasi aktual dimiliki dokumen ini dan dokumen workstream pemilik.

## Bukti historis

Bukti Stage 4 historis tetap tersimpan pada commit arsip 02f6194ed04c8f13ea64eda35b7afb94f7006504. Snapshot tersebut bukan laporan runtime terkini.

## Lock Screen audit publisher correction — 12 November 2026

- **IMPLEMENTED:** `k41-audit-desktop-startup.sh` stores private local reports under `~/.local/state/k41/lockscreen/startup-audits/`, outside the checkout, while publishing only the sanitized copy under `reports/` in a temporary independent clone. This prevents the same-path untracked-file collision that can make the next `git pull` fail.
- **IMPLEMENTED:** Publisher uses an independent temporary clone rather than fetching and registering a linked worktree in the user's active checkout. Its Git operations are isolated from local branch/HEAD/index/FETCH_HEAD/worktree metadata.
- **IMPLEMENTED:** startup audit now records revision/hash metadata for the relevant updater, helper, fallback config, visual deployer, and visual auditor; it compares the installed Hyprlock fallback config against repository source and captures Hyprland instance metadata.
- **IMPLEMENTED:** regression test updated to reject local-checkout fetch/worktree operations and require the independent clone path.
- **NOT TESTED YET:** Bash syntax, ShellCheck, regression suite, end-to-end push simulation, and fresh X280 audit report. No claim of runtime verification is made.
- **Scope note:** automatic deployment-log publisher in `k41-deploy-lockscreen-visual.sh` still uses the older linked-worktree pattern and remains a separate follow-up; this change only corrects the startup audit publisher.


## Lock Screen deployment publisher correction — 12 November 2026

- **IMPLEMENTED:** `k41-deploy-lockscreen-visual.sh` now publishes sanitized deployment logs through an independent temporary clone of the approved repository. It no longer runs `git fetch` or `git worktree add/remove` against the user's active checkout.
- **IMPLEMENTED:** publication failure is separated from deployment outcome. A failed clone/push emits a warning and retains the private local log; it does not change the deployment exit status or trigger rollback. Rollback remains tied to deployment/copy/reload failure.
- **IMPLEMENTED:** log sanitization masks both the home directory and repository checkout path.
- **IMPLEMENTED:** regression test now checks the independent-clone publisher pattern and guards against local-checkout fetch/worktree operations and publication failure changing deployment status.
- **NOT TESTED YET:** Bash syntax/regression suite/ShellCheck execution and end-to-end publication simulation have not been run in this session. No deployment on the ThinkPad X280 has been performed.
- **DEPLOYMENT GATE:** latest startup audit supports moving to a deployment preflight, but the deployment script still requires the actual X280 Caelestia checkout origin, exact pinned HEAD, target-file state, and active Hyprland environment to pass its runtime guards. Do not describe visual deployment or rendering as verified until it is run and checked on the device.
