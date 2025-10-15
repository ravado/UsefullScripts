#!/usr/bin/env bash
# ============================================
# 🔧 Enable IP forwarding & configure NAT for rsync
# ============================================

set -euo pipefail

REMOTE_IP="100.106.208.27"
RSYNC_PORT=873

echo "🚀 Enabling IPv4 forwarding..."
# Enable temporarily
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

# Make it persistent across reboots
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
fi
sudo sysctl -p >/dev/null

# ============================================
# 🧱 Configure NAT rules (clean and reapply)
# ============================================

echo "🧹 Cleaning old NAT rules related to rsync (${RSYNC_PORT})..."
sudo iptables -t nat -D PREROUTING -p tcp --dport ${RSYNC_PORT} -j DNAT --to-destination ${REMOTE_IP}:${RSYNC_PORT} 2>/dev/null || true
sudo iptables -t nat -D POSTROUTING -p tcp -d ${REMOTE_IP} --dport ${RSYNC_PORT} -j MASQUERADE 2>/dev/null || true

echo "📡 Adding new DNAT rule (redirect port ${RSYNC_PORT} → ${REMOTE_IP})..."
sudo iptables -t nat -A PREROUTING -p tcp --dport ${RSYNC_PORT} -j DNAT --to-destination ${REMOTE_IP}:${RSYNC_PORT}

echo "🔁 Adding MASQUERADE rule (for return traffic / hairpin NAT)..."
sudo iptables -t nat -A POSTROUTING -p tcp -d ${REMOTE_IP} --dport ${RSYNC_PORT} -j MASQUERADE

# ============================================
# 💾 Save and persist rules
# ============================================

echo "💾 Installing iptables-persistent (if missing)..."
sudo apt-get update -y
sudo apt-get install -y iptables-persistent

echo "🧱 Saving current iptables configuration..."
sudo netfilter-persistent save

# ============================================
# ✅ Done
# ============================================

echo "✅ NAT configuration complete."
echo "🔍 Check active rules: sudo iptables -t nat -L -n -v"
echo "🔍 Verify IP forwarding: sysctl net.ipv4.ip_forward"