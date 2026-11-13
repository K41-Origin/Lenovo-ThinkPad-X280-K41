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
grep -Fq 'import "../../services" as Services' "$source_root/modules/topbar/Topbar.qml"

mkdir -p "$fixture/$workstream/modules/services" "$fixture/$workstream/modules/topbar" "$fixture/$workstream/scripts" "$home" "$config/quickshell/caelestia/services" "$config/quickshell/k41/modules/topbar" "$config/quickshell/k41/services"
printf 'preserve shared K41 service\n' >"$config/quickshell/k41/services/Other.qml"
printf 'old compatibility service\n' >"$config/quickshell/k41/services/Cpu.qml"
printf 'old compatibility Topbar\n' >"$config/quickshell/k41/modules/topbar/Topbar.qml"
cp "$source_root/scripts/k41-implement-topbar.sh" "$fixture/$workstream/scripts/"
for service in "${services[@]}"; do
    cp "$source_root/modules/services/$service" "$fixture/$workstream/modules/services/$service"
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
compat_target="$config/quickshell/k41/modules/topbar/Topbar.qml"
compat_service_target="$config/quickshell/k41/services"
service_target="$config/quickshell/caelestia/k41/services"
legacy_service_target="$config/quickshell/caelestia/k41/modules/topbar/services"
mkdir -p "$legacy_service_target"
printf 'legacy sentinel\n' >"$legacy_service_target/Legacy.qml"
run_installer
backup_root="$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d -print -quit)"
cmp -s "$target" "$qml"
cmp -s "$compat_target" "$qml"
test -f "$backup_root/compat-Topbar.qml"
test -f "$backup_root/compat-services/Cpu.qml"
grep -Fq 'old compatibility Topbar' "$backup_root/compat-Topbar.qml"
grep -Fq 'old compatibility service' "$backup_root/compat-services/Cpu.qml"
grep -Fq 'preserve shared K41 service' "$compat_service_target/Other.qml"
test ! -e "$legacy_service_target"
test -f "$backup_root/legacy-topbar-services/Legacy.qml"
for service in "${services[@]}"; do
    cmp -s "$service_target/$service" "$fixture/$workstream/modules/services/$service"
    cmp -s "$compat_service_target/$service" "$fixture/$workstream/modules/services/$service"
done
grep -Fq 'property bool transientNotification:' "$fixture/$workstream/modules/services/Notifications.qml"
! grep -Eq '^[[:space:]]*property[[:space:]]+[^;]*[[:space:]]transient([[:space:]:=]|$)' "$fixture/$workstream/modules/services/Notifications.qml"
grep -Fq 'notification.transient' "$fixture/$workstream/modules/services/Notifications.qml"
grep -Fq 'Item {' "$fixture/$workstream/modules/services/Cpu.qml"
grep -Fq 'visible: false' "$fixture/$workstream/modules/services/Cpu.qml"
grep -Fq 'Item {' "$fixture/$workstream/modules/services/Memory.qml"
grep -Fq 'visible: false' "$fixture/$workstream/modules/services/Memory.qml"
grep -Fq 'Item {' "$fixture/$workstream/modules/services/Clock.qml"
grep -Fq 'visible: false' "$fixture/$workstream/modules/services/Clock.qml"
grep -Fq 'Item {' "$fixture/$workstream/modules/services/Notifications.qml"
grep -Fq 'visible: false' "$fixture/$workstream/modules/services/Notifications.qml"
grep -Fq 'id: entry' "$fixture/$workstream/modules/services/Notifications.qml"
grep -Fq 'Process {' "$fixture/$workstream/modules/services/Cpu.qml"
grep -Fq 'Process {' "$fixture/$workstream/modules/services/Memory.qml"
grep -Fq 'SystemClock {' "$fixture/$workstream/modules/services/Clock.qml"
grep -Fqx 'import qs.k41.modules.topbar as K41Topbar' "$host"
grep -Fqx '    K41Topbar.Topbar {}' "$host"
grep -Fq 'K41_NOTIFICATION_SERVER_DISABLED_BY_K41' "$notifs"
if grep -Eq '^[[:space:]]*NotificationServer[[:space:]]*\{' "$notifs"; then
    echo 'Caelestia NotificationServer was not disabled.' >&2
    exit 1
fi
backup_root="$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d -print -quit)"
test -f "$backup_root/Notifs.qml"
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

run_installer
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1

# Duplicate exact K41-owned host lines; normalize to one canonical import and instance.
awk '
    /import qs\.k41\.modules\.topbar as K41Topbar/ { print; print; next }
    /K41Topbar\.Topbar \{\}/ { print; print; next }
    { print }
' "$host" >"$host.duplicate"
mv "$host.duplicate" "$host"
run_installer
test "$(grep -Fc 'import qs.k41.modules.topbar as K41Topbar' "$host")" -eq 1
test "$(grep -Ec '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$host")" -eq 1
test "$(find "$state/k41/backups/topbar" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2

# Inject failure at host publication and verify rollback restores both notification owners' files.
cp "$backup_root/Notifs.qml" "$notifs"
cat >"$host" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    id: root
}
QML
printf 'old mirror content for rollback\n' >"$compat_target"
printf 'old service content for rollback\n' >"$compat_service_target/Cpu.qml"
compat_module_before_rollback="$(sha256sum "$compat_target" | cut -d' ' -f1)"
compat_service_before_rollback="$(sha256sum "$compat_service_target/Cpu.qml" | cut -d' ' -f1)"
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
test "$(sha256sum "$compat_target" | cut -d' ' -f1)" = "$compat_module_before_rollback"
test "$(sha256sum "$compat_service_target/Cpu.qml" | cut -d' ' -f1)" = "$compat_service_before_rollback"
cmp -s "$target" "$qml"
for service in "${services[@]}"; do
    cmp -s "$service_target/$service" "$fixture/$workstream/modules/services/$service"
