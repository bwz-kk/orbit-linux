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

# Real Quest 3S captures (serials redacted). Both controller paths must agree.
real='.state == "connected" and .model == "Quest 3S" and .os == "209" and .ip == "192.168.1.50"
  and .headset == {level: 82, charging: false, status: "Discharging", temp: 33, plug: "AC", worn: "Worn"}
  and .left == {level: 100, status: "Idle"} and .right == {level: 100, status: "Idle"}'
check quest3s-rstest.txt "$real"
check quest3s-remote.txt "$real"

# Hand-made: charging over USB, one controller asleep, one disconnected (-1%), no Horizon build prop.
check synthetic-charging.txt '.os == "78.0" and .ip == "192.168.1.42"
  and .headset == {level: 89, charging: true, status: "Charging", temp: 34, plug: "USB", worn: "Standby"}
  and .left == {level: 60, status: "Asleep"} and .right == {level: null, status: "Asleep"}'

exit $fail
