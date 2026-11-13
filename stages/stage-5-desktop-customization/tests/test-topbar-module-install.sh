#!/usr/bin/env bash
set -Eeuo pipefail

source_root="$(cd -- "$(dirname -- "$0")/../workstreams/04-topbar" && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/repository"
home="$tmp/home"
config="$tmp/config"
state="$tmp/state"
workstream="stages/stage-5-desktop-customization/workstreams/04-topbar"
services=(Cpu.qml Memory.qml Battery.qml Clock.qml Notifications.qml TopbarState.qml)

mkdir -p "$fixture/$workstream/modules/topbar/services" "$fixture/$workstream/scripts" "$home" "$config/quickshell/caelestia/services"
cp "$source_root/scripts/k41-implement-topbar.sh" "$fixture/$workstream/scripts/"
for service in "${services[@]}"; do
    cp "$source_root/modules/topbar/services/$service" "$fixture/$workstream/modules/topbar/services/$service"
done

git -C "$fixture" init -q
qml="$fixture/$workstream/modules/topbar/Topbar.qml"
cat >"$qml" <<'QML'
import QtQuick
Item { objectName: "K41Topbar" } // K41Topbar
QML

host="$config/quickshell/caelestia/shell.qml"
cat >"$host" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    id: root
}
QML
host_before="$(sha256sum "$host" | cut -d' ' -f1)"

notifs="$config/quickshell/caelestia/services/Notifs.qml"
cat >"$notifs" <<'QML'
pragma Singleton
Singleton {
    id: root
    property list<var> list: []
    NotificationServer {
        onNotification: notif => {
            notif.tracked = true;
            root.list = [comp, ...root.list];
        }
    }
}
QML

run_installer() {
    HOME="$home" XDG_CONFIG_HOME="$config" XDG_STATE_HOME="$state" PATH="${TEST_PATH:-$PATH}" \
        bash "$fixture/$workstream/scripts/k41-implement-topbar.sh"
}

target="$config/quickshell/caelestia/k41/modules/topbar/Topbar.qml"
service_target="$config/quickshell/caelestia/k41/modules/topbar/services"
run_installer
cmp -s "$target" "$qml"
for service in "${services[@]}"; do
    cmp -s "$service_target/$service" "$fixture/$workstream/modules/topbar/services/$service"
done
grep -Fqx 'import qs.k41.modules.topbar as K41Topbar' "$host"
grep -Fqx '    K41Topbar.Topbar {}' "$host"
grep -Fq 'K41_NOTIFICATION_SERVER_DISABLED_BY_K41' "$notifs"
if grep -Eq '^[[:space:]]*NotificationServer[[:space:]]*\\{' "$notifs"; then
    echo 'Caelestia NotificationServer was not disabled.' >&2
    exit 1
fi
backup_root="$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d -print -quit)"
test -f "$backup_root/Notifs.qml"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# Duplicate only the exact K41-owned host lines; deployment must overwrite
# them with one canonical import and one instance, preserving other host code.
awk '
    /import qs\\.k41\\.modules\\.topbar as K41Topbar/ { print; print; next }
    /K41Topbar\\.Topbar \\{\\}/ { print; print; next }
    { print }
' "$host" >"$host.duplicate"
mv "$host.duplicate" "$host"
run_installer
test "$(grep -Fc 'import qs.k41.modules.topbar as K41Topbar' "$host")" -eq 1
test "$(grep -Ec '^[[:space:]]*K41Topbar\\.Topbar[[:space:]]*\\{[[:space:]]*\\}[[:space:]]*
cp "$backup_root/Notifs.qml" "$notifs"
# Model a fresh install: the host has no K41 import yet, while its target
# directory contains an older, currently unused K41 copy.
cat >"$host" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    id: root
}
QML
notifs_before_rollback="$(sha256sum "$notifs" | cut -d' ' -f1)"
host_before_rollback="$(sha256sum "$host" | cut -d' ' -f1)"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/mv" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in
        *.shell.install.*) exit 97 ;;
    esac
done
exec /usr/bin/mv "$@"
SH
chmod 0755 "$tmp/bin/mv"
if TEST_PATH="$tmp/bin:$PATH" run_installer >/dev/null 2>&1; then
    echo 'Expected injected host publication failure.' >&2
    exit 1
