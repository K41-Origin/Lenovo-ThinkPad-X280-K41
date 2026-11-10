#!/usr/bin/env bash
# Apply repository-managed desktop config files from a reviewed manifest.
# No package installation, service changes, or shell restart is performed.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() {
  cat <<'USAGE'
Usage:
  bash scripts/k41-desktop-costumization.sh --dry-run
  bash scripts/k41-desktop-costumization.sh --apply

The apply mode requires an interactive confirmation and a reviewed manifest:
  config/desktop/customization.manifest

Manifest format: source-path<TAB>target-path
Targets are restricted to ~/.config/ and ~/.local/share/backgrounds/.
Every existing target is backed up before replacement.
USAGE
}
mode=${1:---dry-run}
[[ $# -le 1 ]] || { usage >&2; exit 2; }
case "$mode" in --dry-run|--apply) ;; -h|--help) usage; exit 0 ;; *) usage >&2; exit 2 ;; esac
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, jangan dengan sudo.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
manifest="$repo_root/config/desktop/customization.manifest"
[[ -f $manifest && ! -L $manifest ]] || die "Manifest belum tersedia: $manifest. Audit harus ditinjau terlebih dahulu."
[[ -r $manifest ]] || die 'Manifest tidak dapat dibaca.'

declare -a sources=() targets=()
while IFS=$'\t' read -r source target extra || [[ -n ${source:-}${target:-}${extra:-} ]]; do
  [[ -z ${source:-} || $source == \#* ]] && continue
  [[ -n ${target:-} && -z ${extra:-} ]] || die 'Baris manifest harus memiliki tepat dua kolom TSV.'
  [[ $source != /* && $target != /* ]] || die 'Path manifest harus relatif.'
  [[ $source != *'..'* && $target != *'..'* ]] || die 'Path traversal tidak diizinkan.'
  [[ $target == .config/* || $target == .local/share/backgrounds/* ]] || die "Target di luar allowlist: $target"
  src="$repo_root/$source"
  [[ -f $src && ! -L $src && -r $src ]] || die "Sumber tidak valid: $source"
  [[ ! -d $HOME/$target ]] || die "Target merupakan direktori: $target"
  [[ ! -L $HOME/$target ]] || die "Target symlink tidak diizinkan: $target"
  for existing in "${targets[@]}"; do [[ $existing != "$target" ]] || die "Target duplikat: $target"; done
  sources+=("$src")
  targets+=("$target")
done <"$manifest"
( ${#sources[@]} > 0 ) || die 'Manifest tidak memiliki entri yang dapat diterapkan.'

backup_root="$repo_root/reports/stage-5-desktop-customization/desktop-customization/backups"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_dir="$backup_root/$timestamp"
if [[ $mode == --dry-run ]]; then
  printf 'DRY-RUN: %s file akan diproses. Tidak ada perubahan dilakukan.\n' "${#sources[@]}"
  for i in "${!sources[@]}"; do
    if [[ -e $HOME/${targets[$i]} ]]; then
      printf 'REPLACE + BACKUP: %s\n' "${targets[$i]}"
    else
      printf 'CREATE: %s\n' "${targets[$i]}"
    fi
    printf '  source: %s\n' "${sources[$i]#"$repo_root"/}"
  done
  exit 0
fi

[[ -t 0 && -r /dev/tty && -w /dev/tty ]] || die '--apply memerlukan terminal interaktif.'
printf 'PERINGATAN: konfigurasi desktop pada HOME akan diubah.\n'
printf 'Manifest: %s\n' "$manifest"
printf 'Jumlah file: %s\n' "${#sources[@]}"
read -r -p 'Ketik APPLY-K41 untuk melanjutkan: ' confirmation </dev/tty
[[ $confirmation == APPLY-K41 ]] || die 'Dibatalkan; tidak ada perubahan.'

mkdir -p -- "$backup_dir"
chmod 0700 "$backup_root" "$backup_dir"
# Preflight and backup all current targets before the first replacement.
for i in "${!targets[@]}"; do
  target_path="$HOME/${targets[$i]}"
  parent="$(dirname -- "$target_path")"
  [[ ! -e $target_path || -f $target_path ]] || die "Target bukan file biasa: ${targets[$i]}"
  [[ ! -L $parent ]] || die "Parent target symlink tidak diizinkan: $parent"
  if [[ -f $target_path ]]; then
    mkdir -p -- "$backup_dir/$(dirname -- "${targets[$i]}")"
    cp -a -- "$target_path" "$backup_dir/${targets[$i]}"
  fi
done

# Stage all new files on the destination filesystem before atomic rename.
declare -a staged=()
cleanup() { for item in "${staged[@]:-}"; do [[ -n $item ]] && rm -f -- "$item"; done; }
trap cleanup EXIT
for i in "${!targets[@]}"; do
  target_path="$HOME/${targets[$i]}"
  parent="$(dirname -- "$target_path")"
  install -d -m 0755 -- "$parent"
  temp="$(mktemp "$parent/.k41-customization.XXXXXX")"
  cp -- "${sources[$i]}" "$temp"
  chmod 0644 "$temp"
  staged+=("$temp")
done

for i in "${!targets[@]}"; do
  mv -f -- "${staged[$i]}" "$HOME/${targets[$i]}"
  staged[$i]=''
done

{
  printf '# K41 desktop customization deployment\n'
  printf 'Applied UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'Backup directory: %s\n' "$backup_dir"
  printf 'Files applied: %s\n' "${#targets[@]}"
  printf '\n'
  printf '%s\n' "${targets[@]}"
} >"$backup_dir/deployment.txt"
chmod 0600 "$backup_dir/deployment.txt"
info 'File customization selesai.'
info "Backup: $backup_dir"
info 'Perubahan belum diverifikasi secara visual; restart/reload tidak dilakukan otomatis.'
