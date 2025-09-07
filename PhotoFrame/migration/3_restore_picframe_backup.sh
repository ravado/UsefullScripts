#!/bin/bash
set -euo pipefail

# Load environment variables and validate
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "$SCRIPT_DIR/env_loader.sh"; then
    exit 1
fi

echo -e "=== PICFRAME RESTORATION SCRIPT ===\n"

SMB_CRED_FILE="$HOME/.smbcred"
LOCAL_TMP="/tmp/picframe_restore"
PICFRAME_BASE="$HOME/picframe"
PICFRAME_DATA="$PICFRAME_BASE/picframe_data"

mkdir -p "$LOCAL_TMP"

###########################
# Parse options
###########################

# Defaults
VERBOSE=0          # --verbose : extra debug/summary output
RESTORE_SERVICE=0  # --with-service : restore original systemd service from backup

POSITIONAL=()

# Loop through all args
for arg in "$@"; do
  case "$arg" in
    -v|--verbose)
      # Enable verbose output (extra logging and summary at the end)
      VERBOSE=1
      ;;
    --with-service)
      # Restore the systemd picframe.service from the backup archive
      # If not set, script will keep the service created by the installer
      RESTORE_SERVICE=1
      ;;
    *)
      # Any non-flag is treated as a positional argument
      POSITIONAL+=("$arg")
      ;;
  esac
done

# Put back only the positional args for easy handling
set -- "${POSITIONAL[@]}"

# --- Required arguments ---
# 1: <prefix>        (home / batanovs / cherednychoks)
# 2: <backup file>   (filename.tar.gz OR "latest")
if [ $# -lt 2 ]; then
    echo "❌ Usage: $0 [--verbose] [--with-service] <prefix> <backup_file.tar.gz|latest>"
    echo ""
    echo "Examples:"
    echo "  $0 home latest"
    echo "  $0 --verbose home latest"
    echo "  $0 home latest --with-service"
    echo "  $0 --verbose --with-service home latest"
    exit 1
fi

PREFIX="$1"
BACKUP_INPUT="$2"
BACKUP_PREFIX="picframe_${PREFIX}_setup_backup_"

###########################
# Fetch from SMB if needed
###########################
if [[ "$BACKUP_INPUT" == "latest" ]]; then
    echo "🔍 Searching SMB ($SMB_BACKUPS_PATH/$SMB_BACKUPS_SUBDIR) for latest backup with prefix: $BACKUP_PREFIX"

    LATEST_FILE=$(smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" -c "cd $SMB_BACKUPS_SUBDIR; ls" \
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
    smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" -c "cd $SMB_BACKUPS_SUBDIR; lcd $LOCAL_TMP; get $BACKUP_NAME"
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
    mkdir -p "$PICFRAME_DATA"
    cp -a "$BACKUP_FULL/picframe_data/." "$PICFRAME_DATA/"
    echo "✅ picframe_data merged into $PICFRAME_DATA (existing files overwritten, others kept)"
else
    echo "⚠️ No picframe_data found in backup"
fi

echo "📑 Applying updated configuration for $PREFIX..."

CONFIG_REMOTE="configs/${PREFIX}_updated_config.yml"
CONFIG_LOCAL="$LOCAL_TMP/${PREFIX}_updated_config.yml"

# Fetch updated config from SMB share
smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" -c "cd $SMB_BACKUPS_SUBDIR/configs; lcd $LOCAL_TMP; get ${PREFIX}_updated_config.yml" || {
    echo "⚠️ No updated config found on SMB for $PREFIX"
}

# Apply if downloaded
if [ -f "$CONFIG_LOCAL" ]; then
    mkdir -p "$PICFRAME_DATA/config"
    cp -v "$CONFIG_LOCAL" "$PICFRAME_DATA/config/configuration.yaml"
    echo "✅ Updated configuration.yaml applied from $CONFIG_LOCAL"
else
    echo "⚠️ Updated config not applied (file missing after fetch)"
fi

if [[ $RESTORE_SERVICE -eq 1 ]]; then
    echo "⚙️ Restoring systemd service..."
    if [ -f "$BACKUP_FULL/picframe.service" ]; then
        sudo cp -v "$BACKUP_FULL/picframe.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable picframe.service
        echo "✅ picframe.service restored from backup"
    else
        echo "⚠️ No picframe.service found in backup"
    fi
else
    echo "ℹ️ Skipping service restore (use --with-service to enable)"
fi

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
    echo "🔄 Updating existing repo..."
    git -C "$TARGET_DIR" checkout main
    git -C "$TARGET_DIR" pull --ff-only
    echo "✅ Repo updated to latest main."
else
    echo "🔄 Cloning UsefullScripts repo (branch: main)..."
    if git clone --branch main --single-branch git@github.com:ravado/UsefullScripts.git "$TARGET_DIR"; then
        echo "✅ Scripts repository cloned on branch main"
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

echo -e "\n=== ✅ RESTORATION COMPLETE ===\n"
echo "🚀 Next steps:"
echo "1️⃣ Configure photo sync service: ./5_configure_photo_sync.sh <prefix>"
echo "2️⃣ 🔄 Restart the Pi: sudo reboot now"
echo "3️⃣ 🔒 Start WireGuard: sudo systemctl restart wg-quick@wg0"