done

# Unknown Caelestia source must fail before mutation.
host_after_install="$(sha256sum "$host" | cut -d' ' -f1)"
printf 'pragma Singleton\nSingleton { }\n' >"$notifs"
if run_installer >/dev/null 2>&1; then
    echo 'Expected unknown Caelestia source rejection.' >&2
    exit 1
fi
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$host_after_install"

# Offline migration guards for the audited partial-install state.
mkdir -p "$tmp/offline-bin"
cat >"$tmp/offline-bin/pgrep" <<'SH'
#!/usr/bin/env bash
[[ ${MOCK_QS_RUNNING:-0} == 1 ]] && exit 0
exit 1
SH
cat >"$tmp/offline-bin/busctl" <<'SH'
#!/usr/bin/env bash
[[ ${MOCK_BUS_UNAVAILABLE:-0} == 1 ]] && exit 1
printf 'NAME PID PROCESS USER CONNECTION UNIT SESSION DESCRIPTION\n'
if [[ ${MOCK_BUS_OWNER:-0} == 1 ]]; then
    printf 'org.freedesktop.Notifications 123 qs user :1.2 - - mock\n'
fi
SH
chmod 0755 "$tmp/offline-bin/pgrep" "$tmp/offline-bin/busctl"
TEST_PATH="$tmp/offline-bin:$PATH"
cat >"$host" <<'QML'
import QtQuick
import Quickshell
import qs.k41.modules.topbar as K41Topbar
import qs.k41.modules.topbar as K41Topbar
ShellRoot {
    id: root
    K41Topbar.Topbar {}
    K41Topbar.Topbar {}
}
QML
cp "$backup_root/Notifs.qml" "$notifs"
partial_host_before="$(sha256sum "$host" | cut -d' ' -f1)"
partial_notifs_before="$(sha256sum "$notifs" | cut -d' ' -f1)"
if MOCK_QS_RUNNING=1 run_installer >/dev/null 2>&1; then
    echo 'Expected rejection while Quickshell is running.' >&2
    exit 1
fi
if MOCK_BUS_UNAVAILABLE=1 run_installer >/dev/null 2>&1; then
    echo 'Expected rejection when the user bus cannot be inspected.' >&2
    exit 1
fi
if MOCK_BUS_OWNER=1 run_installer >/dev/null 2>&1; then
    echo 'Expected rejection while the notification name has an owner.' >&2
    exit 1
fi
test "$(sha256sum "$host" | cut -d' ' -f1)" = "$partial_host_before"
test "$(sha256sum "$notifs" | cut -d' ' -f1)" = "$partial_notifs_before"

# Also exercise the one-sided partial state: only the import remains.
sed -i '/K41Topbar.Topbar/d' "$host"
if MOCK_BUS_OWNER=0 run_installer; then
    : # Expected to migrate safely with Quickshell stopped and no D-Bus owner.
else
    echo 'Expected safe migration for import-only partial state.' >&2
    exit 1
fi
test "$(grep -Fc 'import qs.k41.modules.topbar as K41Topbar' "$host")" -eq 1
test "$(grep -Ec '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$host")" -eq 1
grep -Fq 'K41_NOTIFICATION_SERVER_DISABLED_BY_K41' "$notifs"
if grep -Eq '^[[:space:]]*NotificationServer[[:space:]]*\{' "$notifs"; then
    echo 'Offline migration did not disable the Caelestia server.' >&2
    exit 1
fi
host_before="$(sha256sum "$host" | cut -d' ' -f1)"

# A stale compatibility mirror is repaired only after the same offline checks.
printf 'stale compatibility module\n' >"$compat_target"
compat_stale_before="$(sha256sum "$compat_target" | cut -d' ' -f1)"
if MOCK_QS_RUNNING=1 run_installer >/dev/null 2>&1; then
    echo 'Expected compatibility mirror sync to reject an active Quickshell process.' >&2
    exit 1
fi
if MOCK_BUS_OWNER=1 run_installer >/dev/null 2>&1; then
    echo 'Expected compatibility mirror sync to reject an active notification owner.' >&2
    exit 1
fi
test "$(sha256sum "$compat_target" | cut -d' ' -f1)" = "$compat_stale_before"
if MOCK_BUS_OWNER=0 run_installer >/dev/null 2>&1; then
    cmp -s "$compat_target" "$qml"
else
    echo 'Expected offline compatibility mirror sync to succeed.' >&2
    exit 1
fi

# A legacy directory migration is also guarded while the already-integrated shell is active.
mkdir -p "$legacy_service_target"
printf 'second legacy sentinel\n' >"$legacy_service_target/Legacy.qml"
if MOCK_QS_RUNNING=1 run_installer >/dev/null 2>&1; then
    echo 'Expected structural service migration to reject an active Quickshell process.' >&2
    exit 1
fi
if MOCK_BUS_OWNER=1 run_installer >/dev/null 2>&1; then
    echo 'Expected structural service migration to reject an active notification owner.' >&2
    exit 1
fi
test -f "$legacy_service_target/Legacy.qml"
if MOCK_BUS_OWNER=0 run_installer >/dev/null 2>&1; then
    test ! -e "$legacy_service_target"
else
    echo 'Expected offline structural service migration to succeed.' >&2
    exit 1
fi

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

printf 'PASS: primary and compatibility service deployment, shared-file preservation, notification handoff, idempotency, duplicate normalization, rollback, offline partial-migration guards, dependency and symlink guards.\n'
