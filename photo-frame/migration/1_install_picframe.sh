#!/bin/bash
set -euo pipefail

# Load environment variables and validate
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "$SCRIPT_DIR/env_loader.sh"; then
    exit 1
fi

# Detect current user
CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)

###########################
# Swap Configuration
###########################

configure_swap() {
    local SWAP_SIZE="${1:-1024}"
    local SWAP_FILE="/etc/dphys-swapfile"

    echo "📝 Increasing swap to ${SWAP_SIZE}MB for package compilation..."

    # Backup original configuration
    if [[ ! -f "${SWAP_FILE}.backup" ]]; then
        sudo cp "$SWAP_FILE" "${SWAP_FILE}.backup"
    fi

    # Update swap size
    sudo sed -i "s/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=${SWAP_SIZE}/" "$SWAP_FILE"

    # Apply changes
    sudo dphys-swapfile swapoff 2>/dev/null || true
    sudo dphys-swapfile setup
    sudo dphys-swapfile swapon

    # Verify
    local ACTUAL=$(free -m | awk '/Swap:/ {print $2}')
    echo "✅ Swap configured: ${ACTUAL}MB"
}

restore_swap() {
    local SWAP_FILE="/etc/dphys-swapfile"

    if [[ -f "${SWAP_FILE}.backup" ]]; then
        echo "♻️  Restoring original swap configuration..."
        sudo mv "${SWAP_FILE}.backup" "$SWAP_FILE"
        sudo dphys-swapfile swapoff
        sudo dphys-swapfile setup
        sudo dphys-swapfile swapon
        echo "✅ Swap restored to original size"
    fi
}

# Increase swap before package installation
configure_swap 1024

# Ensure swap is restored on script exit (success or failure)
trap restore_swap EXIT

###########################
# System Update
###########################

echo "🔧 Updating system..."
export DEBIAN_FRONTEND=noninteractive

if ! timeout 600 sudo apt -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" update; then
    echo "❌ apt update timed out or failed after 10 minutes"
    exit 1
fi

echo "📦 Upgrading existing packages..."
if ! timeout 1200 sudo apt -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" upgrade -y; then
    echo "❌ apt upgrade timed out or failed after 20 minutes"
    exit 1
fi

###########################
# Package Installation (Batched)
###########################

# Define package groups
CORE_PACKAGES=(python3 python3-venv python3-libgpiod git bc locales)
DISPLAY_PACKAGES=(xserver-xorg x11-xserver-utils xinit libmtdev1 libgles2-mesa)
MEDIA_PACKAGES=(libsdl2-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 imagemagick vlc)
NETWORK_PACKAGES=(wireguard rsync smbclient rclone resolvconf)
SERVICES_PACKAGES=(samba mosquitto mosquitto-clients inotify-tools btop)

# Installation function
install_package_batch() {
    local BATCH_NAME="$1"
    shift
    local PACKAGES=("$@")

    echo "📦 Installing ${BATCH_NAME}..."

    if ! timeout 600 sudo apt install -y --no-install-recommends "${PACKAGES[@]}"; then
        echo "❌ Failed to install ${BATCH_NAME} (timeout or error)"
        return 1
    fi

    echo "✅ ${BATCH_NAME} installed successfully"
    return 0
}

# Install each batch
install_package_batch "core packages" "${CORE_PACKAGES[@]}" || exit 1
install_package_batch "display packages" "${DISPLAY_PACKAGES[@]}" || exit 1
install_package_batch "media packages" "${MEDIA_PACKAGES[@]}" || exit 1
install_package_batch "network packages" "${NETWORK_PACKAGES[@]}" || exit 1
install_package_batch "services packages" "${SERVICES_PACKAGES[@]}" || exit 1

# Clean up to free space
echo "🧹 Cleaning apt cache..."
sudo apt clean
sudo apt autoremove -y

echo "✅ All packages installed successfully"

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
echo "⏳ Waiting for DNS to come back..."
MAX_DNS_RETRIES=30  # 30 attempts * 2 seconds = 60 seconds total
DNS_RETRY_COUNT=0

