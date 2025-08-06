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
# Validate required variables
###########################

# SMB server configuration
: "${SMB_SERVER:?❌ SMB_SERVER is missing in $ENV_FILE}"
: "${SMB_SUBDIR:?❌ SMB_SUBDIR is missing in $ENV_FILE}"

# SMB credentials
: "${USERNAME:?❌ USERNAME is missing in $ENV_FILE}"
: "${PASSWORD:?❌ PASSWORD is missing in $ENV_FILE}"
: "${SMB_CRED_USER:?❌ SMB_CRED_USER is missing in $ENV_FILE}"
: "${SMB_CRED_PASS:?❌ SMB_CRED_PASS is missing in $ENV_FILE}"

# Remote sync settings
: "${REMOTE_USER:?❌ REMOTE_USER is missing in $ENV_FILE}"
: "${REMOTE_HOST:?❌ REMOTE_HOST is missing in $ENV_FILE}"
: "${REMOTE_PATH:?❌ REMOTE_PATH is missing in $ENV_FILE}"
: "${LOCAL_PATH:?❌ LOCAL_PATH is missing in $ENV_FILE}"