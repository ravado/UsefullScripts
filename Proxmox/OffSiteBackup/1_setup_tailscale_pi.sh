#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "📦 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "🛠️ Enabling service..."
sudo systemctl enable --now tailscaled

echo "🔑 Bringing Pi into Tailnet..."
sudo tailscale up \
  --hostname=pi-backup \
  --ssh

echo "✅ Raspberry Pi is now in Tailnet!"
echo "Pi Tailnet IP: $(tailscale ip -4)"
echo "Check status with: tailscale status"