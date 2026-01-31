#!/bin/bash

# NFS Unmount Script

MOUNTS=(
    "/Volumes/NASik_Backups"
    "/Volumes/NASik_Personal-Archive"
)

echo "Unmounting NFS shares..."

for mount in "${MOUNTS[@]}"; do
    if mount | grep -q "$mount"; then
        echo "Unmounting: $mount"
        sudo umount "$mount"
        [ $? -eq 0 ] && echo "✓ Unmounted: $mount" || echo "✗ Failed: $mount"
    else
        echo "Not mounted: $mount"
    fi
done

echo "Done!"