#!/usr/bin/env bash
# Parses captured adb dumps through bin/orbit-status and asserts the JSON.
set -u
cd "$(dirname "$0")"
fail=0

# Never touch the real cache or saved Wi-Fi address.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CACHE_HOME="$tmp/cache" XDG_CONFIG_HOME="$tmp/config"
fake() { PATH="$PWD/fake-adb:$PATH" FAKE_ADB_LOG="$tmp/adb.log" ORBIT_TIMEOUT=1 "$@"; }

assert() {  # $1 name, $2 json, $3 jq assertion
  if jq -e "$3" <<<"$2" >/dev/null; then
    echo "ok   $1"
  else
    echo "FAIL $1: $3"; echo "     $2"; fail=1
  fi
}

check() {  # $1 fixture, $2 jq assertion
  assert "$1" "$(ORBIT_RAW="fixtures/$1" ../bin/orbit-status)" "$2"
}

# Sleeping Wi-Fi headset, nothing cached yet: must time out as offline and drop
# the dead transport, not hang.
start=$SECONDS
out=$(fake ../bin/orbit-status)
if [ "$out" = '{"state":"offline","transport":"wifi"}' ] && grep -qx 'disconnect 10.0.0.9:5555' "$tmp/adb.log" && (( SECONDS - start < 5 )); then
  echo "ok   asleep-wifi-timeout"
else
  echo "FAIL asleep-wifi-timeout: $out ($((SECONDS - start))s) $(cat "$tmp/adb.log" 2>/dev/null)"; fail=1
fi

# Real Quest 3S captures (serials redacted). Both controller paths must agree.
real='.state == "connected" and (.stale | not) and (.seen | type) == "number"
  and .model == "Quest 3S" and .os == "209" and .ip == "192.168.1.50"
  and .headset == {level: 82, charging: false, status: "Discharging", temp: 33, plug: "AC", worn: "Worn"}
  and .left == {level: 100, status: "Idle"} and .right == {level: 100, status: "Idle"}'
check quest3s-remote.txt "$real"
check quest3s-rstest.txt "$real"

# The last good reading (quest3s-rstest) is cached and shown, marked stale, once
# the headset sleeps or goes away.
seen=$(jq .seen "$XDG_CACHE_HOME/orbit-linux/last.json")
stale=".stale and .seen == $seen and .headset.level == 82 and .left.level == 100 and .right.level == 100"
assert asleep-shows-last "$(fake ../bin/orbit-status)" ".state == \"offline\" and .transport == \"wifi\" and $stale"
assert gone-shows-last "$(FAKE_ADB_DEVICES= fake ../bin/orbit-status)" ".state == \"disconnected\" and .transport == null and $stale"

# Hand-made: charging over USB, one controller asleep, one disconnected (-1%), no Horizon build prop.
check synthetic-charging.txt '.os == "78.0" and .ip == "192.168.1.42"
  and .headset == {level: 89, charging: true, status: "Charging", temp: 34, plug: "USB", worn: "Standby"}
  and .left == {level: 60, status: "Asleep"} and .right == {level: null, status: "Asleep"}'

exit $fail
