#!/bin/bash
set -euo pipefail

LOG="/var/log/pi-proxy-install.log"
exec > >(tee -a "$LOG") 2>&1

echo "Log: $LOG"
echo "Starting installation..."


echo "[1] Updating package list..."
sudo apt-get update -y


echo "[2] Installing required packages..."
sudo apt-get install -y usb-modeswitch curl udev


USE_PREBUILT=true

if $USE_PREBUILT; then
  echo "[3] Installing prebuilt 3proxy..."

  sudo mkdir -p /usr/local/3proxy
  sudo curl -L -o /usr/local/3proxy/3proxy \
    https://raw.githubusercontent.com/z3apa3a/3proxy/master/bin/3proxy

  sudo chmod +x /usr/local/3proxy/3proxy

else
  echo "[3] Compiling 3proxy from source (slow)..."

  sudo apt-get install -y build-essential

  git clone https://github.com/z3apa3a/3proxy || true
  cd 3proxy
  ln -sf Makefile.Linux Makefile
  make -j$(nproc)
  sudo make install
  cd ..
fi


echo "[4] Installing proxy configs..."

sudo install -m 644 ./3proxy.cfg /etc/3proxy.cfg
sudo install -m 755 ./startproxy.sh /usr/local/bin/startproxy
sudo sed -i 's/\r$//' /usr/local/bin/startproxy   # ensure no CRLF


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
ExecStart=/usr/local/bin/startproxy
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
echo "Reboot recommended."
