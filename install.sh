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

echo "Installation complete! Reboot system."
