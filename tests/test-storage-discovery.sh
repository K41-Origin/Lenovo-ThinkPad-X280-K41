#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/storage.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/lsblk" <<'MOCK'
#!/usr/bin/env bash
[[ ${K41_LSBLK_FAIL:-0} == 0 ]] || exit 9
cat "${K41_LSBLK_FIXTURE:?}"
MOCK
cat >"$tmp/bin/swapon" <<'MOCK'
#!/usr/bin/env bash
[[ ${K41_SWAPON_FAIL:-0} == 0 ]] || exit 9
cat "${K41_SWAP_FIXTURE:?}"
MOCK
cat >"$tmp/bin/jq" <<'MOCK'
#!/usr/bin/env bash
exec /usr/bin/jq "$@"
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
export K41_LSBLK_FIXTURE="$tmp/devices.json"
export K41_SWAP_FIXTURE="$tmp/swaps.txt"
: >"$K41_SWAP_FIXTURE"

write_safe_fixture() {
  cat >"$K41_LSBLK_FIXTURE" <<'JSON'
{"blockdevices":[
 {"name":"/dev/nvme0n1","type":"disk","size":256000000000,"model":"WDC PC SN730","tran":"nvme","wwn":"eui.001","serial":"SN001","rm":false,"ro":false,"mountpoints":[null],"children":[
  {"name":"/dev/nvme0n1p1","type":"part","size":1073741824,"mountpoints":[null]},
  {"name":"/dev/nvme0n1p2","type":"part","size":255000000000,"mountpoints":[null],
   "children":[{"name":"/dev/mapper/cryptroot","type":"crypt","mountpoints":[null]}]}
 ]},
 {"name":"/dev/sda","type":"disk","size":32000000000,"model":"USB","tran":"usb","wwn":null,"serial":"USB001","rm":true,"ro":false,"mountpoints":[null],"children":[]}
]}
JSON
}
write_safe_fixture

declare -A found=()
storage::discover_candidates found || { echo 'FAIL: discovery'; exit 1; }
[[ ${found[candidate_count]} == 2 ]]
[[ ${found[0.device_path]} == /dev/nvme0n1 ]]
[[ ${found[0.stable_id_kind]} == wwn ]]
[[ ${found[1.removable]} == true ]]
echo 'PASS: discovers disks and records identity and safety facts'

declare -A target=([device_path]=/dev/nvme0n1 [size_bytes]=256000000000 [wwn]=eui.001 [serial]=SN001)
storage::validate_target target || { echo 'FAIL: valid internal NVMe rejected'; exit 1; }
echo 'PASS: accepts unchanged internal NVMe with matching WWN and serial'

# Any mounted descendant, including a mapper below a partition, blocks erasure.
sed -i 's/"mountpoints":\[null\]}/"mountpoints":["\/"]}/' "$K41_LSBLK_FIXTURE"
if storage::validate_target target; then echo 'FAIL: mounted target accepted'; exit 1; fi
echo 'PASS: rejects mounted descendants'
write_safe_fixture

# Active swap partition is checked independently of mountpoints.
printf '%s\n' /dev/nvme0n1p2 >"$K41_SWAP_FIXTURE"
if storage::validate_target target; then echo 'FAIL: active swap target accepted'; exit 1; fi
echo 'PASS: rejects active swap descendants'
: >"$K41_SWAP_FIXTURE"

# A removable or non-NVMe disk cannot be accepted as the target.
declare -A usb=([device_path]=/dev/sda [size_bytes]=32000000000 [serial]=USB001)
if storage::validate_target usb; then echo 'FAIL: removable USB target accepted'; exit 1; fi
echo 'PASS: rejects removable USB target'

# Duplicate stable identity makes the entire discovery ambiguous.
python3 - "$K41_LSBLK_FIXTURE" <<'PY'
import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["blockdevices"].append(dict(d["blockdevices"][0], name="/dev/nvme1n1"))
json.dump(d,open(p,"w"))
PY
if storage::discover_candidates found; then echo 'FAIL: duplicate WWN accepted'; exit 1; fi
echo 'PASS: rejects duplicate WWN'
write_safe_fixture

# Both identity fields supplied by the caller must still match.
declare -A bad=([device_path]=/dev/nvme0n1 [size_bytes]=256000000000 [wwn]=eui.001 [serial]=CHANGED)
if storage::validate_target bad; then echo 'FAIL: changed serial accepted'; exit 1; fi
echo 'PASS: rejects changed secondary identity'

# Missing required safety state and failed discovery tools fail closed.
python3 - "$K41_LSBLK_FIXTURE" <<'PY'
import json,sys
p=sys.argv[1]
d=json.load(open(p)); del d["blockdevices"][0]["rm"]
json.dump(d,open(p,"w"))
PY
if storage::discover_candidates found; then echo 'FAIL: unknown removable state accepted'; exit 1; fi
echo 'PASS: rejects unknown safety state'
write_safe_fixture
export K41_SWAPON_FAIL=1
if storage::discover_candidates found; then echo 'FAIL: swapon failure accepted'; exit 1; fi
unset K41_SWAPON_FAIL
echo 'PASS: fails closed when swap discovery fails'
export K41_LSBLK_FAIL=1
if storage::discover_candidates found; then echo 'FAIL: lsblk failure accepted'; exit 1; fi
unset K41_LSBLK_FAIL
echo 'PASS: fails closed when lsblk fails'

declare -a indexed=()
if storage::discover_candidates indexed; then echo 'FAIL: accepted indexed array'; exit 1; fi
echo 'PASS: rejects invalid output array'
printf '%s\n' 'All storage discovery tests passed.'