until ping -c1 -W5 8.8.8.8 >/dev/null 2>&1 || host google.com >/dev/null 2>&1; do
    DNS_RETRY_COUNT=$((DNS_RETRY_COUNT + 1))

    if [[ $DNS_RETRY_COUNT -ge $MAX_DNS_RETRIES ]]; then
        echo "❌ DNS not available after ${MAX_DNS_RETRIES} attempts (60 seconds)."
        echo "   Please check network connection and try again."
        exit 1
    fi

    echo "  Waiting for DNS... (attempt $DNS_RETRY_COUNT/$MAX_DNS_RETRIES)"
    sleep 2
done

echo "✅ DNS is available, continuing..."

echo "🌐 Configuring locales (en_US.UTF-8 and uk_UA.UTF-8)..."
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^# *uk_UA.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
sudo update-locale LANG=en_US.UTF-8

echo "🖥️ Configuring boot behaviour (Console Autologin)..."
sudo raspi-config nonint do_boot_behaviour B2

###########################
# Python Virtual Environment
###########################

VENV_PATH="/opt/picframe-env"

echo "🐍 Creating isolated Python environment at $VENV_PATH..."
sudo python3 -m venv "$VENV_PATH"
sudo chown -R $CURRENT_USER:$CURRENT_USER "$VENV_PATH"

echo "🐍 Activating virtual environment..."
source "$VENV_PATH/bin/activate"

echo "🐍 Upgrading pip in virtual environment..."
pip install --upgrade pip

echo "🐍 Installing Python packages..."
# Install only CircuitPython DHT (pure Python, no compilation needed)
pip install adafruit-circuitpython-dht
pip install adafruit-circuitpython-bme280
pip install adafruit-platformdetect
pip install paho-mqtt

# Picframe will be installed after git clone

echo "📥 Cloning picframe repository..."
cd "$HOME_DIR"

if [ -d "picframe" ]; then
    echo "⚠️  Existing picframe folder found, removing..."
    rm -rf picframe
fi

# Clone with timeout and shallow depth (faster, less memory)
echo "   Repository: https://github.com/ravado/picframe.git"
echo "   Branch: main"
echo "   Timeout: 5 minutes"

if ! timeout 300 git clone --depth 1 --single-branch -b main \
    https://github.com/ravado/picframe.git 2>&1 | tee /tmp/picframe-git-clone.log; then

    echo "❌ Git clone failed or timed out after 5 minutes"
    echo "   Check network connection and GitHub availability"
    echo "   Clone log saved to: /tmp/picframe-git-clone.log"
    exit 1
fi

cd picframe
echo "✅ Repository cloned successfully"

echo "🐍 Installing Picframe in development mode..."
# Ensure venv is activated
source "$VENV_PATH/bin/activate"
pip install -e .

echo "✅ Picframe installed in virtual environment"

# Switch to develop branch
git checkout develop

# echo "📂 Initializing Picframe config..."
# picframe -i "$HOME_DIR"
# mkdir -p "$HOME_DIR/.config/picframe"
# cp "$HOME_DIR/picframe_data/config/configuration.yaml" "$HOME_DIR/.config/picframe/"

echo "🎨 Starting X server for HDMI display..."
sudo X :0 -nolisten tcp &
X_PID=$!

echo "⏳ Waiting for X server to initialize..."
for i in $(seq 1 30); do
    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
        echo "✅ X server started successfully (${i}s)"
        break
    fi
    if ! kill -0 $X_PID 2>/dev/null; then
        echo "❌ X server process died"
        exit 1
    fi
    if [[ $i -eq 30 ]]; then
        echo "❌ X server failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

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
After=multi-user.target network-online.target
Wants=network-online.target

[Service]
User=$CURRENT_USER
Type=simple
Environment=DISPLAY=:0
Environment=XAUTHORITY=${HOME_DIR}/.Xauthority
Environment=LANG=en_US.UTF-8

# Activate virtual environment before running
ExecStart=/bin/bash -c 'source /opt/picframe-env/bin/activate && exec /usr/bin/xinit ${HOME_DIR}/picframe/picframe_data/launch.sh -- :0 -s 0 vt1 -keeptty'

Restart=always
RestartSec=10
StartLimitInterval=200
StartLimitBurst=5

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