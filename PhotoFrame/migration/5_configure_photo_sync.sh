#!/bin/bash
set -e

# === LOAD ENV ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env_loader.sh"

# === CONSTANTS / PATHS (hardcoded user) ===
RUN_USER="ivan.cherednychok"
RUN_HOME="/home/${RUN_USER}"
SCRIPT_PATH="${RUN_HOME}/Documents/Scripts/PhotoFrame/sync_and_resize_photos.sh"
RCLONE_CONFIG="${RUN_HOME}/.config/rclone/rclone.conf"

SYSTEMD_TEMPLATE_NAME="photo-sync@.service"
SYSTEMD_TEMPLATE_PATH="/etc/systemd/system/${SYSTEMD_TEMPLATE_NAME}"
SYSTEMD_BASE_NAME="photo-sync.service"                     # convenience unit → defaults to 'home'
SYSTEMD_BASE_PATH="/etc/systemd/system/${SYSTEMD_BASE_NAME}"

# === SMB / rclone remote from env ===
SERVER_IP="$SMB_HOST"
SHARE_NAME="$SMB_PICFRAMES_SHARE"
username="$SMB_CRED_USER"
raw_password="$SMB_CRED_PASS"
remote_name="nasikphotos"

# === OBSCURE PASSWORD ===
obscured_pass="$(rclone obscure "$raw_password")"

# === CREATE / UPDATE RCLONE CONFIG ENTRY ===
mkdir -p "$(dirname "$RCLONE_CONFIG")"

if grep -q "^\[$remote_name\]" "$RCLONE_CONFIG" 2>/dev/null; then
  echo "🔁 Updating existing rclone config for [$remote_name]"
  sed -i "/^\[$remote_name\]/,/^$/d" "$RCLONE_CONFIG"
else
  echo "🆕 Creating rclone config for [$remote_name]"
fi

cat >> "$RCLONE_CONFIG" <<EOF

[$remote_name]
type = smb
server = $SERVER_IP
host = $SERVER_IP
share = $SHARE_NAME
username = $username
user = $username
pass = $obscured_pass
EOF

chmod 600 "$RCLONE_CONFIG"
chown "$RUN_USER":"$RUN_USER" "$RCLONE_CONFIG" || true
echo "✅ rclone config updated for [$remote_name] at $RCLONE_CONFIG"

# === CREATE SYSTEMD TEMPLATE SERVICE (photo-sync@.service) ===
echo "🛠️ Writing $SYSTEMD_TEMPLATE_PATH"
sudo tee "$SYSTEMD_TEMPLATE_PATH" > /dev/null <<EOF
[Unit]
Description=Sync and Resize Photos (%i)
After=network-online.target

[Service]
Type=oneshot
User=${RUN_USER}
Environment="HOME=${RUN_HOME}"
Environment="RCLONE_CONFIG=${RCLONE_CONFIG}"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"
WorkingDirectory=${RUN_HOME}
ExecStart=${SCRIPT_PATH} %i

[Install]
WantedBy=multi-user.target
EOF

# === CREATE CONVENIENCE NON-TEMPLATE (photo-sync.service → defaults to 'home') ===
echo "🛠️ Writing $SYSTEMD_BASE_PATH (defaults to 'home')"
sudo tee "$SYSTEMD_BASE_PATH" > /dev/null <<EOF
[Unit]
Description=Sync and Resize Photos (default: home)
After=network-online.target

[Service]
Type=oneshot
User=${RUN_USER}
Environment="HOME=${RUN_HOME}"
Environment="RCLONE_CONFIG=${RCLONE_CONFIG}"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"
WorkingDirectory=${RUN_HOME}
ExecStart=${SCRIPT_PATH} home

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd units created:"
echo "   - $SYSTEMD_TEMPLATE_PATH"
echo "   - $SYSTEMD_BASE_PATH"

# === RELOAD SYSTEMD & HINTS ===
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

echo
echo "▶️ Run manually (instances):"
echo "  sudo systemctl start photo-sync@home"
echo "  sudo systemctl start photo-sync@batanovs"
echo "  sudo systemctl start photo-sync@cherednychoks"
echo
echo "▶️ Convenience (defaults to 'home'):"
echo "  sudo systemctl start photo-sync"
echo "  sudo systemctl status photo-sync"
echo
echo "🕒 Cron examples (root):"
echo "  0 2 * * * /bin/systemctl start photo-sync@home"
echo " 10 2 * * * /bin/systemctl start photo-sync@batanovs"
echo " 20 2 * * * /bin/systemctl start photo-sync@cherednychoks"
echo
echo "🪵 Or log via systemd-cat from cron:"
echo "  * * * * * /usr/bin/systemd-cat -t picframe-backup ${SCRIPT_PATH} home"