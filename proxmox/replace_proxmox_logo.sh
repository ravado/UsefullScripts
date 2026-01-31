#!/bin/bash

# === CONFIGURATION ===
LOCAL_IMAGE="logo-128.png"
REMOTE_HOST="root@192.168.91.199"   # Replace with actual IP/domain
TEMP_REMOTE="/tmp/logo-128.png"

# === REMOTE PATHS ===
PVE_LOGO="/usr/share/pve-manager/images/logo-128.png"
PBS_LOGO="/usr/share/javascript/proxmox-backup/images/logo-128.png"

# === STEP 1: Upload the image ===
echo "📤 Uploading $LOCAL_IMAGE to $REMOTE_HOST..."
scp "$LOCAL_IMAGE" "${REMOTE_HOST}:${TEMP_REMOTE}" || { echo "❌ Upload failed"; exit 1; }

# === STEP 2: SSH and process remotely ===
echo "🔧 Connecting and replacing logo on remote Proxmox server..."
ssh "$REMOTE_HOST" bash << 'EOF'
set -e

LOGO_SRC="/tmp/logo-128.png"
PVE_LOGO="/usr/share/pve-manager/images/logo-128.png"
PBS_LOGO="/usr/share/javascript/proxmox-backup/images/logo-128.png"

# Determine platform
if [ -f "$PVE_LOGO" ]; then
    TARGET="$PVE_LOGO"
    echo "🖥 Detected Proxmox VE"
elif [ -f "$PBS_LOGO" ]; then
    TARGET="$PBS_LOGO"
    echo "💾 Detected Proxmox Backup Server"
else
    echo "❌ No supported Proxmox installation found. Exiting."
    exit 1
fi

# Backup original if not already backed up
if [ ! -f "${TARGET}.bak" ]; then
    echo "📦 Creating backup of original logo..."
    cp "$TARGET" "${TARGET}.bak"
else
    echo "ℹ️ Backup already exists: ${TARGET}.bak"
fi

# Replace logo
echo "🔁 Replacing logo with uploaded version..."
mv "$LOGO_SRC" "$TARGET"
chmod 644 "$TARGET"

echo "✅ Logo replaced successfully! Clear your browser cache to see the change."
EOF
