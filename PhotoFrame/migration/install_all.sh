#!/bin/bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/ravado/UsefullScripts/main/PhotoFrame/migration"

# Always work in current dir for curl|bash
SCRIPT_DIR="$(pwd)"

# Files to download
FILES=(env_loader.sh 0_backup_setup.sh 1_install_picframe.sh 2_restore_samba.sh 3_restore_picframe_backup.sh 4_sync_photos.sh 5_configure_photo_sync.sh backup.env.example)

echo "📥 Downloading required scripts..."
for file in "${FILES[@]}"; do
    echo "   → $file"
    curl -fsSL "$REPO_URL/$file" -o "$SCRIPT_DIR/$file"
    chmod +x "$SCRIPT_DIR/$file" 2>/dev/null || true
done
echo "✅ All scripts downloaded."

# Copy backup.env.example to backup.env if not present
if [ ! -f "$SCRIPT_DIR/backup.env" ]; then
    echo "⚠️ No backup.env found, creating from example..."
    cp "$SCRIPT_DIR/backup.env.example" "$SCRIPT_DIR/backup.env"
    chmod 600 "$SCRIPT_DIR/backup.env"
    echo "✅ backup.env created from example. Please edit it to match your environment."
fi

echo ""
echo "✅ Installation complete."
echo ""
echo "👉 Next steps:"
echo "1️⃣  Edit the 'backup.env' file to match your SMB and PicFrame configuration."
echo "2️⃣  Run the scripts manually in the following order as needed:"
echo "    ./0_backup_setup.sh <prefix>"
echo "    ./1_install_picframe.sh"
echo "    ./2_restore_samba.sh"
echo "    ./3_restore_picframe_backup.sh <prefix> <latest|filename>"
echo "    ./4_sync_photos.sh"
echo ""
echo "ℹ️ Example:"
echo "    ./0_backup_setup.sh home"
echo "    ./3_restore_picframe_backup.sh home latest"