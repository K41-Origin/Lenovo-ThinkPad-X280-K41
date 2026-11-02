#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/storage.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/lsblk" <<'MOCK'
#!/usr/bin/env bash
cat "${K41_LSBLK_FIXTURE:?}"
MOCK
cat >"$tmp/bin/jq" <<'MOCK'
#!/usr/bin/env bash
exec /usr/bin/jq "$@"
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
export K41_LSBLK_FIXTURE="$tmp/devices.json"
cat >"$K41_LSBLK_FIXTURE" <<'JSON'
{"blockdevices":[
 {"name":"/dev/nvme0n1","type":"disk","size":256000000000,"model":"WDC PC SN730","tran":"nvme","wwn":"eui.001","serial":"SN001","rm":false,"ro":false,"mountpoints":[null],"children":[
  {"name":"/dev/nvme0n1p1","type":"part","size":1073741824,"mountpoints":["/efi"]},
  {"name":"/dev/nvme0n1p2","type":"part","size":255000000000,"mountpoints":["/"]}
 ]},
 {"name":"/dev/sda","type":"disk","size":32000000000,"model":"USB","tran":"usb","wwn":null,"serial":"USB001","rm":true,"ro":false,"mountpoints":[null],"children":[]},
 {"name":"/dev/sdb","type":"disk","size":64000000000,"model":"Unknown","tran":"usb","wwn":null,"serial":null,"rm":false,"ro":false,"mountpoints":[null],"children":[]}
]}
JSON
declare -A found=()
storage::discover_candidates found || { echo 'FAIL: discovery'; exit 1; }
[[ ${found[candidate_count]} == 3 ]]
[[ ${found[0.device_path]} == /dev/nvme0n1 ]]
[[ ${found[0.has_mounted_descendant]} == yes ]]
[[ ${found[0.stable_id_kind]} == wwn ]]
[[ ${found[1.removable]} == true ]]
[[ ${found[2.stable_id_kind]} == none ]]
echo 'PASS: discovers whole-disk candidates and records identity/safety facts'

declare -A valid_target=([device_path]=/dev/nvme0n1 [size_bytes]=256000000000 [wwn]=eui.001)
if storage::validate_target valid_target; then
  echo 'FAIL: mounted target accepted'; exit 1
fi
echo 'PASS: rejects target with mounted descendant'

cat >"$K41_LSBLK_FIXTURE" <<'JSON'
{"blockdevices":[
 {"name":"/dev/nvme0n1","type":"disk","size":256000000000,"model":"WDC PC SN730","tran":"nvme","wwn":"eui.001","serial":"SN001","rm":false,"ro":false,"mountpoints":[null],"children":[]}
]}
JSON
storage::validate_target valid_target || { echo 'FAIL: safe stable target rejected'; exit 1; }
echo 'PASS: validates unchanged non-removable, writable target with stable WWN'

declare -A no_stable_id=([device_path]=/dev/sdb [size_bytes]=64000000000)
if storage::validate_target no_stable_id; then
  echo 'FAIL: accepted target without stable identity'; exit 1
fi
echo 'PASS: rejects target without stable identity'

declare -a indexed=()
if storage::discover_candidates indexed; then
  echo 'FAIL: accepted indexed array'; exit 1
fi
echo 'PASS: rejects invalid output array'

printf '%s\n' 'All storage discovery tests passed.'
