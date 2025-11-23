#!/bin/bash

set -e

BASE_DIR="/home/pi/piproxy"
VENV_DIR="$BASE_DIR/venv"

echo "Updating system..."
sudo apt-get update -y

echo "Installing required packages..."
sudo apt-get install -y usb-modeswitch python3 python3-pip python3-venv python3-full

echo "Installing 3proxy..."
git clone https://github.com/z3apa3a/3proxy /tmp/3proxy-src
cd /tmp/3proxy-src
ln -sf Makefile.Linux Makefile
make -j$(nproc)
sudo make install
cd -

echo "Disabling system 3proxy service..."
sudo systemctl stop 3proxy.service 2>/dev/null || true
sudo systemctl disable 3proxy.service 2>/dev/null || true
sudo rm -f /etc/3proxy/3proxy.cfg

echo "Installing custom 3proxy config into piproxy directory..."
mkdir -p "$BASE_DIR"
sudo install -m644 3proxy.cfg "$BASE_DIR/3proxy.cfg"
sudo chown pi:pi "$BASE_DIR/3proxy.cfg"

echo "Installing startproxy.sh..."
sudo cp ./startproxy.sh "$BASE_DIR/startproxy.sh"
sudo chmod +x "$BASE_DIR/startproxy.sh"
sudo chown pi:pi "$BASE_DIR/startproxy.sh"

echo "Setting up udev rules..."
sudo cp ./40-huawei.rules /etc/udev/rules.d/40-huawei.rules
sudo usb_modeswitch -v 3566 -p 2001 -X
sudo udevadm control --reload-rules

echo "Creating Python virtual environment in piproxy..."
python3 -m venv "$VENV_DIR"

echo "Installing Python packages..."
"$VENV_DIR/bin/pip" install huawei_lte_api rich requests

echo "Making Python scripts venv-aware..."
for script in reset_ip.py modem_status.py; do
    sed -i "1i\
#!/usr/bin/env python3\n\
import sys\nimport os\nVENV_PATH='$VENV_DIR'\n\
if sys.prefix != VENV_PATH:\n\
    activate_this = os.path.join(VENV_PATH, 'bin', 'activate_this.py')\n\
    if os.path.exists(activate_this):\n\
        with open(activate_this) as f: exec(f.read(), dict(__file__=activate_this))\n" \
    "$BASE_DIR/$script"

    chmod +x "$BASE_DIR/$script"
    sudo chown pi:pi "$BASE_DIR/$script"
done

echo "Installing systemd startup service..."
sudo bash -c "cat >/etc/systemd/system/piproxy-start.service" << 'EOF'
[Unit]
Description=PiProxy Startup Script
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/pi/piproxy/startproxy.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable piproxy-start.service

echo "Installation complete! Reboot system."
