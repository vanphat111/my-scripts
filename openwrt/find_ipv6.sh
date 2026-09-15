#!/bin/sh

[ -z "$1" ] && exit 1

TARGET_MAC=$(echo "$1" | tr '[:upper:]' '[:lower:]')
IFACE="${2:-eth0}"

ping6 -c 2 -W 1 ff02::1%"$IFACE" >/dev/null 2>&1

PUBLIC_IP=$(ip -6 neigh show dev "$IFACE" | grep -i "$TARGET_MAC" | awk '{print $1}' | grep -E '^[23]')

if [ -z "$PUBLIC_IP" ] && [ -f /tmp/hosts/odhcpd ]; then
  PUBLIC_IP=$(grep -i "$TARGET_MAC" /tmp/hosts/odhcpd | awk '{print $1}' | grep -E '^[23]')
fi

if [ -z "$PUBLIC_IP" ]; then
  PREFIX=$(ip -6 addr show dev "$IFACE" scope global | grep -v ' fdf0:' | grep 'inet6 2' | awk '{print $2}' | cut -d'/' -f1 | head -n1 | cut -d: -f1-4)

  if [ -n "$PREFIX" ]; then
    m1=$(echo "$TARGET_MAC" | cut -d: -f1)
    m2=$(echo "$TARGET_MAC" | cut -d: -f2)
    m3=$(echo "$TARGET_MAC" | cut -d: -f3)
    m4=$(echo "$TARGET_MAC" | cut -d: -f4)
    m5=$(echo "$TARGET_MAC" | cut -d: -f5)
    m6=$(echo "$TARGET_MAC" | cut -d: -f6)

    m1_hex=$(printf "%02x" $((0x$m1 ^ 2)))
    PUBLIC_IP="${PREFIX}:${m1_hex}${m2}:${m3}ff:fe${m4}:${m5}${m6}"
  fi
fi

if [ -n "$PUBLIC_IP" ]; then
  echo "$PUBLIC_IP"
fi
