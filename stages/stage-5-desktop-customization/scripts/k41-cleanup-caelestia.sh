#!/usr/bin/env bash
# Phase 1 of Dashboard removal: generate a fresh read-only Caelestia audit.
# Actual deletion is intentionally gated on review of the resulting report.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die 'Run as the regular desktop user; do not use sudo.'

script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
audit_script="$script_dir/k41-audit-caelestia.sh"
[[ -f $audit_script && -r $audit_script ]] || die "Missing audit script: $audit_script"

case \${1:-} in
    ""|--audit)
        [[ $# -le 1 ]] || die 'Usage: k41-cleanup-caelestia.sh [--audit]'
        ;;
    --apply|--rollback)
        die 'Deletion/apply is not available yet. Run the read-only audit first, push its report, and wait for target review.'
        ;;
    *)
        die 'Usage: k41-cleanup-caelestia.sh [--audit]'
        ;;
esac

printf '%s\n' 'K41 Caelestia Dashboard removal — pre-audit phase'
printf '%s\n' 'Mode: READ-ONLY'
printf '%s\n' 'No configuration, source file, keybind, package, service, or runtime state will be changed.'
printf '\n%s\n' 'Running the canonical Caelestia audit to inventory configuration, source roots, references, and keybind candidates...'

audit_output="$(bash "$audit_script" 2>&1)" || {
    printf '%s\n' "$audit_output" >&2
    die 'Caelestia audit failed; inspect the error above. No removal was attempted.'
}
printf '%s\n' "$audit_output"

report_rel="$(printf '%s\n' "$audit_output" | sed -n 's/^INFO: Report: //p' | tail -n 1)"
[[ -n $report_rel ]] || die 'Audit completed without reporting its output directory.'
report_dir="$repo_root/$report_rel"
[[ -d $report_dir && -f $report_dir/summary.txt && -f $report_dir/run.log ]] \
    || die "Expected audit report is incomplete: $report_dir"

printf '\n%s\n' 'Dashboard removal pre-audit completed.'
printf 'REPORT_DIR=%s\n' "$report_rel"
printf '%s\n' 'Review and push this report directory. The next revision will implement deletion only after the source targets, package ownership, Git dirty state, and external references have been reviewed.'
