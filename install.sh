#!/bin/bash

# Update and upgrade system packages
echo "Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install necessary packages
echo "Installing required packages..."
sudo apt-get install -y usb-modeswitch

echo "Installing 3proxy..."
git clone https://github.com/z3apa3a/3proxy
cd 3proxy
ln -s Makefile.Linux Makefile
make
sudo make install
cd ..
sleep 2

# Setup 3proxy
echo "Setting up 3proxy..."
sudo cp ./3proxy.cfg /home/pi/3proxy.cfg
sudo chmod +x /home/pi/3proxy.cfg

# Setup the startproxy.sh script
echo "Creating startup script..."
sudo cp ./startproxy.sh /home/pi/startproxy.sh
sudo chmod +x /home/pi/startproxy.sh

# Configure udev rules for Huawei dongle
echo "Setting up udev rules..."
sudo cp ./40-huawei.rules /etc/udev/rules.d/40-huawei.rules

# Add startup to rc.local
echo "Adding startup commands to /etc/rc.local..."
sudo cp ./rc.local /etc/rc.local
sudo chmod +x /etc/rc.local

sudo usb_modeswitch -v 3566 -p 2001 -X

sleep 2
# Reload udev rules
sudo udevadm control --reload-rules

# Success message
echo "Installation complete! Reboot system."
