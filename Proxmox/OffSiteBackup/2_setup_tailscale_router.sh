#!/usr/bin/env bash
set -euo pipefail

LAN_SUBNET="192.168.91.0/24"   # заміни на свою підмережу

echo "🚀 Updating system..."
apt-get update -y && apt-get upgrade -y

echo "📦 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "🛠️ Enabling service..."
systemctl enable --now tailscaled

echo "🔑 Bringing LXC into Tailnet as subnet router..."
tailscale up \
  --hostname=proxmox-router \
  --advertise-routes=$LAN_SUBNET \
  --accept-dns=false

echo "✅ Done!"
echo "👉 Now go to https://login.tailscale.com/admin/machines and Approve route: $LAN_SUBNET"
echo "Check routes with: tailscale status"