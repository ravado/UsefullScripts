#!/bin/bash
set -euo pipefail

# Load environment variables and validate
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env_loader.sh"

echo -e "=== PICFRAME RESTORATION SCRIPT ===\n"

SMB_CRED_FILE="$HOME/.smbcred"
LOCAL_TMP="/tmp/picframe_restore"
PICFRAME_BASE="$HOME/picframe"
PICFRAME_DATA="$PICFRAME_BASE/picframe_data"

mkdir -p "$LOCAL_TMP"

###########################
# Parse options
###########################
VERBOSE=0
if [[ "${1:-}" == "-v" ]]; then
    VERBOSE=1
    shift
fi

# ✅ Require prefix and backup argument
if [ $# -lt 2 ]; then
    echo "❌ Usage: $0 [-v] <prefix> <backup_file.tar.gz|latest>"
    echo "Examples:"
    echo "  $0 home latest"
    echo "  $0 batanovs picframe_batanovs_setup_backup_20250802_105212.tar.gz"
    exit 1
fi

PREFIX="$1"
BACKUP_INPUT="$2"
BACKUP_PREFIX="picframe_${PREFIX}_setup_backup_"

###########################
# Fetch from SMB if needed
###########################
if [[ "$BACKUP_INPUT" == "latest" ]]; then
    echo "🔍 Searching SMB ($SMB_SERVER/$SMB_SUBDIR) for latest backup with prefix: $BACKUP_PREFIX"

    LATEST_FILE=$(smbclient "$SMB_SERVER" -A "$SMB_CRED_FILE" -c "cd $SMB_SUBDIR; ls" \
                  | awk '{print $1}' \
                  | grep "^${BACKUP_PREFIX}" \
                  | sort -r \
                  | head -n1)

    if [[ -z "$LATEST_FILE" ]]; then
        echo "❌ No backups found for prefix '$PREFIX' on SMB"
        exit 1
    fi

    BACKUP_NAME="$LATEST_FILE"
    echo "✅ Found latest backup on SMB: $BACKUP_NAME"
else
    BACKUP_NAME="$BACKUP_INPUT"
    echo "📦 Using specified backup file: $BACKUP_NAME"
fi

###########################
# Fetch from SMB if not local
###########################
if [ ! -f "$LOCAL_TMP/$BACKUP_NAME" ]; then
    echo "📥 Downloading $BACKUP_NAME from SMB..."
    smbclient "$SMB_SERVER" -A "$SMB_CRED_FILE" -c "cd $SMB_SUBDIR; lcd $LOCAL_TMP; get $BACKUP_NAME"
    BACKUP_PATH="$LOCAL_TMP/$BACKUP_NAME"
else
    BACKUP_PATH="$LOCAL_TMP/$BACKUP_NAME"
    echo "✅ Using existing local backup: $BACKUP_PATH"
fi

###########################
# Extract backup
###########################
echo "📦 Extracting backup archive..."
sudo tar -xzpf "$BACKUP_PATH" -C "$LOCAL_TMP"

BACKUP_DIR=$(basename "$BACKUP_PATH" .tar.gz)
BACKUP_FULL="$LOCAL_TMP/$BACKUP_DIR"

if [ ! -d "$BACKUP_FULL" ]; then
    echo "❌ Backup directory not found after extraction!"
    exit 1
fi

# Fix ownership of extracted files so current user can read them if needed
sudo chown -R "$USER":"$USER" "$BACKUP_FULL"

echo "🕑 Restoring user crontab..."
if [ -f "$BACKUP_FULL/crontab.txt" ]; then
    crontab "$BACKUP_FULL/crontab.txt"
    echo "✅ Crontab restored from backup"
else
    echo "⚠️ No crontab.txt found in backup, skipping"
fi

echo "🔧 Patching restored crontab to use 'xset' instead of 'vcgencmd'..."

TMP_CRON_PATCHED="$LOCAL_TMP/patched_crontab.txt"

# Read and patch crontab
crontab -l | \
    sed 's/vcgencmd display_power 0/xset dpms force off/g' | \
    sed 's/vcgencmd display_power 1/xset dpms force on/g' > "$TMP_CRON_PATCHED"

# Add DISPLAY=:0 at the top if not already present
if ! grep -q "^DISPLAY=" "$TMP_CRON_PATCHED"; then
    sed -i '1iDISPLAY=:0' "$TMP_CRON_PATCHED"
    echo "✅ Added DISPLAY=:0 to crontab"
else
    echo "ℹ️ DISPLAY already set in crontab"
fi

# Reinstall patched crontab
crontab "$TMP_CRON_PATCHED"
echo "✅ Patched display commands in crontab"

# Cleanup
rm "$TMP_CRON_PATCHED"

###########################
# Restore files
###########################
echo "📂 Creating necessary directories..."
mkdir -p ~/picframe ~/Documents/Scripts ~/.config ~/.config/picframe ~/Pictures

echo "🖼️ Restoring PicFrame data..."
if [ -d "$BACKUP_FULL/picframe_data" ]; then
    mkdir -p "$PICFRAME_BASE"
    rm -rf "$PICFRAME_DATA"
    cp -r "$BACKUP_FULL/picframe_data" "$PICFRAME_BASE/"
    echo "✅ picframe_data restored into $PICFRAME_BASE/"
else
    echo "⚠️ No picframe_data found in backup"
fi

# It should be better recreated in #1 install_picframe script
# echo "⚙️ Restoring systemd service..."
# if [ -f "$BACKUP_FULL/picframe.service" ]; then
#     sudo cp -v "$BACKUP_FULL/picframe.service" /etc/systemd/system/
#     sudo systemctl daemon-reload
#     sudo systemctl enable picframe.service
#     echo "✅ picframe.service restored"
# else
#     echo "⚠️ No picframe.service found in backup"
# fi

echo "🔑 Restoring SSH keys..."
if [ -f "$BACKUP_FULL/ssh/id_ed25519" ]; then
    mkdir -p ~/.ssh
    cp -v "$BACKUP_FULL/ssh/id_ed25519"* ~/.ssh/
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
fi

echo "🛠️ Restoring git configuration..."
if [ -f "$BACKUP_FULL/git_config/user.name" ]; then
    GIT_NAME=$(cat "$BACKUP_FULL/git_config/user.name")
    git config --global user.name "$GIT_NAME"
    [ $VERBOSE -eq 1 ] && echo "   → git user.name set to $GIT_NAME"
fi
if [ -f "$BACKUP_FULL/git_config/user.email" ]; then
    GIT_EMAIL=$(cat "$BACKUP_FULL/git_config/user.email")
    git config --global user.email "$GIT_EMAIL"
    [ $VERBOSE -eq 1 ] && echo "   → git user.email set to $GIT_EMAIL"
fi

echo "📂 Restoring Documents/Scripts repository..."

BRANCH_FILE="$BACKUP_FULL/git_config/scripts_branch"
SAVED_BRANCH="photoframe-home"
[ -f "$BRANCH_FILE" ] && SAVED_BRANCH=$(cat "$BRANCH_FILE")

TARGET_DIR=~/Documents/Scripts
mkdir -p ~/Documents

if [ -d "$TARGET_DIR/.git" ]; then
    echo "⚠️ $TARGET_DIR already exists, skipping clone."
else
    echo "🔄 Cloning UsefullScripts repo (branch: $SAVED_BRANCH)..."
    if git clone -b "$SAVED_BRANCH" git@github.com:ravado/UsefullScripts.git "$TARGET_DIR"; then
        echo "✅ Scripts repository cloned on branch $SAVED_BRANCH"
    else
        echo "❌ Failed to clone Scripts repository. Check SSH keys and GitHub access."
    fi
fi

###########################
# Create photo directories
###########################
echo "📁 Ensuring photo directories exist..."
mkdir -p ~/Pictures/PhotoFrame ~/Pictures/PhotoFrameOriginal ~/Pictures/PhotoFrameDeleted
echo "✅ Photo directories created in ~/Pictures/"
ls -lah ~/Pictures

###########################
# Restore WireGuard configs
###########################
echo "🔒 Restoring WireGuard configuration..."
if [ -d "$BACKUP_FULL/wireguard_config" ]; then
    sudo mkdir -p /etc/wireguard
    sudo cp -v "$BACKUP_FULL/wireguard_config/"* /etc/wireguard/
    sudo chmod 600 /etc/wireguard/*.conf /etc/wireguard/privatekey 2>/dev/null || true
    echo "✅ WireGuard configuration restored"
    echo "   → Restart WireGuard after network setup: sudo systemctl restart wg-quick@wg0"
else
    echo "⚠️ No WireGuard configuration found in backup"
fi

###########################
# Verbose details
###########################
if [ $VERBOSE -eq 1 ]; then
    echo ""
    echo "📋 Verbose summary:"
    echo "   Backup used: $BACKUP_PATH"
    echo "   Restored PicFrame config to: ~/.config/picframe/"
    echo "   Restored SSH keys to: ~/.ssh/"
    echo "   Restored WireGuard config to: /etc/wireguard/"
    echo "   Restored Samba config to: /etc/samba/"
    echo "   Restored systemd service to: /etc/systemd/system/picframe.service"
fi

###########################
# Cleanup
###########################
echo "🧹 Cleaning up temporary files..."
rm -rf "$BACKUP_FULL"

echo -e "\n=== RESTORATION COMPLETE ===\n"
echo "Next steps:"
echo "1. sync the photos from previous pi frame with \`4_sync_photos.sh\` script"
echo "2. restart the pi: sudo reboot now"
echo "3. Start WireGuard: sudo systemctl restart wg-quick@wg0"
echo "4. Start PicFrame: sudo systemctl start picframe.service"
echo "5. Check logs: sudo journalctl -u picframe.service -f"