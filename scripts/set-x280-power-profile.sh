#!/usr/bin/env bash
set -Eeuo pipefail
usage() {
  cat <<'USAGE'
Usage:
  bash scripts/set-x280-power-profile.sh --show
  bash scripts/set-x280-power-profile.sh --apply PROFILE
Profiles: power-saver, balanced, performance (only if exposed by the daemon).
--show is read-only. --apply changes the active profile and verifies the result.
Run as the regular user; no sudo, package installation, or service changes.
USAGE
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
case "\${1-}" in
  -h|--help) usage; exit 0 ;;
  --show) [[ $# == 1 ]] || { usage >&2; exit 2; } ;;
  --apply) [[ $# == 2 ]] || { usage >&2; exit 2; } ;;
  *) usage >&2; exit 2 ;;
esac
command -v busctl >/dev/null 2>&1 || die 'busctl is required (systemd).'
service= path= iface=
for candidate in \
  'net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles' \
  'org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles'; do
  read -r s p i <<<"$candidate"
  if busctl --system introspect "$s" "$p" "$i" >/dev/null 2>&1; then
    service="$s"; path="$p"; iface="$i"; break
  fi
done
[[ -n $service ]] || die 'Power Profiles D-Bus service/interface not found or inaccessible.'
get_property() { busctl --system get-property "$service" "$path" "$iface" "$1"; }
profiles="$(get_property Profiles)" || die 'could not read available profiles.'
active_raw="$(get_property ActiveProfile)" || die 'could not read active profile.'
active="\${active_raw#s }"; active="\${active%\"}"; active="\${active#\"}"
if [[ \${1} == --show ]]; then
  printf 'D-Bus service: %s\nObject: %s\nActive profile: %s\nAvailable profile data: %s\n' "$service" "$path" "$active" "$profiles"
  exit 0
fi
requested="$2"
case "$requested" in power-saver|balanced|performance) ;; *) die 'unsupported profile name.' ;; esac
grep -Fq "\\"$requested\\"" <<<"$profiles" || die "profile '$requested' is not exposed by this device."
if [[ $requested == "$active" ]]; then printf 'Already active: %s\n' "$active"; exit 0; fi
printf 'Changing power profile: %s -> %s\n' "$active" "$requested"
printf 'Rollback: bash scripts/set-x280-power-profile.sh --apply %s\n' "$active"
busctl --system set-property "$service" "$path" "$iface" ActiveProfile s "$requested" || die 'D-Bus rejected the profile change.'
verified_raw="$(get_property ActiveProfile)" || die 'profile set but verification read failed.'
verified="\${verified_raw#s }"; verified="\${verified%\"}"; verified="\${verified#\"}"
[[ $verified == "$requested" ]] || die "verification mismatch: expected '$requested', observed '$verified'."
printf 'VERIFIED active profile: %s\n' "$verified"
