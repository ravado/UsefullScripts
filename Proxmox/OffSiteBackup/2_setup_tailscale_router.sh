#!/usr/bin/env bash
# ============================================
# 🌐 Tailscale Gateway + NAT for rsync
# ============================================

set -euo pipefail

# === DevOps-safe privilege detection ===
if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
elif [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  echo "❌ This script must be run as root or with sudo privileges."
  exit 1
fi

REMOTE_IP="100.106.208.27"
RSYNC_PORT=873

# ============================================
# 📦 Install dependencies
# ============================================

echo "🚀 Updating system..."
$SUDO apt-get update -y && $SUDO apt-get upgrade -y

echo "📦 Installing curl and iptables utilities..."
$SUDO apt-get install -y curl iptables-persistent

# ============================================
# 🌀 Install and enable Tailscale
# ============================================

echo "📦 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | $SUDO bash

# ============================================
# 🛠️ Enable IP forwarding
# ============================================

echo "🛠️ Enabling IP forwarding..."
$SUDO tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

$SUDO sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null

# ============================================
# 🔗 Connect to Tailnet
# ============================================

echo "🔑 Bringing this node into Tailnet..."
$SUDO tailscale up

echo "🌍 Your Tailscale IPv4 address:"
tailscale ip -4

# ============================================
# 🧱 Configure NAT rules (for rsync)
# ============================================

echo "🧹 Cleaning old NAT rules related to rsync (${RSYNC_PORT})..."
$SUDO iptables -t nat -D PREROUTING -p tcp --dport ${RSYNC_PORT} -j DNAT --to-destination ${REMOTE_IP}:${RSYNC_PORT} 2>/dev/null || true
$SUDO iptables -t nat -D POSTROUTING -p tcp -d ${REMOTE_IP} --dport ${RSYNC_PORT} -j MASQUERADE 2>/dev/null || true

echo "📡 Adding new DNAT rule (redirect port ${RSYNC_PORT} → ${REMOTE_IP})..."
$SUDO iptables -t nat -A PREROUTING -p tcp --dport ${RSYNC_PORT} -j DNAT --to-destination ${REMOTE_IP}:${RSYNC_PORT}

echo "🔁 Adding MASQUERADE rule (for return traffic / hairpin NAT)..."
$SUDO iptables -t nat -A POSTROUTING -p tcp -d ${REMOTE_IP} --dport ${RSYNC_PORT} -j MASQUERADE

echo "💾 Saving iptables configuration..."
$SUDO netfilter-persistent save

# ============================================
# ✅ Done
# ============================================

echo "✅ All set! This LXC now acts as a Tailscale gateway with NAT forwarding for rsync."
echo "🔍 Check Tailscale status: tailscale status"
echo "🔍 Check NAT rules: ${SUDO} iptables -t nat -L -n -v"
echo "🔍 Verify IP forwarding: sysctl net.ipv4.ip_forward"

cat <<'NOTE'

📋 Reminder for Proxmox LXC config:
Add the following lines to /etc/pve/lxc/<ID>.conf if not already present:

  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file

NOTE