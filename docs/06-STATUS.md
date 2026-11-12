# Status Proyek

**Terakhir diperbarui: 2026-11-13.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

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

Urutan di bawah adalah urutan eksekusi workstream Stage 5. ID aktif berurutan 01–08; workflow kolaborasi adalah prosedur lintas-workstream, bukan workstream bernomor. Clean up Caelestia menjadi Workstream 08 dan selalu dikerjakan terakhir.

1. **Workstream 01 — Boot Experience: PAUSED — INVESTIGATION PENDING.** Implementasi Plymouth-only, theme K41, installer, dan handoff helper tersedia di repository. Audit read-only X280 20261112T051447Z mencatat plymouth-start.service dan switch-root berhasil, UKI berisi komponen Plymouth, theme default dilaporkan k41, serta k41-plymouth-release.service menjalankan plymouth quit --retain-splash sekitar detik ke-15. Journal juga mencatat fbcon mengambil alih console sekitar detik ke-16 dan Plymouth quit selesai sekitar detik ke-22. Fakta ini menunjukkan lifecycle service berjalan, tetapi tidak membuktikan splash terlihat. Display handoff, renderer/theme, dan interaksi VT masih hipotesis; penyebab belum VERIFIED. Belum ada bukti repair script Caelestia menyebabkan masalah. Jangan menjalankan installer, rebuild UKI, atau mengubah boot/system services sampai audit read-only selesai dan rencana perubahan disetujui. Lihat [dokumen Workstream 01](../stages/stage-5-desktop-customization/docs/01-BOOT-EXPERIENCE.md).
2. **Workstream 02 — Lock Screen: COMPLETED / USER ACCEPTED (12 November 2026).** Pengguna telah menerima penyelesaian workstream yang mencakup audit visual/startup, source visual K41, helper dan updater startup, deployment dengan backup/checksum/log, publikasi log tersanitasi otomatis melalui temporary independent clone, cleanup hook legacy, serta cleanup sembilan komponen visual Caelestia yang tidak lagi digunakan. Dependency preflight deployment juga diperbarui untuk memeriksa `center/Clock.qml` dan `center/StateMessage.qml`. Dokumen pemilik: [Workstream 02 — Lock Screen](../stages/stage-5-desktop-customization/docs/02-LOCK-SCREEN.md). **COMPLETED / USER ACCEPTED tidak berarti seluruh runtime X280 VERIFIED.** Audit startup lanjutan `20261112T195531Z` menggabungkan beberapa log: lima startup historis mengamati Caelestia IPC ready, lock request accepted, dan lock state verified; dua startup mengalami IPC timeout. Pada startup terbaru yang tercatat (13 November sekitar 02:53 WIB), IPC timeout diikuti Hyprlock fallback; log fallback menunjukkan autentikasi berhasil dan unlock. Ini bukan satu timeline tunggal dan tidak membuktikan Lock Surface QML terlihat. QML rendering, seluruh skenario lock/unlock, suspend/resume, dan autentikasi Caelestia pada run terbaru tidak diklaim VERIFIED. Detail: dokumen Workstream 02. Cleanup visual hanya menargetkan user checkout dan meninggalkan tracked deletions pada Caelestia; jangan update checkout sebelum file dipulihkan atau prosedur update menangani deletions. PAM, authentication, dan Wayland session-lock protocol tetap di luar scope perubahan visual.
3. **Workstream 03 — Bottombar: COMPLETED / USER ACCEPTED.** Source canonical K41, deployment ke `~/.config/quickshell/k41/modules/bottombar/Dock.qml`, dan integrasi `K41Bottombar.Dock {}` pada Caelestia host telah diimplementasikan sesuai arsitektur yang disepakati. Pengguna menyatakan legacy `K41Dock` telah dihapus manual. Status completed adalah penerimaan scope workstream; Bash syntax, ShellCheck, fixture execution, QML compile/runtime, dan regression belum diklaim TESTED/VERIFIED. Dokumen owner: [Bottombar](../stages/stage-5-desktop-customization/docs/03-BOTTOMBAR.md).
4. **Workstream 04 — Topbar: PENDING — REBOOT DAN RUNTIME VERIFICATION.** Source/deployer tersedia. Audit X280 terakhir menunjukkan module runtime identik dengan source canonical, host memiliki import dan instance Topbar pada posisi struktural yang diharapkan, serta satu proses Quickshell aktif dengan selector `caelestia`. Pengguna mengidentifikasi reboot sebagai langkah berikutnya untuk memuat perubahan; reboot belum diklaim telah dilakukan dalam dokumentasi ini. QML load/instantiation/rendering, visual, notification tray, fullscreen, multi-monitor, scaling, dan Bottombar regression belum VERIFIED. Lihat [Topbar](../stages/stage-5-desktop-customization/docs/04-TOPBAR.md).
5. **Workstream 05 — Launcher: PLANNED.**
6. **Workstream 06 — Sidebar: PLANNED.**
7. **Workstream 07 — Utilities: PLANNED.**
8. **Workstream 08 — Clean up Caelestia: PLANNED — FINAL WORKSTREAM.** Dilaksanakan hanya setelah seluruh workstream komponen Stage 5 selesai/diterima. Audit read-only, dependency mapping, persetujuan target, dry-run, backup, controlled cleanup, dan rollback wajib. Scope: [Clean up Caelestia](../stages/stage-5-desktop-customization/docs/08-CLEAN-UP-CAELESTIA.md).

**Fondasi lintas-workstream K41-dots — PLANNED (bukan workstream tersendiri).** Menyusun audit fitur upstream yang read-only dan script penyiapan modul ke `~/.config/quickshell/k41/modules/<feature>/`. Fondasi ini mendukung komponen Stage 5 dan tidak mengubah urutan eksekusi di atas.

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

## Bottombar audit publisher correction — 12 November 2026

- **IMPLEMENTED:** Workstream 03 audit now keeps the complete diagnostic report privately under `~/.local/state/k41/bottombar/audits/` and automatically publishes a separately sanitized copy under `reports/stage-5-desktop-customization/03-bottombar/audits/<timestamp>/`.
- **IMPLEMENTED:** Publication uses a temporary independent clone of the approved repository. Fetch/commit/push/rebase operations are confined to that clone; the active checkout's HEAD, branch, index, FETCH_HEAD, and worktree metadata are not used for writes.
- **IMPLEMENTED:** A regression test was added to reject local-checkout Git mutations and require isolated-clone publication; the test is included in `tests/run.sh`. CI also compiles the embedded Python block in the Bottombar audit.
- **NOT TESTED YET:** Bash syntax, ShellCheck, repository regression suite, simulated end-to-end push, and a fresh X280 audit/publication have not been executed in this session. No claim of runtime verification is made.
- **PRIVACY NOTE:** Sanitization masks common host/user/network/credential identifiers, but cannot guarantee that every sensitive value is removed. Review the published report on GitHub.
- **FAILURE BEHAVIOR:** If clone, commit, or push fails, the private local report is retained and the audit exits non-zero; the active checkout remains untouched.

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
