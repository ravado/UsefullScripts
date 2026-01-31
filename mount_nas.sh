#!/bin/bash

# NFS Mount Script for NASik shares

NAS_IP="192.168.91.198"
MOUNT_OPTS="rw,resvport,nfc,vers=3,hard,intr"

# Array of shares: "remote_path:local_mount_point"
SHARES=(
    "/volume1/Backups:/Volumes/NASik_Backups"
    "/volume1/Personal-Archive:/Volumes/NASik_Personal-Archive"
    "/volume2/Media-Library:/Volumes/NASik_Media-Library"
    # Add more shares here as needed
    # "/volume1/Photos:/Volumes/NASik_Photos"
)

echo "Mounting NFS shares from $NAS_IP..."

for share in "${SHARES[@]}"; do
    IFS=':' read -r remote local <<< "$share"
    
    # Create mount point if it doesn't exist
    if [ ! -d "$local" ]; then
        echo "Creating mount point: $local"
        sudo mkdir -p "$local"
    fi
    
    # Check if already mounted
    if mount | grep -q "$local"; then
        echo "✓ Already mounted: $local"
    else
        echo "Mounting: $NAS_IP$remote -> $local"
        sudo mount -t nfs -o $MOUNT_OPTS $NAS_IP$remote $local
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully mounted: $local"
        else
            echo "✗ Failed to mount: $local"
        fi
    fi
done

echo "Done!"