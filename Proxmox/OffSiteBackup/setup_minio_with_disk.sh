#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURABLE ===
MINIO_USER="minio-user"
MOUNT_POINT="/srv/minio/data"
DEVICE="/dev/sda1"                     # заміни, якщо інший диск
FS_TYPE="ext4"                         # або vfat/xfs, залежно від диска
MINIO_ROOT_USER="admin"                # зміни логін
MINIO_ROOT_PASSWORD="SuperSecretPass"  # зміни пароль

echo "🚀 Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "📦 Installing dependencies..."
sudo apt-get install -y wget unzip

echo "👤 Creating MinIO user..."
if ! id "$MINIO_USER" >/dev/null 2>&1; then
    sudo useradd -r -s /sbin/nologin $MINIO_USER
fi

echo "📂 Preparing mount point..."
sudo mkdir -p $MOUNT_POINT
sudo chown -R $MINIO_USER:$MINIO_USER $MOUNT_POINT

echo "💾 Checking device $DEVICE..."
if [ ! -b "$DEVICE" ]; then
    echo "❌ Device $DEVICE not found. Edit script and set correct device."
    exit 1
fi

echo "📝 Adding to /etc/fstab..."
UUID=$(blkid -s UUID -o value $DEVICE)
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID  $MOUNT_POINT  $FS_TYPE  defaults,noatime  0  2" | sudo tee -a /etc/fstab
fi

echo "🔄 Mounting $DEVICE to $MOUNT_POINT..."
sudo mount -a
sudo chown -R $MINIO_USER:$MINIO_USER $MOUNT_POINT

echo "📥 Downloading MinIO binary..."
wget -q https://dl.min.io/server/minio/release/linux-arm/minio -O /tmp/minio
sudo mv /tmp/minio /usr/local/bin/minio
sudo chmod +x /usr/local/bin/minio

echo "📝 Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/minio.service
[Unit]
Description=MinIO
After=network.target

[Service]
User=$MINIO_USER
Group=$MINIO_USER
Environment="MINIO_ROOT_USER=$MINIO_ROOT_USER"
Environment="MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD"
ExecStart=/usr/local/bin/minio server $MOUNT_POINT --console-address ":9001"
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd and starting MinIO..."
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio

echo "✅ MinIO installed and running!"
echo "   - Data dir: $MOUNT_POINT"
echo "   - API:     http://<pi-ip>:9000"
echo "   - Console: http://<pi-ip>:9001"
echo "   - User:    $MINIO_ROOT_USER"
echo "   - Pass:    $MINIO_ROOT_PASSWORD"