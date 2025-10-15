#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Updating system..."
apt-get update -y && apt-get upgrade -y

echo "📦 Installing curl..."
apt-get install curl -y

echo "📦 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh


# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf



echo "🔑 Bringing LXC into Tailnet as a simple gateway client..."
tailscale up --advertise-routes=192.168.91.0/24

echo "✅ Tailscale client is now active!"
echo "ℹ️ Check connection with: tailscale status"
echo "🌐 Your LXC Tailnet IP:"
tailscale ip -4

# add to config lxc
# lxc.cgroup2.devices.allow: c 10:200 rwm
# lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
