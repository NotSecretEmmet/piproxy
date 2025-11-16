#!/bin/bash
set -euo pipefail

LOG="/var/log/pi-proxy-install.log"
sudo touch "$LOG"
sudo chmod 644 "$LOG"
exec > >(sudo tee -a "$LOG") 2>&1

echo "Log: $LOG"
echo "Starting installation..."


echo "[1] Updating package list..."
sudo apt-get update -y


echo "[2] Installing required packages..."
sudo apt-get install -y usb-modeswitch curl wget udev


echo "[3] Installing 3proxy (official ARM64 Debian package)..."

TMP_DEB="/tmp/3proxy.deb"
wget -q https://github.com/3proxy/3proxy/releases/download/0.9.5/3proxy-0.9.5.aarch64.deb -O "$TMP_DEB"

sudo apt-get install -y "$TMP_DEB"
rm "$TMP_DEB"

echo "3proxy installed at: /usr/bin/3proxy"


echo "[4] Installing proxy configs..."

sudo mkdir -p /usr/local/3proxy/conf
sudo mkdir -p /usr/local/3proxy/logs

sudo install -m 644 ./3proxy.cfg /usr/local/3proxy/conf/3proxy.cfg

sudo install -m 755 ./startproxy.sh /usr/local/bin/startproxy
sudo sed -i 's/\r$//' /usr/local/bin/startproxy


echo "[5] Installing udev rules..."

sudo install -m 644 ./40-huawei.rules /etc/udev/rules.d/40-huawei.rules
sudo udevadm control --reload-rules


echo "[6] Creating systemd service..."

sudo tee /etc/systemd/system/3proxy.service >/dev/null <<EOF
[Unit]
Description=3Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/3proxy /usr/local/3proxy/conf/3proxy.cfg
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable 3proxy.service


echo "[7] Applying usb_modeswitch for Huawei (3566:2001)..."
sudo usb_modeswitch -v 3566 -p 2001 -X || \
  echo "Modeswitch may already be applied or handled by udev."


echo "=== Installation Complete ==="
echo "Start proxy now with: sudo systemctl start 3proxy"
echo "View logs: sudo journalctl -u 3proxy -f"
echo "Reboot recommended."
