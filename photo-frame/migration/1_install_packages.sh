#!/bin/bash
set -euo pipefail

# System package installation for PicFrame on Raspberry Pi
# Run this script before 1_install_picframe_developer_mode.sh

# Function to check for a working internet connection
check_internet_connection() {
    echo "🌐 Checking for an active internet connection..."
    while ! ping -c 1 -W 1 google.com &> /dev/null; do
        echo "⚠️  No internet connection. Retrying in 5 seconds..."
        sleep 5
    done
    echo "✅ Internet connection confirmed."
}

check_internet_connection

echo "🔄 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

echo "📦 Installing required packages..."
sudo apt-get install -y \
    git \
    libsdl2-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    xwayland labwc wlr-randr \
    vlc ffmpeg imagemagick \
    wireguard rsync smbclient rclone \
    inotify-tools libgpiod2 bc btop \
    locales resolvconf \
    mosquitto mosquitto-clients \
    samba

echo "✅ All packages installed successfully."
