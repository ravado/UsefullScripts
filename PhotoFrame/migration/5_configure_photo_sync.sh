#!/bin/bash

set -e

# === CONFIG ===
SCRIPT_PATH="$HOME/Documents/Scripts/PhotoFrame/sync_and_resize_photos.sh"
RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
SYSTEMD_SERVICE_NAME="photo-sync.service"
SYSTEMD_SERVICE_PATH="$HOME/.config/systemd/user/$SYSTEMD_SERVICE_NAME"
SERVER_IP="192.168.91.198"
SHARE_NAME="Photo-Frames"

# === INPUT ===
read -p "Enter target name (e.g. home, batanovs, cherednychoks): " target_name
read -s -p "Enter password for accessing SMB share $SHARE_NAME: " raw_password
echo

username="photoframe-$target_name"
remote_name="nasikphotos"

# === OBSCURE PASSWORD ===
obscured_pass=$(rclone obscure "$raw_password")

# === CREATE RCLONE CONFIG ENTRY ===
mkdir -p "$(dirname "$RCLONE_CONFIG")"

# Remove old entry if exists
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
share = $SHARE_NAME
username = $username
password = $obscured_pass
EOF

chmod 600 "$RCLONE_CONFIG"

echo "✅ rclone config updated for [$remote_name]"

# === CREATE SYSTEMD SERVICE ===
mkdir -p "$(dirname "$SYSTEMD_SERVICE_PATH")"

cat > "$SYSTEMD_SERVICE_PATH" <<EOF
[Unit]
Description=Sync and Resize Photos for $target_name
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH $target_name
Environment="RCLONE_CONFIG=$RCLONE_CONFIG"

[Install]
WantedBy=default.target
EOF

echo "✅ Systemd user service created: $SYSTEMD_SERVICE_PATH"

# === INSTRUCT USER TO ENABLE SERVICE ===
echo
echo "To run it manually:"
echo "  systemctl --user start $SYSTEMD_SERVICE_NAME"
echo
echo "To run at boot/login:"
echo "  systemctl --user enable $SYSTEMD_SERVICE_NAME"