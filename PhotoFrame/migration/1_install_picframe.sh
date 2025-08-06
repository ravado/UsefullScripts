#!/bin/bash
set -euo pipefail

# Detect current user
CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)

echo "🔧 Updating system..."
export DEBIAN_FRONTEND=noninteractive
sudo apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update
sudo apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y \
    python3 python3-pip python3-pil python3-numpy \
    xserver-xorg x11-xserver-utils xinit \
    libmtdev1 libgles2-mesa git \
    libsdl2-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    locales \
    wireguard rsync \
    inotify-tools imagemagick libgpiod2 smbclient rclone samba mosquitto mosquitto-clients bc

# Install resolvconf
sudo apt install -y resolvconf

# Detect which network service is present and restart accordingly
if systemctl is-enabled NetworkManager &>/dev/null; then
    echo "Restarting NetworkManager..."
    sudo systemctl restart NetworkManager
elif systemctl is-enabled networking &>/dev/null; then
    echo "Restarting networking..."
    sudo systemctl restart networking
else
    echo "⚠️ No NetworkManager or networking service detected, skipping restart."
fi

# Wait until DNS is back online
echo "Waiting for DNS to come back..."
until ping -c1 8.8.8.8 >/dev/null 2>&1 || host google.com >/dev/null 2>&1; do
  sleep 2
done

echo "DNS is available, continuing script..."

echo "🌐 Configuring locales (en_US.UTF-8 and uk_UA.UTF-8)..."
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^# *uk_UA.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
sudo update-locale LANG=en_US.UTF-8

# ✅ Install Adafruit Python modules
echo "🐍 Installing required Python modules..."

# Use this on VM
sudo pip3 install --break-system-packages Adafruit_DHT --install-option="--force-pi"
sudo pip3 install --break-system-packages adafruit-circuitpython-bme280 adafruit-circuitpython-dht adafruit-platformdetect
sudo pip3 install --break-system-packages paho-mqtt

# Use this on real pi device
# sudo pip3 install --break-system-packages Adafruit_DHT adafruit-circuitpython-bme280 adafruit-circuitpython-dht adafruit-platformdetect

echo "📥 Cloning picframe..."
cd "$HOME_DIR"
if [ -d "picframe" ]; then
    echo "⚠️  Existing picframe folder found, removing..."
    rm -rf picframe
fi

git clone -b main https://github.com/ravado/picframe.git
# git clone https://github.com/helgeerbe/picframe.git
cd picframe

echo "🐍 Installing Picframe system-wide (Bookworm fix)..."
sudo pip3 install . --break-system-packages

# Switch to develop branch
git checkout develop

# echo "📂 Initializing Picframe config..."
# picframe -i "$HOME_DIR"
# mkdir -p "$HOME_DIR/.config/picframe"
# cp "$HOME_DIR/picframe_data/config/configuration.yaml" "$HOME_DIR/.config/picframe/"

echo "🎨 Starting X server for HDMI display..."
sudo X :0 -nolisten tcp &
sleep 3

echo "📺 Setting DISPLAY variable..."
export DISPLAY=:0
if ! grep -q "export DISPLAY=:0" "$HOME_DIR/.bashrc"; then
    echo 'export DISPLAY=:0' >> "$HOME_DIR/.bashrc"
fi

# Detect Picframe binary path
PICFRAME_BIN=$(which picframe)

echo "🛠️ Creating systemd service for auto-start..."
SERVICE_FILE=/etc/systemd/system/picframe.service
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Picframe Slideshow
After=multi-user.target
# After=network.target

[Service]
User=root
Type=simple
#Environment=DISPLAY=:0
ExecStart=xinit /usr/bin/python3 /home/ivan.cherednychok/picframe/picframe_data/run_start.py /home/ivan.cherednychok/picframe/picframe_data/config/configuration.yaml -- :0 -s 0 -dpms
# •  -- :0 - Specifies display :0 and separates application args from X server args
# •  -s 0 - Disables screen saver (sets timeout to 0)
# •  -dpms - Disables Display Power Management Signaling


# User=$CURRENT_USER
# ExecStart=$PICFRAME_BIN $HOME_DIR/.config/picframe/configuration.yaml

Restart=always
RestartSec=5

# Make sure environment variables are loaded (e.g., LANG)
Environment=LANG=en_US.UTF-8

[Install]
WantedBy=multi-user.target
EOL

echo "🔄 Enabling Picframe service..."
sudo systemctl daemon-reload
sudo systemctl enable picframe
sudo systemctl restart picframe

echo "Disabling screen timeout and DPMS power management..."
xset s off
xset -dpms
echo "Current screen saver settings:"
xset q | grep -A 2 "Screen Saver"

echo "Screen timeout disabled successfully!"

echo "✅ Installation complete!"
echo "➡️ Picframe will now start automatically on boot using HDMI screen."