#!/usr/bin/env bash
set -euo pipefail

echo "Updating package index..."
sudo apt-get update

echo "Installing required packages..."
sudo apt-get install -y usb-modeswitch git build-essential ca-certificates

# --------------------------------------------------------------------
# Install 3proxy only if missing
# --------------------------------------------------------------------
if ! command -v 3proxy >/dev/null 2>&1; then
  echo "Building 3proxy..."
  git clone https://github.com/z3apa3a/3proxy /tmp/3proxy-src
  cd /tmp/3proxy-src
  ln -sf Makefile.Linux Makefile
  make -j$(nproc)
  sudo make install
  cd -
  rm -rf /tmp/3proxy-src
else
  echo "3proxy already installed."
fi

echo "Installing configuration files..."

# Udev rules
sudo install -m644 udev/40-3566-switch.rules /etc/udev/rules.d/40-3566-switch.rules
sudo install -m644 udev/70-modem-netnames.rules /etc/udev/rules.d/70-modem-netnames.rules

# Scripts
sudo install -m755 scripts/modeswitch-wrapper.sh /usr/local/bin/modeswitch-wrapper.sh
sudo install -m755 scripts/modem-init.sh /usr/local/bin/modem-init.sh

# MAC definitions
sudo install -m644 modem_macs.conf /etc/modem_macs.conf

# 3proxy config
sudo install -m644 3proxy.cfg /home/pi/3proxy.cfg
sudo chown pi:pi /home/pi/3proxy.cfg

# Systemd services
sudo install -m644 systemd/modem-init.service /etc/systemd/system/modem-init.service
sudo install -m644 systemd/3proxy.service /etc/systemd/system/3proxy.service

sudo systemctl daemon-reload
sudo systemctl enable --now modem-init.service
sudo systemctl enable --now 3proxy.service

echo "Reloading udev rules..."
sudo udevadm control --reload-rules

echo "Installation complete. Reboot recommended."

