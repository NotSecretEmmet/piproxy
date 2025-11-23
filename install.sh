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

echo "Installing 3proxy..."
git clone https://github.com/z3apa3a/3proxy /tmp/3proxy-src
cd /tmp/3proxy-src
ln -sf Makefile.Linux Makefile
make -j$(nproc)
sudo make install
cd -
sleep 2

echo "Disabling system 3proxy service..."
sudo systemctl stop 3proxy.service 2>/dev/null
sudo systemctl disable 3proxy.service 2>/dev/null
# Remove default config so systemd cannot start it even by accident
sudo rm -f /etc/3proxy/3proxy.cfg


# Setup 3proxy custom config
echo "Setting up 3proxy..."
sudo install -m644 3proxy.cfg /home/pi/3proxy.cfg
sudo chown pi:pi /home/pi/3proxy.cfg

# Copy config
sudo install -m 644 ./3proxy.cfg /usr/local/3proxy/conf/3proxy.cfg

# Minimal start script (waits for usb0)
sudo tee /usr/local/bin/startproxy >/dev/null <<'EOF'
#!/bin/bash
# Wait until usb0 exists
while ! ip link show usb0 >/dev/null 2>&1; do
  echo "Waiting for usb0..."
  sleep 2
done

exec /usr/bin/3proxy /usr/local/3proxy/conf/3proxy.cfg
EOF
sudo chmod +x /usr/local/bin/startproxy

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
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable piproxy-start.service

echo "Installation complete! Reboot system."
