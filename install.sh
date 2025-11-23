#!/bin/bash
set -e

BASE_DIR="/home/pi/piproxy"
VENV_DIR="$BASE_DIR/venv"

echo "=== Updating system ==="
sudo apt-get update -y

echo "=== Installing required packages ==="
sudo apt-get install -y usb-modeswitch python3 python3-pip python3-venv python3-full git build-essential

echo "=== Installing 3proxy from source ==="
sudo rm -rf /tmp/3proxy-src
git clone https://github.com/z3apa3a/3proxy /tmp/3proxy-src
cd /tmp/3proxy-src
ln -sf Makefile.Linux Makefile
make -j"$(nproc)"
sudo make install
cd -

echo "=== Disabling default 3proxy service ==="
sudo systemctl stop 3proxy.service 2>/dev/null || true
sudo systemctl disable 3proxy.service 2>/dev/null || true
sudo rm -f /etc/3proxy/3proxy.cfg 2>/dev/null || true

echo "=== Creating piproxy directory ==="
mkdir -p "$BASE_DIR"
sudo chown pi:pi "$BASE_DIR"

echo "=== Installing 3proxy.cfg ==="
sudo install -m644 ./3proxy.cfg "$BASE_DIR/3proxy.cfg"
sudo chown pi:pi "$BASE_DIR/3proxy.cfg"

echo "=== Installing startproxy.sh ==="
sudo bash -c "cat >$BASE_DIR/startproxy.sh" << 'EOF'
#!/bin/bash
echo "Starting 3proxy..."
/usr/bin/3proxy /home/pi/piproxy/3proxy.cfg
EOF

sudo chmod +x "$BASE_DIR/startproxy.sh"
sudo chown pi:pi "$BASE_DIR/startproxy.sh"

echo "=== Installing udev rules for Huawei modems ==="
sudo cp ./40-huawei.rules /etc/udev/rules.d/40-huawei.rules
sudo usb_modeswitch -v 3566 -p 2001 -X || true
sudo udevadm control --reload-rules

echo "=== Creating Python virtual environment ==="
python3 -m venv "$VENV_DIR"

echo "=== Installing Python packages into venv ==="
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install huawei_lte_api rich requests

echo "=== Installing Python utility scripts ==="
for script in reset_ip.py modem_status.py; do
    sudo install -m755 "./$script" "$BASE_DIR/$script"
    sudo chown pi:pi "$BASE_DIR/$script"
done

echo "=== Creating systemd service piproxy.service ==="
sudo bash -c "cat >/etc/systemd/system/piproxy.service" << EOF
[Unit]
Description=PiProxy - 3proxy with automatic modem interfaces
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$BASE_DIR

# Ensure Python scripts use the private venv
Environment=PATH=$VENV_DIR/bin:/usr/bin:/bin

ExecStart=$BASE_DIR/startproxy.sh

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Enabling and starting piproxy.service ==="
sudo systemctl daemon-reload
sudo systemctl enable piproxy.service
sudo systemctl restart piproxy.service

echo "=== Installation complete! ==="
echo "3proxy should now start automatically on boot."