fi
test "$(sha256sum "$notifs" | cut -d' ' -f1)" = "$notifs_before_rollback"
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_before_rollback"
cmp -s "$target" "$qml"
for service in "${services[@]}"; do
    cmp -s "$service_target/$service" "$fixture/$workstream/modules/topbar/services/$service"
done

# An unrecognized Caelestia source must fail before any further mutation.
host_after_install="$(sha256sum "$host" | cut -d' ' -f1)"
printf 'pragma Singleton\nSingleton { }\n' >"$notifs"
if run_installer >/dev/null 2>&1; then
    echo 'Expected unknown Caelestia source rejection.' >&2
    exit 1
fi
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_after_install"
# Restore the already-patched handoff state for the remaining guards.
cat >"$notifs" <<'QML'
pragma Singleton
Singleton {
    id: root
    property list<var> list: []
    // K41_NOTIFICATION_SERVER_DISABLED_BY_K41
}
QML

# Dependency rejection must not mutate installed files.
printf '\nimport Caelestia.Services\n' >>"$qml"
before="$(sha256sum "$target" | cut -d' ' -f1)"
if run_installer >/dev/null 2>&1; then
    echo 'Expected Caelestia dependency rejection.' >&2
    exit 1
fi
test "$(sha256sum "$target" | cut -d' ' -f1)" = "$before"

# Restore valid source before exercising the symlink guard.
cp "$source_root/modules/topbar/Topbar.qml" "$qml"
rm -f "$target"
ln -s "$host" "$target"
if run_installer >/dev/null 2>&1; then
    echo 'Expected symlink target rejection.' >&2
    exit 1
fi
test -L "$target"
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_before"

printf 'PASS: service deployment, Caelestia handoff, idempotency, fail-closed, dependency and symlink guards.\n'
 "$host")" -eq 1
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2

# Inject a failure at host publication after handoff and K41 staging; verify full rollback.
cp "$backup_root/Notifs.qml" "$notifs"
# Model a fresh install: the host has no K41 import yet, while its target
# directory contains an older, currently unused K41 copy.
cat >"$host" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    id: root
}
QML
notifs_before_rollback="$(sha256sum "$notifs" | cut -d' ' -f1)"
host_before_rollback="$(sha256sum "$host" | cut -d' ' -f1)"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/mv" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in
        *.shell.install.*) exit 97 ;;
    esac
done
exec /usr/bin/mv "$@"
SH
chmod 0755 "$tmp/bin/mv"
if TEST_PATH="$tmp/bin:$PATH" run_installer >/dev/null 2>&1; then
    echo 'Expected injected host publication failure.' >&2
    exit 1
fi
test "$(sha256sum "$notifs" | cut -d' ' -f1)" = "$notifs_before_rollback"
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_before_rollback"
cmp -s "$target" "$qml"
for service in "${services[@]}"; do
    cmp -s "$service_target/$service" "$fixture/$workstream/modules/topbar/services/$service"
done

# An unrecognized Caelestia source must fail before any further mutation.
host_after_install="$(sha256sum "$host" | cut -d' ' -f1)"
printf 'pragma Singleton\nSingleton { }\n' >"$notifs"
if run_installer >/dev/null 2>&1; then
    echo 'Expected unknown Caelestia source rejection.' >&2
    exit 1
fi
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_after_install"
# Restore the already-patched handoff state for the remaining guards.
cat >"$notifs" <<'QML'
pragma Singleton
Singleton {
    id: root
    property list<var> list: []
    // K41_NOTIFICATION_SERVER_DISABLED_BY_K41
}
QML

# Dependency rejection must not mutate installed files.
printf '\nimport Caelestia.Services\n' >>"$qml"
before="$(sha256sum "$target" | cut -d' ' -f1)"
if run_installer >/dev/null 2>&1; then
    echo 'Expected Caelestia dependency rejection.' >&2
    exit 1
fi
test "$(sha256sum "$target" | cut -d' ' -f1)" = "$before"

# Restore valid source before exercising the symlink guard.
cp "$source_root/modules/topbar/Topbar.qml" "$qml"
rm -f "$target"
ln -s "$host" "$target"
if run_installer >/dev/null 2>&1; then
    echo 'Expected symlink target rejection.' >&2
    exit 1
fi
test -L "$target"
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_before"

printf 'PASS: service deployment, Caelestia handoff, idempotency, fail-closed, dependency and symlink guards.\n'
