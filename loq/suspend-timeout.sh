#!/usr/bin/env bash

logger -t suspend-timeout "Hook called: ${1:-} ${2:-}"
set -u

STATE="/run/suspend-timeout.timestamp"
LIMIT=21600
RTC=/dev/rtc0

case "${1:-}" in
pre)
  [[ "${2:-}" == "suspend" ]] || exit 0

  if grep -q '^alarm: on ' <(rtcwake -d "$RTC" -m show 2>/dev/null); then
    logger -t suspend-timeout "RTC alarm already in use, skipping"
    exit 0
  fi

  date +%s >"$STATE"

  if ! rtcwake -d "$RTC" -m no -s "$LIMIT"; then
    rm -f "$STATE"
    logger -t suspend-timeout "Cannot configure RTC wake"
  fi
  ;;

post)
  [[ "${2:-}" == "suspend" ]] || exit 0
  [[ -f "$STATE" ]] || exit 0

  START=$(cat "$STATE")
  NOW=$(date +%s)
  ELAPSED=$((NOW - START))

  rm -f "$STATE"

  rtcwake -d "$RTC" -m disable || true

  if ((ELAPSED >= LIMIT)); then
    logger -t suspend-timeout \
      "Suspend timeout reached; scheduling poweroff"

    systemd-run \
      --unit=suspend-timeout-poweroff \
      --on-active=15s \
      /usr/bin/systemctl poweroff
  else
    logger -t suspend-timeout \
      "Resumed after ${ELAPSED}s; shutdown cancelled"
  fi
  ;;
esac

exit 0
