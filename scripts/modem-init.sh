#!/usr/bin/env bash
LOG=/var/log/modem-init.log
exec >>"$LOG" 2>&1

echo "=== $(date +'%F %T') modem-init start ==="

CONF=/etc/modem_macs.conf
declare -A MAP

if [[ ! -f "$CONF" ]]; then
  echo "Missing $CONF"
  exit 1
fi

while read -r mac name; do
  [[ -z "$mac" || "$mac" == \#* ]] && continue
  mac=$(echo "$mac" | tr 'A-F' 'a-f')
  MAP["$mac"]="$name"
done < "$CONF"

END=$((SECONDS + 30))
while (( SECONDS < END )); do
  for IF in $(ls /sys/class/net | grep -E '^usb|^wwan|^rndis|^cdc' || true); do
    mac=$(cat /sys/class/net/$IF/address 2>/dev/null | tr 'A-F' 'a-f')
    if [[ -n "${MAP[$mac]:-}" ]]; then
      target="${MAP[$mac]}"
      if [[ "$IF" != "$target" ]]; then
        echo "Renaming $IF → $target (MAC $mac)"
        ip link set "$IF" down || true
        ip link set "$IF" name "$target" || true
        ip link set "$target" up || true
      fi
    fi
  done
  sleep 1
done

echo "=== modem-init done ==="
exit 0
