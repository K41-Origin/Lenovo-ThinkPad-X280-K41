#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

# Sourcing must not emit output or alter shell options/traps.
before_options="$(set +o)"
before_traps="$(trap -p)"
source "$repo_root/lib/common.sh" >"$tmp/source.out" 2>"$tmp/source.err" || fail 'common module sourcing returned failure'
source "$repo_root/lib/preflight.sh" >>"$tmp/source.out" 2>>"$tmp/source.err" || fail 'preflight module sourcing returned failure'
[[ ! -s "$tmp/source.out" && ! -s "$tmp/source.err" ]] || fail 'module sourcing emitted output'
[[ "$(set +o)" == "$before_options" ]] || fail 'module sourcing changed shell options'
[[ "$(trap -p)" == "$before_traps" ]] || fail 'module sourcing changed traps'
pass 'module sourcing has no output or shell-option/trap changes'

# Logging goes to stderr and validates its argument count.
log_stdout="$(k41::log_info 'diagnostic' 2>/dev/null)" || fail 'info logger failed'
[[ -z "$log_stdout" ]] || fail 'logger wrote to stdout'
log_stderr="$(k41::log_info 'diagnostic' 2>&1 >/dev/null)"
[[ "$log_stderr" == 'INFO: diagnostic' ]] || fail 'logger stderr format mismatch'
if k41::log_warn >/dev/null 2>&1; then fail 'logger accepted missing argument'; fi
pass 'logging helpers validate arguments and write to stderr'

# Boot-mode detector accepts a fixture root, allowing deterministic tests.
mkdir -p "$tmp/uefi/efi" "$tmp/legacy"
preflight::detect_boot_mode_at "$tmp/uefi" 2>"$tmp/uefi.log" || fail 'UEFI fixture failed'
grep -q 'UEFI' "$tmp/uefi.log" || fail 'UEFI result not reported'
preflight::detect_boot_mode_at "$tmp/legacy" 2>"$tmp/legacy.log" || fail 'legacy fixture failed'
grep -q 'legacy/BIOS candidate' "$tmp/legacy.log" || fail 'legacy result not reported'
if preflight::detect_boot_mode_at "$tmp/missing" 2>"$tmp/unknown.log"; then
  fail 'unknown firmware state was treated as success'
fi
grep -q 'unknown' "$tmp/unknown.log" || fail 'unknown state not reported'
pass 'boot-mode detection distinguishes UEFI, legacy candidate, and unknown'

# Required-command check handles present, absent, and invalid names.
preflight::check_commands bash 2>"$tmp/commands-ok.log" || fail 'present command not detected'
if preflight::check_commands command-that-does-not-exist-k41 2>"$tmp/commands-missing.log"; then
  fail 'missing command was treated as success'
fi
if preflight::check_commands 'bad/name' 2>"$tmp/commands-invalid.log"; then
  fail 'invalid command name was accepted'
fi
pass 'required-command check handles present, missing, and invalid names'

# Network diagnostic uses only a read-only link query.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/ip" <<'MOCK_IP'
#!/usr/bin/env bash
[[ "$*" == '-brief link show' ]] || exit 9
printf 'lo UNKNOWN 00:00:00:00:00:00\n'
MOCK_IP
chmod +x "$tmp/bin/ip"
PATH="$tmp/bin:$PATH" preflight::report_network_links 2>"$tmp/network.log" || fail 'mock network link query failed'
grep -q 'not proof of internet connectivity' "$tmp/network.log" || fail 'network limitation not disclosed'
grep -q 'lo UNKNOWN' "$tmp/network.log" || fail 'network link observation missing'
pass 'network check reports link state without claiming internet access'

printf '%s\n' 'All common/preflight tests passed.'
