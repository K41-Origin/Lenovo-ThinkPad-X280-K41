#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/storage.sh"

# Isolate target-validation integration from the host's real /sys and /proc.
# The topology algorithm itself is exercised with synthetic fixtures separately.
storage::topology_check_target() {
  [[ $# -eq 4 && $1 == 259:0 && $2 == /sys && $3 == /proc/self/mountinfo && $4 == /proc/swaps ]] || return 2
  [[ ${K41_TOPOLOGY_FAIL:-0} == 0 ]]
}
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
 {"name":"/dev/nvme0n1","maj:min":"259:0","type":"disk","size":256000000000,"model":"WDC PC SN730","tran":"nvme","wwn":"eui.001","serial":"SN001","rm":false,"ro":false,"mountpoints":[null],"children":[
  {"name":"/dev/nvme0n1p1","type":"part","size":1073741824,"mountpoints":[null]},
  {"name":"/dev/nvme0n1p2","type":"part","size":255000000000,"mountpoints":[null],
   "children":[{"name":"/dev/mapper/cryptroot","type":"crypt","mountpoints":[null]}]}
 ]},
 {"name":"/dev/sda","maj:min":"8:0","type":"disk","size":32000000000,"model":"USB","tran":"usb","wwn":null,"serial":"USB001","rm":true,"ro":false,"mountpoints":[null],"children":[]}
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

# A removable SD/MMC reader may enumerate with zero capacity. Skip it rather
# than aborting discovery or treating it as an installable candidate.
python3 - "$K41_LSBLK_FIXTURE" <<'PY'
import json,sys
p=sys.argv[1]
with open(p) as f: d=json.load(f)
d["blockdevices"].append({
    "name":"/dev/sdb","maj:min":"8:16","type":"disk","size":0,
    "model":"SD/MMC","tran":"usb","wwn":None,"serial":"READER001",
    "rm":True,"ro":False,"mountpoints":[None],"children":[]
})
with open(p,"w") as f: json.dump(d,f)
PY
storage::discover_candidates found || { echo 'FAIL: zero-capacity removable reader aborted discovery'; exit 1; }
[[ ${found[candidate_count]} == 2 ]]
echo 'PASS: skips zero-capacity removable reader without exposing it as a candidate'

# A zero-capacity non-removable disk is ambiguous and must fail closed.
python3 - "$K41_LSBLK_FIXTURE" <<'PY'
import json,sys
p=sys.argv[1]
with open(p) as f: d=json.load(f)
d["blockdevices"].append({
    "name":"/dev/nvme1n1","maj:min":"259:16","type":"disk","size":0,
    "model":"Unknown","tran":"nvme","wwn":"eui.zero","serial":"ZERO001",
    "rm":False,"ro":False,"mountpoints":[None],"children":[]
})
with open(p,"w") as f: json.dump(d,f)
PY
if storage::discover_candidates found; then echo 'FAIL: zero-capacity non-removable disk accepted'; exit 1; fi
echo 'PASS: rejects zero-capacity non-removable disk'
write_safe_fixture

# Missing/invalid size remains a discovery error even for removable devices.
python3 - "$K41_LSBLK_FIXTURE" <<'PY'
import json,sys
p=sys.argv[1]
with open(p) as f: d=json.load(f)
d["blockdevices"][1]["size"]=None
with open(p,"w") as f: json.dump(d,f)
PY
if storage::discover_candidates found; then echo 'FAIL: unknown disk size accepted'; exit 1; fi
echo 'PASS: rejects unknown disk size'
write_safe_fixture

declare -A target=([device_path]=/dev/nvme0n1 [size_bytes]=256000000000 [wwn]=eui.001 [serial]=SN001)
storage::validate_target target || { echo 'FAIL: valid internal NVMe rejected'; exit 1; }
echo 'PASS: accepts unchanged internal NVMe with matching WWN and serial and invokes topology validation'

export K41_TOPOLOGY_FAIL=1
if storage::validate_target target; then echo 'FAIL: topology validation failure was ignored'; exit 1; fi
unset K41_TOPOLOGY_FAIL
echo 'PASS: blocks target when topology validation fails'

# Any mounted descendant, including a mapper below a partition, blocks erasure.
sed -i 's/"mountpoints":\[null\]}/"mountpoints":["\/"]}/' "$K41_LSBLK_FIXTURE"
if storage::validate_target target; then echo 'FAIL: mounted target accepted'; exit 1; fi
echo 'PASS: rejects mounted descendants'
write_safe_fixture

# Active swap partition is checked independently of mountpoints.
printf '%s\n' /dev/nvme0n1p2 >"$K41_SWAP_FIXTURE"
if storage::validate_target target; then echo 'FAIL: active swap target accepted'; exit 1; fi
echo 'PASS: rejects active swap descendants'
ln -s /dev/nvme0n1p2 "$tmp/swap-alias"
printf '%s\n' "$tmp/swap-alias" >"$K41_SWAP_FIXTURE"
if storage::validate_target target; then echo 'FAIL: aliased active swap target accepted'; exit 1; fi
echo 'PASS: rejects active swap device aliases'
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
