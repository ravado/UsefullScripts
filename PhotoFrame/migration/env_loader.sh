#!/bin/bash
# env_loader.sh – Loads environment variables for PicFrame scripts and validates them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/backup.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "❌ Missing $ENV_FILE. Please create it (you can copy backup.env.example)."
    exit 1
fi

###########################
# ✅ Validate required variables
###########################

# 📂 SMB Server Configuration
: "${SMB_HOST:?❌ SMB_HOST is missing in $ENV_FILE}"

: "${SMB_BACKUPS_SHARE:?❌ SMB_BACKUPS_SHARE is missing in $ENV_FILE}"
: "${SMB_BACKUPS_SUBDIR:?❌ SMB_BACKUPS_SUBDIR is missing in $ENV_FILE}"
: "${SMB_BACKUPS_PATH:?❌ SMB_BACKUPS_PATH is missing in $ENV_FILE}"

: "${SMB_PICFRAMES_SHARE:?❌ SMB_PICFRAMES_SHARE is missing in $ENV_FILE}"
: "${SMB_PICFRAMES_SUBDIR:?❌ SMB_PICFRAMES_SUBDIR is missing in $ENV_FILE}"
: "${SMB_PICFRAMES_PATH:?❌ SMB_PICFRAMES_PATH is missing in $ENV_FILE}"

# 🔑 SMB Credentials
: "${USERNAME:?❌ USERNAME is missing in $ENV_FILE}"
: "${PASSWORD:?❌ PASSWORD is missing in $ENV_FILE}"
: "${SMB_CRED_USER:?❌ SMB_CRED_USER is missing in $ENV_FILE}"
: "${SMB_CRED_PASS:?❌ SMB_CRED_PASS is missing in $ENV_FILE}"

# 🔄 Remote Sync Settings
: "${REMOTE_USER:?❌ REMOTE_USER is missing in $ENV_FILE}"
: "${REMOTE_HOST:?❌ REMOTE_HOST is missing in $ENV_FILE}"
: "${REMOTE_PATH:?❌ REMOTE_PATH is missing in $ENV_FILE}"
: "${LOCAL_PATH:?❌ LOCAL_PATH is missing in $ENV_FILE}"