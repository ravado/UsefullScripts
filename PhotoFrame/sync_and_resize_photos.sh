#!/bin/bash

echo -e "[$(date '+%d-%m-%Y %H:%M:%S')] Initializing sync and resize script...\n"

# Run rclone sync
rclone sync -v "googlephotos:shared-album/Photo Frame: Cherednychoks" /home/ivan.cherednychok/Pictures/PhotoFrameOriginal --ignore-case-sync

# Run the resizing script
/home/ivan.cherednychok/Documents/Scripts/PhotoFrame/resize_new_photos.sh

# Keep files synced so if there are some deleted photos it is represented in picture frame location too
/home/ivan.cherednychok/Documents/Scripts/PhotoFrame/remove_missing_photos.sh
