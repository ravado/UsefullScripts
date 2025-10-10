#!/usr/bin/env bash
set -euo pipefail

USER="backup"
PASS="SuperSecretPass"        # зміни пароль
MOUNT_POINT="/mnt/backupdisk" # змінюй на свій диск
UUID="PUT-YOUR-UUID-HERE"     # заміни на реальний UUID з lsblk

echo "🚀 Installing rsync..."
sudo apt-get update -y && sudo apt-get install -y rsync

echo "👤 Ensuring backup user exists..."
if ! id "$USER" >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" $USER
fi

echo "📂 Preparing mount point..."
sudo mkdir -p $MOUNT_POINT
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab
fi

echo "🔄 Mounting disk..."
sudo mount -a
sudo chown -R $USER:$USER $MOUNT_POINT

echo "📝 Creating /etc/rsyncd.conf..."
sudo tee /etc/rsyncd.conf >/dev/null <<EOF
uid = $USER
gid = $USER
use chroot = no
max connections = 2
log file = /var/log/rsyncd.log
timeout = 300

[backup]
   path = $MOUNT_POINT
   comment = Backup module
   read only = false
   auth users = $USER
   secrets file = /etc/rsyncd.secrets
EOF

echo "🔑 Creating /etc/rsyncd.secrets..."
echo "$USER:$PASS" | sudo tee /etc/rsyncd.secrets >/dev/null
sudo chmod 600 /etc/rsyncd.secrets
sudo chown root:root /etc/rsyncd.secrets

echo "🔄 Enabling rsync daemon..."
sudo systemctl enable rsync
sudo systemctl restart rsync

echo "✅ Done!"
echo "   - Rsync daemon is running on port 873"
echo "   - Module name: backup"
echo "   - Path: $BACKUP_DIR"
echo "   - Username: $USER"
echo "   - Password: $PASS"