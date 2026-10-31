#!/usr/bin/env bash
# Parses captured adb dumps through bin/orbit-status and asserts the JSON.
set -u
cd "$(dirname "$0")"
fail=0

check() {  # $1 fixture, $2 jq assertion
  out=$(ORBIT_RAW="fixtures/$1" ../bin/orbit-status)
  if jq -e "$2" <<<"$out" >/dev/null; then
    echo "ok   $1"
  else
    echo "FAIL $1: $2"; echo "     $out"; fail=1
  fi
}

check remote.txt '.state == "connected" and .model == "Quest 3S" and .os == "78.0" and .ip == "192.168.1.42"
  and .headset == {level: 89, charging: true, status: "Charging", temp: 34, plug: "USB", worn: "Standby"}
  and .left == {level: 60, status: "Asleep"} and .right == {level: null, status: "Searching"}'

check rstest.txt '.os == "UP1A.231005.007.A1" and .ip == null
  and .headset == {level: 41, charging: false, status: "Discharging", temp: 31.2, plug: null, worn: null}
  and .left == {level: 92, status: "Active"} and .right == {level: 40, status: "Asleep"}'

exit $fail
