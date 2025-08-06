#!/bin/bash

echo -e "[$(date '+%d-%m-%Y %H:%M:%S')] Initializing sync and resize script...\n"
# Run rclone sync (google photos, basically dead as of 2025 since google changed the api access)
# clone sync -v "googlephotos:shared-album/Photo Frame: Home" /home/ivan.cherednychok/Pictures/PhotoFrameOriginal --ignore-case-sync

# Run rclone sync from NASik or other SMB share
rclone copy -v "nasikphotos:/Photo-Frames/Home/Original" "$HOME/Pictures/PhotoFrameOriginal" \
  --ignore-case-sync \
  --copy-links \
  --create-empty-src-dirs \
  --exclude "Thumbs.db" \
  --exclude ".DS_Store" \
  --transfers=4 \
  --checkers=8

# Run the resizing script
/home/ivan.cherednychok/Documents/Scripts/PhotoFrame/resize_new_photos.sh

# Keep files synced so if there are some deleted photos it is represented in picture frame location too
/home/ivan.cherednychok/Documents/Scripts/PhotoFrame/remove_missing_photos.sh
