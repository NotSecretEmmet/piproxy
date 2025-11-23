#!/bin/bash

# Update and upgrade system packages
echo "Updating system..."
sudo apt-get update -y

# Install necessary packages
echo "Installing required packages..."
sudo apt-get install -y usb-modeswitch

echo "Installing 3proxy..."
git clone https://github.com/z3apa3a/3proxy /tmp/3proxy-src
cd /tmp/3proxy-src
ln -sf Makefile.Linux Makefile
make -j$(nproc)
sudo make install
cd -
sleep 2

###########################
# Disable default 3proxy service
###########################
echo "Disabling system 3proxy service..."
sudo systemctl stop 3proxy.service 2>/dev/null
sudo systemctl disable 3proxy.service 2>/dev/null

# Remove default config so systemd cannot start it even by accident
sudo rm -f /etc/3proxy/3proxy.cfg

###########################

# Setup 3proxy custom config
echo "Setting up 3proxy..."
sudo install -m644 3proxy.cfg /home/pi/3proxy.cfg
sudo chown pi:pi /home/pi/3proxy.cfg

# Setup the startproxy.sh script
echo "Creating startup script..."
sudo cp ./startproxy.sh /home/pi/startproxy.sh
sudo chmod +x /home/pi/startproxy.sh

# Configure udev rules for Huawei dongle
echo "Setting up udev rules..."
sudo cp ./40-huawei.rules /etc/udev/rules.d/40-huawei.rules

cudo usb_modeswitch -v 3566 -p 2001 -X

sudo udevadm control --reload-rules

echo "Setting up Python environment..."
sudo apt-get install -y python3 python3-pip python3-venv python3-full

# Create virtual environment
python3 -m venv /home/pi/pienv

# Install required packages inside venv
/home/pi/pienv/bin/pip install huawei_lte_api rich requests

# Set paths
BASE_DIR="/home/pi/piproxy"
VENV_DIR="/home/pi/pienv"

# Make Python scripts venv-aware and executable
for script in reset_ip.py modem_status.py; do
    # Insert venv activation at the top
    sed -i "1i\
import sys\nimport os\nVENV_PATH='$VENV_DIR'\nif sys.prefix != VENV_PATH:\n    activate_this = os.path.join(VENV_PATH, 'bin', 'activate_this.py')\n    if os.path.exists(activate_this):\n        with open(activate_this) as f: exec(f.read(), dict(__file__=activate_this))\n" $BASE_DIR/$script

    # Make executable
    chmod +x $BASE_DIR/$script
done

echo "Installing simple startup service..."
sudo bash -c 'cat >/etc/systemd/system/piproxy-start.service' << 'EOF'
[Unit]
Description=PiProxy Startup Script
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/pi/startproxy.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable piproxy-start.service

echo "Installation complete! Reboot system."
