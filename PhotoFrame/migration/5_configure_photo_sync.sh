#!/bin/bash

set -e

# === LOAD ENV ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env_loader.sh"

# === CONFIG from env ===
SCRIPT_PATH="$HOME/Documents/Scripts/PhotoFrame/sync_and_resize_photos.sh"
RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
SYSTEMD_SERVICE_NAME="photo-sync@.service"                    # <- templated
SYSTEMD_SERVICE_PATH="/etc/systemd/system/$SYSTEMD_SERVICE_NAME"

SERVER_IP="$SMB_HOST"
SHARE_NAME="$SMB_PICFRAMES_SHARE"
username="$SMB_CRED_USER"
raw_password="$SMB_CRED_PASS"
remote_name="nasikphotos"

# === OBSCURE PASSWORD ===
obscured_pass=$(rclone obscure "$raw_password")

# === CREATE RCLONE CONFIG ENTRY ===
mkdir -p "$(dirname "$RCLONE_CONFIG")"

# Remove old remote if exists
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
echo "✅ rclone config updated for [$remote_name]"

# === CREATE SYSTEMD TEMPLATE SERVICE ===
echo "🛠️ Creating systemd template at $SYSTEMD_SERVICE_PATH"
sudo tee "$SYSTEMD_SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Sync and Resize Photos (%i)
After=network-online.target

[Service]
Type=oneshot
User=root
Environment=RCLONE_CONFIG=$RCLONE_CONFIG
ExecStart=$SCRIPT_PATH %i

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd service created: $SYSTEMD_SERVICE_PATH"

# === RELOAD SYSTEMD AND SHOW INSTRUCTIONS ===
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload
echo
echo "To run it manually (pick one):"
echo "  sudo systemctl start photo-sync@home"
echo "  sudo systemctl start photo-sync@batanovs"
echo "  sudo systemctl start photo-sync@cherednychoks"
echo
echo "⚠️ To schedule automatic sync via root's crontab (examples):"
echo "  0 2 * * * /bin/systemctl start photo-sync@home"
echo "  10 2 * * * /bin/systemctl start photo-sync@batanovs"
echo "  20 2 * * * /bin/systemctl start photo-sync@cherednychoks"
echo
echo "Or log directly via systemd-cat from cron:"
echo "  * * * * * /usr/bin/systemd-cat -t picframe-backup $SCRIPT_PATH home"