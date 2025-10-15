#!/usr/bin/env bash
set -euo pipefail

# === Check sudo availability ===
if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
elif [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  echo "❌ This script must be run as root or with sudo privileges."
  exit 1
fi

echo "🚀 Updating system..."
$SUDO apt-get update -y && $SUDO apt-get upgrade -y

echo "📦 Installing dependencies..."
$SUDO apt-get install -y curl

echo "📦 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | $SUDO bash

# === Enable IP forwarding for routing ===
echo "🛠️ Enabling IP forwarding..."
$SUDO tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

$SUDO sysctl -p /etc/sysctl.d/99-tailscale.conf

$SUDO tailscale up

echo "✅ Tailscale client is now active!"
echo "ℹ️ Check connection with: tailscale status"
echo "🌐 Your LXC Tailnet IP:"
tailscale ip -4

cat <<'NOTE'

📋 Reminder for Proxmox LXC config:
Add the following lines to /etc/pve/lxc/<ID>.conf if not already present:

  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file

NOTE