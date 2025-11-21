#!/usr/bin/env bash
set -eu

DEVNAME="${1:-}"
LOG=/var/log/modeswitch-wrapper.log

exec >>"$LOG" 2>&1
echo "=== $(date +'%F %T') modeswitch-wrapper called for ${DEVNAME} ==="

USB_VENDOR="3566"
USB_PRODUCT="2001"
MAX_TRIES=6
SLEEP_BETWEEN=2

do_modeswitch() {
  local mode="$1"
  case "$mode" in
    J) /usr/sbin/usb_modeswitch -v $USB_VENDOR -p $USB_PRODUCT -J -W -R || true ;;
    X) /usr/sbin/usb_modeswitch -v $USB_VENDOR -p $USB_PRODUCT -X -W -R || true ;;
    S) /usr/sbin/usb_modeswitch -v $USB_VENDOR -p $USB_PRODUCT -S -W -R || true ;;
    R) /usr/sbin/usb_modeswitch -v $USB_VENDOR -p $USB_PRODUCT -R || true ;;
  esac
  sleep $SLEEP_BETWEEN
}

attempt=1
while (( attempt <= MAX_TRIES )); do
  echo "Attempt $attempt for $DEVNAME"

  for method in J X S; do
    do_modeswitch "$method"

    if lsusb -t | grep -qiE "Class=(Wireless|CDC|Communications)"; then
      echo "Device switched successfully."
      exit 0
    fi
  done

  # Hard re-enumeration if still stuck
  if [[ -d "/sys/bus/usb/devices/${DEVNAME}" ]]; then
    echo "Re-enumerating $DEVNAME via unbind/bind"
    if [ -w "/sys/bus/usb/devices/${DEVNAME}/driver/unbind" ]; then
      echo -n "$DEVNAME" > "/sys/bus/usb/devices/${DEVNAME}/driver/unbind" || true
      sleep 0.5
      echo -n "$DEVNAME" > "/sys/bus/usb/drivers/usb/bind" || true
      sleep $SLEEP_BETWEEN
    fi
  fi

  attempt=$((attempt + 1))
done

echo "Switch attempts exhausted."
exit 0
