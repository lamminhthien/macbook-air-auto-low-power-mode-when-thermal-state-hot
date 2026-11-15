#!/usr/bin/env bash
# thermal-lpm: turn Low Power Mode on when the Mac heats up and off when it cools down.
#
# Usage:
#   sudo ./thermal-lpm.sh                  # run with default thresholds
#   sudo ./thermal-lpm.sh --on 1 --off 0   # custom thresholds
#   ./thermal-lpm.sh --probe               # print current thermal level and LPM state
set -euo pipefail

KEY="com.apple.system.thermalpressurelevel"
ON_LEVEL=1        # enable LPM when level >= this value
OFF_LEVEL=0       # disable LPM when level <= this value
INTERVAL=10       # seconds between checks
MIN_HOLD=60       # minimum seconds between two LPM changes

PROBE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --on)       ON_LEVEL="$2"; shift 2 ;;
    --off)      OFF_LEVEL="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --hold)     MIN_HOLD="$2"; shift 2 ;;
    --probe)    PROBE=1; shift ;;
    -h|--help)  sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Invalid option: $1" >&2; exit 1 ;;
  esac
done

thermal_level() {
  # notifyutil -g prints a line ending with the state number; take that number.
  # "|| true" keeps the script alive if the key is missing.
  notifyutil -g "$KEY" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || true
}

lpm_state() {
  pmset -g | awk '/lowpowermode/ {print $2; exit}'
}

set_lpm() {
  pmset -a lowpowermode "$1"
}

if [[ $PROBE -eq 1 ]]; then
  echo "Thermal pressure level: $(thermal_level)"
  echo "Current Low Power Mode: $(lpm_state)"
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo to change Low Power Mode." >&2
  exit 1
fi

ORIGINAL_LPM="$(lpm_state || true)"
if [[ "$ORIGINAL_LPM" != "0" && "$ORIGINAL_LPM" != "1" ]]; then
  echo "Cannot read Low Power Mode state; this Mac may not support it." >&2
  exit 1
fi
LAST_CHANGE=0

restore() {
  trap - EXIT
  echo
  echo "Stopping. Restoring Low Power Mode to: $ORIGINAL_LPM"
  set_lpm "$ORIGINAL_LPM" || true
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Started. Enable LPM at level >= $ON_LEVEL, disable at level <= $OFF_LEVEL. Press Ctrl+C to stop."

while true; do
  level="$(thermal_level)"
  current="$(lpm_state)"
  now="$(date +%s)"

  if [[ -n "$level" ]]; then
    if (( now - LAST_CHANGE >= MIN_HOLD )); then
      if (( level >= ON_LEVEL )) && [[ "$current" != "1" ]]; then
        set_lpm 1
        LAST_CHANGE=$now
        echo "$(date '+%H:%M:%S') level=$level -> Low Power Mode ON"
      elif (( level <= OFF_LEVEL )) && [[ "$current" == "1" ]]; then
        set_lpm 0
        LAST_CHANGE=$now
        echo "$(date '+%H:%M:%S') level=$level -> Low Power Mode OFF"
      fi
    fi
  fi

  sleep "$INTERVAL"
done
