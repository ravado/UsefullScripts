#!/bin/bash
# Not really needed since now we sync with rclone from NASik
# Use next 5_configure_photo_sync.sh better

set -euo pipefail

# Load environment variables and validate
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "$SCRIPT_DIR/env_loader.sh"; then
    exit 1
fi

echo "Syncing all files from ${REMOTE_HOST}..."

# Optional params for rsync to run with
# --ignore-existing → only copies new files, doesn’t overwrite.
# --update → copies only if the source file is newer.
# --remove-source-files → moves files instead of copying.
# --delete → makes local folder a mirror of remote (deletes files that don’t exist remotely).

rsync -av --progress --ignore-existing --delete \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}" \
    "${LOCAL_PATH}"

echo "Sync completed!"