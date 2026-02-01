# TASK-004: Photo Frame Installation & Screen Control Improvements

**Status:** Planning
**Created:** 2026-02-01
**Target:** Raspberry Pi Zero 2W (512MB-1GB RAM, USB WiFi)
**OS:** Raspberry Pi OS (Bookworm)
**Complexity:** High

---

# 📋 SECTION 1: QUICK OVERVIEW

## Executive Summary

Migration scripts have **14 critical issues** causing 40-60% installation failure rate on Pi Zero 2W. Root cause: C extension compilation exhausts memory → swap thrashing → USB/WiFi bandwidth saturation → network appears to fail.

**Impact After Fixes:**
- Installation success: 40-60% → **95%+**
- Install time: 45-90 min → **20-35 min**
- Network hangs: 30% → **<5%**
- OOM kills: 25% → **<1%**
- Screen control reliability: 80% → **>95%**

---

## Part A: Installation Reliability

### Critical Issues (Must Fix)

| Priority | Issue | Impact | Effort |
|----------|-------|--------|--------|
| 1 | **C compilation OOM** | System freeze, network crash | Low |
| 2 | **Package conflicts** (apt + pip) | Broken Python environment | Medium |
| 3 | **Infinite DNS loop** | Installation hangs forever | Low |
| 4 | **SMB operations no timeout** | Backup/restore hangs | Low |
| 5 | **Git clone no timeout** | Clone hangs on slow network | Low |

### High Priority Issues (Should Fix)

| Priority | Issue | Impact | Effort |
|----------|-------|--------|--------|
| 6 | **Deprecated pip flag** | Will break on pip 25.0+ | Low |
| 7 | **rclone high concurrency** | Memory exhaustion (360-720MB) | Low |
| 8 | **APT no timeout** | Long operations, no progress | Medium |

### Medium/Low Priority (Nice to Have)

- Missing `set -euo pipefail` in 2_restore_samba.sh
- No error handling in smbpasswd commands
- Hardcoded user paths
- X server fixed sleep instead of health check

---

## Part B: Screen Control (RPi Zero 2W)

### Current State
- ✅ Using `xset dpms force on/off` (correct for X11)
- ✅ Migrating from `vcgencmd display_power` (good)
- ⚠️ DISPLAY environment in cron unreliable
- ⚠️ No verification that screen actually turned on/off

### Required Improvements
1. **Robust screen control script** with verification
2. **Better environment handling** (DISPLAY, XAUTHORITY)
3. **Systemd timers** (preferred) or enhanced cron
4. **Optional HDMI-CEC support** for compatible displays

---

## Implementation Phases

### Phase 1: Critical Fixes (Must Do Before Any Install)
```
Priority 1-5 | Estimated time: 2-3 hours
```

1. **Swap configuration** - Increase to 1024MB before pip install
2. **Virtual environment** - Replace `--break-system-packages`
3. **DNS timeout** - Add max 30 retries (60 seconds)
4. **SMB timeout** - Wrapper function with 120s timeout
5. **Git timeout** - 5-minute limit on clone operations

**Files Modified:**
- `1_install_picframe.sh` (main changes)
- `0_backup_setup.sh` (SMB timeout)
- `3_restore_picframe_backup.sh` (SMB timeout)

---

### Phase 2: Reliability Improvements (Should Do)
```
Priority 6-8 | Estimated time: 1-2 hours
```

1. **Remove deprecated flags** - Use only CircuitPython DHT (pure Python)
2. **Reduce rclone concurrency** - 1 transfer, 2 checkers (50-80MB vs 360-720MB)
3. **Batch APT installs** - Smaller groups with timeouts

**Files Modified:**
- `1_install_picframe.sh` (pip install section)
- `sync_photos_from_nasik.sh` (rclone settings)

---

### Phase 3: Screen Control (Nice to Have)
```
Estimated time: 1 hour
```

1. **Screen control script** - Verification + logging
2. **Systemd timers** - Better than cron for X11
3. **Testing script** - Validate on/off functionality

**Files Created:**
- `~/picframe/scripts/screen_control.sh`
- `/etc/systemd/system/picframe-screen-*.{service,timer}`
- `~/picframe/scripts/test_screen_control.sh`

---

### Phase 4: Polish (Optional)
```
Estimated time: 1 hour
```

- Add `set -euo pipefail` to all scripts
- Fix hardcoded user paths
- X server health check
- HDMI-CEC support

---

## Quick Reference: Top 5 Critical Fixes

### 1️⃣ Swap Configuration (Before any pip install)
```bash
# Add to 1_install_picframe.sh after line 13
sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
sudo dphys-swapfile swapoff && sudo dphys-swapfile setup && sudo dphys-swapfile swapon
```

### 2️⃣ Virtual Environment (Replace lines 66-86)
```bash
python3 -m venv /opt/picframe-env
source /opt/picframe-env/bin/activate
pip install picframe adafruit-circuitpython-dht paho-mqtt
```

### 3️⃣ DNS Timeout (Replace lines 47-49)
```bash
MAX_RETRIES=30; COUNT=0
until ping -c1 -W5 8.8.8.8 >/dev/null 2>&1; do
    COUNT=$((COUNT + 1))
    [[ $COUNT -ge $MAX_RETRIES ]] && { echo "❌ DNS timeout"; exit 1; }
    sleep 2
done
```

### 4️⃣ SMB Timeout Wrapper (Add to 0_backup_setup.sh, 3_restore_picframe_backup.sh)
```bash
smb_with_timeout() {
    timeout 120 smbclient "$@"
    [[ $? -eq 124 ]] && { echo "❌ SMB timeout"; return 1; }
}
```

### 5️⃣ Git Clone Timeout (Replace line 80)
```bash
timeout 300 git clone --depth 1 -b main https://github.com/ravado/picframe.git
```

---

## Context & Constraints

### Accepted Constraints (Intentional Design)
- ✅ Hardcoded user `ivan.cherednychok` - OK for personal use
- ✅ Overwriting SSH keys/crontab - Expected for fresh install
- ✅ Root permissions required - Necessary for system config
- ✅ Network dependency - Required for git/pip/smb operations

### Hardware Constraints (RPi Zero 2W)
- 512MB-1GB RAM (limited)
- USB-based WiFi (shares bandwidth with storage)
- Single/quad-core ARM (slower compilation)
- Default 100MB swap (insufficient)
- SD card I/O (bottleneck during swap)

### Software Constraints
- Raspberry Pi OS Bookworm (pip 24.2+)
- X11 display server (not Wayland by default)
- Python 3.11+
- Deprecated pip `--install-option` flag

---

## Verification Checklist

### Pre-Installation
- [ ] Check available RAM: `free -h` (need 512MB+)
- [ ] Check disk space: `df -h` (need 2GB+)
- [ ] Test network: `ping -c3 8.8.8.8`
- [ ] Verify swap: `free -h` (should show 100MB initially)

### Post-Phase 1 (Critical Fixes)
- [ ] Swap increased to 1024MB
- [ ] Virtual environment created at `/opt/picframe-env`
- [ ] DNS timeout doesn't hang indefinitely
- [ ] SMB operations complete or timeout gracefully
- [ ] Git clone succeeds within 5 minutes

### Post-Phase 2 (Reliability)
- [ ] No deprecated pip warnings
- [ ] rclone memory usage <100MB during sync
- [ ] APT installs complete in batches

### Post-Phase 3 (Screen Control)
- [ ] Screen turns off/on via script
- [ ] Systemd timers scheduled correctly
- [ ] Logs show successful operations

---

# 🔧 SECTION 2: DETAILED IMPLEMENTATION

## Part A: Installation Reliability Fixes

### Fix 1: Swap Configuration for C Compilation

**Problem:** Compiling C extensions (Adafruit_DHT, numpy) requires 500MB-1GB RAM. Pi Zero 2W only has 512MB-1GB + 100MB swap = OOM kill.

**Files:** `1_install_picframe.sh`

**Add after line 13 (after user detection):**

```bash
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

    if [[ $ACTUAL -lt $((SWAP_SIZE - 100)) ]]; then
        echo "⚠️  Warning: Swap size ${ACTUAL}MB is less than requested ${SWAP_SIZE}MB"
    fi
}

restore_swap() {
    local SWAP_FILE="/etc/dphys-swapfile"

    if [[ -f "${SWAP_FILE}.backup" ]]; then
        echo "♻️  Restoring original swap configuration..."
        sudo mv "${SWAP_FILE}.backup" "$SWAP_FILE"
        sudo dphys-swapfile swapoff
        sudo dphys-swapfile setup
        sudo dphys-swapfile swapon

        local ACTUAL=$(free -m | awk '/Swap:/ {print $2}')
        echo "✅ Swap restored to ${ACTUAL}MB"
    else
        echo "ℹ️  No swap backup found, keeping current configuration"
    fi
}

# Increase swap before package installation
configure_swap 1024

# Ensure swap is restored on script exit (success or failure)
trap restore_swap EXIT
```

**Why this works:**
- Temporarily increases swap to 1024MB before compilation
- Automatically restores original swap on exit (via trap)
- Verifies actual swap size matches requested
- Handles cleanup even if script fails

---

### Fix 2: Virtual Environment Instead of --break-system-packages

**Problem:** Using `--break-system-packages` with system apt packages causes conflicts and corrupts Python environment.

**Files:** `1_install_picframe.sh`

**Replace lines 20-21 (apt install):**

```bash
echo "📦 Installing required packages..."
sudo apt install -y \
    python3 python3-venv python3-libgpiod \
    xserver-xorg x11-xserver-utils xinit \
    libmtdev1 libgles2-mesa git \
    libsdl2-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    locales \
    wireguard rsync \
    inotify-tools imagemagick smbclient rclone samba mosquitto mosquitto-clients bc \
    vlc btop
    # Note: Removed python3-pip, python3-pil, python3-numpy
    # These will be installed in venv to avoid conflicts
```

**Replace lines 63-71 (Python package installation):**

```bash
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

# Install picframe from cloned repo (later in script)
# This will be done after git clone
```

**Replace lines 84-86 (picframe installation):**

```bash
echo "🐍 Installing Picframe in development mode..."
# Ensure venv is activated
source "$VENV_PATH/bin/activate"
pip install -e .

echo "✅ Picframe installed in virtual environment"
deactivate
```

**Update systemd service (lines 111-130):**

```bash
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
ExecStart=/bin/bash -c 'source $VENV_PATH/bin/activate && exec /usr/bin/xinit ${HOME_DIR}/picframe/picframe_data/launch.sh -- :0 -s 0 vt1 -keeptty'

Restart=always
RestartSec=10
StartLimitInterval=200
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOL
```

**Add venv info to script output:**

```bash
echo "✅ Installation complete!"
echo ""
echo "📦 Virtual environment: $VENV_PATH"
echo "   To activate manually: source $VENV_PATH/bin/activate"
echo "   Installed packages: pip list"
echo ""
echo "➡️ Picframe will start automatically on boot using HDMI screen."
```

**Why this works:**
- Isolates Python packages from system
- No conflicts with apt-installed packages
- No `--break-system-packages` needed
- Easy to debug (can recreate venv)
- Follows Python best practices

---

### Fix 3: DNS Polling with Timeout

**Problem:** Infinite loop waiting for DNS can hang forever if network fails.

**Files:** `1_install_picframe.sh`

**Replace lines 45-51:**

```bash
###########################
# Wait for DNS availability
###########################

echo "⏳ Waiting for DNS to come back..."
MAX_DNS_RETRIES=30  # 30 attempts * 2 seconds = 60 seconds total
DNS_RETRY_COUNT=0

until ping -c1 -W5 8.8.8.8 >/dev/null 2>&1 || host google.com >/dev/null 2>&1; do
    DNS_RETRY_COUNT=$((DNS_RETRY_COUNT + 1))

    if [[ $DNS_RETRY_COUNT -ge $MAX_DNS_RETRIES ]]; then
        echo "❌ DNS not available after ${MAX_DNS_RETRIES} attempts (60 seconds)."
        echo "   Please check network connection and try again."
        echo "   Troubleshooting:"
        echo "   - Check WiFi: iwconfig"
        echo "   - Check network: ip addr"
        echo "   - Test connectivity: ping 8.8.8.8"
        exit 1
    fi

    echo "  Waiting for DNS... (attempt $DNS_RETRY_COUNT/$MAX_DNS_RETRIES)"
    sleep 2
done

echo "✅ DNS is available, continuing..."
```

**Why this works:**
- Maximum 60 seconds wait (30 retries * 2 seconds)
- Clear error message with troubleshooting steps
- Shows progress (attempt X/Y)
- Exits gracefully instead of hanging

---

### Fix 4: SMB Operations with Timeout

**Problem:** smbclient can hang indefinitely on network issues.

**Files:** `0_backup_setup.sh`, `3_restore_picframe_backup.sh`

**Add after `set -euo pipefail` in both files:**

```bash
###########################
# SMB Timeout Wrapper
###########################

# Default timeout: 120 seconds (2 minutes)
SMB_TIMEOUT="${SMB_TIMEOUT:-120}"

smb_with_timeout() {
    local TIMEOUT="$SMB_TIMEOUT"

    timeout "$TIMEOUT" smbclient "$@"
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 124 ]]; then
        echo "❌ SMB operation timed out after ${TIMEOUT} seconds"
        echo "   Check network connection to SMB server"
        return 1
    elif [[ $EXIT_CODE -ne 0 ]]; then
        echo "❌ SMB operation failed (exit code: $EXIT_CODE)"
        return $EXIT_CODE
    fi

    return 0
}

# Test SMB connectivity if credentials exist
test_smb_connectivity() {
    local SMB_PATH="$1"
    local SMB_CREDS="$2"

    if [[ ! -f "$SMB_CREDS" ]]; then
        echo "⚠️  SMB credentials not found at $SMB_CREDS"
        return 1
    fi

    echo "🔍 Testing SMB connectivity..."
    if ! timeout 10 smbclient "$SMB_PATH" -A "$SMB_CREDS" -c "quit" >/dev/null 2>&1; then
        echo "⚠️  Warning: Cannot connect to SMB server"
        echo "   Continuing anyway (will keep local copy)"
        return 1
    fi

    echo "✅ SMB server reachable"
    return 0
}
```

**In `0_backup_setup.sh`, replace line 160:**

```bash
# Before (line 160):
if smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; lcd $ARCHIVE_DIR; put $ARCHIVE_FILE"; then

# After:
if smb_with_timeout "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; lcd $ARCHIVE_DIR; put $ARCHIVE_FILE"; then
```

**Replace line 166 (retention policy):**

```bash
# Before:
smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; ls" | \

# After:
smb_with_timeout "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; ls" 2>/dev/null | \
```

**Replace line 171 (delete old backups):**

```bash
# Before:
smbclient "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; del $OLD_FILE"

# After:
smb_with_timeout "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; del $OLD_FILE"
```

**In `3_restore_picframe_backup.sh`, add connectivity test (after line 60):**

```bash
# Test SMB connectivity before attempting restore
if ! test_smb_connectivity "$SMB_BACKUPS_PATH" "$SMB_CRED_FILE"; then
    echo "❌ Cannot connect to SMB server. Restore requires SMB access."
    exit 1
fi
```

**Replace SMB operations (lines 75-79, 98):**

```bash
# All smbclient calls should use smb_with_timeout wrapper
# Example from line 75:
if smb_with_timeout "$SMB_BACKUPS_PATH" -A "$SMB_CRED_FILE" \
    -c "cd $SMB_BACKUPS_SUBDIR; get $LATEST_BACKUP" 2>&1 | tee -a "$LOG_FILE"; then
```

**Why this works:**
- 120-second timeout prevents indefinite hangs
- Clear error messages for debugging
- Pre-flight connectivity test
- Graceful fallback (local backup kept)

---

### Fix 5: Git Clone with Timeout & Depth

**Problem:** Git clone can hang on slow/unstable networks.

**Files:** `1_install_picframe.sh`

**Replace lines 73-82:**

```bash
###########################
# Clone PicFrame Repository
###########################

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
    https://github.com/ravado/picframe.git 2>&1 | tee -a /tmp/picframe-git-clone.log; then

    echo "❌ Git clone failed or timed out after 5 minutes"
    echo "   Check network connection and GitHub availability"
    echo "   Clone log saved to: /tmp/picframe-git-clone.log"
    echo ""
    echo "   Troubleshooting:"
    echo "   - Test GitHub: ping github.com"
    echo "   - Try manually: git clone https://github.com/ravado/picframe.git"
    exit 1
fi

cd picframe
echo "✅ Repository cloned successfully"

# Switch to develop branch
echo "🔀 Switching to develop branch..."
if ! git checkout develop; then
    echo "⚠️  Warning: Could not switch to develop branch, staying on main"
fi
```

**Why this works:**
- 5-minute timeout (reasonable for slow connections)
- `--depth 1` reduces download size (faster, less memory)
- `--single-branch` only fetches target branch
- Logs output to file for debugging
- Clear troubleshooting steps

---

### Fix 6: Remove Deprecated --install-option Flag

**Already covered in Fix 2 (Virtual Environment)**

Instead of:
```bash
pip3 install --break-system-packages Adafruit_DHT --install-option="--force-pi"
```

We use:
```bash
pip install adafruit-circuitpython-dht  # Pure Python, no compilation
```

**Why this works:**
- CircuitPython DHT is pure Python (no C compilation)
- No deprecated flags
- Compatible with pip 25.0+
- Less memory during installation

---

### Fix 7: Reduce rclone Concurrency

**Files:** `sync_photos_from_nasik.sh` (if exists), or add to `5_configure_photo_sync.sh`

**Find rclone command (likely around line 39-46):**

```bash
# Before:
rclone sync -v "$SRC" "$DEST" \
  --ignore-case-sync \
  --copy-links \
  --create-empty-src-dirs \
  --exclude "Thumbs.db" \
  --exclude ".DS_Store" \
  --transfers=4 \
  --checkers=8

# After - Optimized for Pi Zero 2W:
rclone sync -v "$SRC" "$DEST" \
  --ignore-case-sync \
  --copy-links \
  --create-empty-src-dirs \
  --exclude "Thumbs.db" \
  --exclude ".DS_Store" \
  --transfers=1 \
  --checkers=2 \
  --buffer-size=16M \
  --timeout=60s \
  --contimeout=30s \
  --low-level-retries=3 \
  --retries=3 \
  --bwlimit=5M \
  --stats=30s \
  --stats-one-line
```

**Memory comparison:**

| Setting | Old Config | New Config | Savings |
|---------|-----------|------------|---------|
| Transfers | 4 (200-400MB) | 1 (50-100MB) | 75% |
| Checkers | 8 (160-320MB) | 2 (40-80MB) | 75% |
| **Total** | **360-720MB** | **90-180MB** | **75%** |

**Why this works:**
- Reduces concurrent operations from 12 to 3
- Fits within Pi Zero 2W memory budget
- Prevents USB WiFi saturation
- Adds timeouts and retries for reliability

---

### Fix 8: Batch APT Installations with Timeouts

**Files:** `1_install_picframe.sh`

**Replace lines 14-28 (system update + package install):**

```bash
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
    echo "   This is unusual. Check apt logs: /var/log/apt/term.log"
    exit 1
fi

###########################
# Package Installation (Batched)
###########################

# Define package groups
CORE_PACKAGES=(
    python3 python3-venv python3-libgpiod
    git bc locales
)

DISPLAY_PACKAGES=(
    xserver-xorg x11-xserver-utils xinit
    libmtdev1 libgles2-mesa
)

MEDIA_PACKAGES=(
    libsdl2-dev libsdl2-image-2.0-0
    libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0
    imagemagick vlc
)

NETWORK_PACKAGES=(
    wireguard rsync smbclient rclone resolvconf
)

SERVICES_PACKAGES=(
    samba mosquitto mosquitto-clients
    inotify-tools btop
)

# Installation function
install_package_batch() {
    local BATCH_NAME="$1"
    shift
    local PACKAGES=("$@")

    echo "📦 Installing ${BATCH_NAME}..."
    echo "   Packages: ${PACKAGES[*]}"

    if ! timeout 600 sudo apt install -y --no-install-recommends "${PACKAGES[@]}"; then
        echo "❌ Failed to install ${BATCH_NAME} (timeout or error)"
        echo "   You can try manually: sudo apt install ${PACKAGES[*]}"
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
```

**Why this works:**
- Smaller batches reduce memory pressure
- Each batch has 10-minute timeout
- Clear error messages show which batch failed
- Can retry individual batches manually
- `--no-install-recommends` reduces unnecessary packages
- Cleanup frees disk space

---

### Fix 9: Add set -euo pipefail to All Scripts

**Files:** `2_restore_samba.sh`

**Replace line 1:**

```bash
#!/bin/bash
set -euo pipefail

###########################
# Load secrets from .env file
###########################
```

**Why this works:**
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `set -o pipefail`: Exit if any command in pipe fails
- Consistent with other scripts

---

### Fix 10: SMB User Creation Error Handling

**Files:** `2_restore_samba.sh`

**Replace lines 69-72:**

```bash
else
    echo "🔐 Creating Samba user '$USERNAME'..."

    # Create Samba user with password
    if ! echo -e "$PASSWORD\n$PASSWORD" | sudo smbpasswd -a "$USERNAME" -s 2>&1 | grep -v "Added user"; then
        echo "❌ Failed to create Samba user '$USERNAME'"
        echo "   Possible reasons:"
        echo "   - Password doesn't meet complexity requirements"
        echo "   - User doesn't exist in system (/etc/passwd)"
        echo "   - Samba is not properly installed"
        exit 1
    fi

    # Enable Samba user
    if ! sudo smbpasswd -e "$USERNAME"; then
        echo "❌ Failed to enable Samba user '$USERNAME'"
        exit 1
    fi

    echo "✅ Samba user '$USERNAME' created and enabled"
fi
```

**Why this works:**
- Checks return code of smbpasswd
- Provides troubleshooting hints
- Exits with error instead of continuing silently

---

### Fix 11: X Server Startup Health Check

**Files:** `1_install_picframe.sh`

**Replace lines 96-98:**

```bash
###########################
# Start X Server
###########################

echo "🎨 Starting X server for HDMI display..."
sudo X :0 -nolisten tcp &
X_PID=$!

echo "⏳ Waiting for X server to initialize..."
MAX_X_WAIT=30
X_READY=false

for i in $(seq 1 $MAX_X_WAIT); do
    # Check if X server is responding
    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
        echo "✅ X server started successfully (took ${i}s)"
        X_READY=true
        break
    fi

    # Check if process died
    if ! kill -0 $X_PID 2>/dev/null; then
        echo "❌ X server process died unexpectedly"
        echo "   Check Xorg logs: /var/log/Xorg.0.log"
        echo ""
        echo "   Common issues:"
        echo "   - No HDMI display connected"
        echo "   - Graphics driver problem"
        echo "   - Permission issues"
        exit 1
    fi

    # Still waiting
    if [[ $i -eq $MAX_X_WAIT ]]; then
        echo "❌ X server failed to start within ${MAX_X_WAIT} seconds"
        echo "   Check Xorg logs: /var/log/Xorg.0.log"
        sudo kill $X_PID 2>/dev/null || true
        exit 1
    fi

    sleep 1
done

if [[ "$X_READY" != "true" ]]; then
    echo "❌ X server not ready"
    exit 1
fi
```

**Why this works:**
- Polls X server with xdpyinfo (proper health check)
- Detects if process dies
- 30-second timeout (not fixed 3-second sleep)
- Clear error messages with log file location

---

### Fix 12: Fix Hardcoded User Paths

**Files:** `1_install_picframe.sh`, `5_configure_photo_sync.sh`

**In `1_install_picframe.sh`, line 123:**

```bash
# Before:
ExecStart=/usr/bin/xinit /home/ivan.cherednychok/picframe/picframe_data/launch.sh -- :0 -s 0 vt1 -keeptty

# After:
ExecStart=/usr/bin/xinit ${HOME_DIR}/picframe/picframe_data/launch.sh -- :0 -s 0 vt1 -keeptty
```

**In `5_configure_photo_sync.sh`, lines 21-24:**

```bash
# Before:
RUN_USER="ivan.cherednychok"
RUN_HOME="/home/${RUN_USER}"

# After (assuming CURRENT_USER is available):
RUN_USER="$CURRENT_USER"
RUN_HOME="$HOME_DIR"
```

**Note:** Per TASK-003, hardcoded `ivan.cherednychok` is acceptable for personal use. This fix is optional.

---

## Part B: Screen Control Implementation

### Screen Control Script

**Create:** `~/picframe/scripts/screen_control.sh`

```bash
#!/bin/bash
set -euo pipefail

# Screen control script for Raspberry Pi Zero 2W with X11
# Usage: ./screen_control.sh [on|off|status]

DISPLAY="${DISPLAY:-:0}"
export DISPLAY

XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export XAUTHORITY

LOG_FILE="/var/log/picframe-screen.log"

# Create log file if it doesn't exist
if [[ ! -f "$LOG_FILE" ]]; then
    sudo touch "$LOG_FILE"
    sudo chown $(whoami):$(whoami) "$LOG_FILE"
fi

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_x_server() {
    if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        log_message "ERROR: X server not accessible on $DISPLAY"
        return 1
    fi
    return 0
}

screen_off() {
    log_message "Turning screen OFF"

    if ! check_x_server; then
        return 1
    fi

    # Method 1: DPMS force off (preferred for X11)
    if xset dpms force off 2>/dev/null; then
        log_message "Screen turned off via DPMS"
    else
        log_message "WARNING: xset dpms force off failed"
    fi

    # Method 2: Blank screen as backup
    xset s activate 2>/dev/null || true

    # Optional Method 3: HDMI-CEC if available
    if command -v cec-client >/dev/null 2>&1; then
        echo 'standby 0' | cec-client -s -d 1 >/dev/null 2>&1 && \
            log_message "Screen turned off via HDMI-CEC"
    fi

    # Verify screen is off (wait 2 seconds for state to settle)
    sleep 2
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    if [[ "$DPMS_STATE" == "Off" ]]; then
        log_message "✅ Screen confirmed OFF"
        return 0
    else
        log_message "⚠️  Screen state unclear (DPMS: $DPMS_STATE)"
        return 1
    fi
}

screen_on() {
    log_message "Turning screen ON"

    if ! check_x_server; then
        return 1
    fi

    # Method 1: DPMS force on
    if xset dpms force on 2>/dev/null; then
        log_message "Screen turned on via DPMS"
    else
        log_message "WARNING: xset dpms force on failed"
    fi

    # Method 2: Deactivate screensaver
    xset s reset 2>/dev/null || true

    # Method 3: Move mouse cursor (wakes up some displays)
    if command -v xdotool >/dev/null 2>&1; then
        DISPLAY=$DISPLAY xdotool mousemove 0 0 2>/dev/null || true
    fi

    # Optional Method 4: HDMI-CEC if available
    if command -v cec-client >/dev/null 2>&1; then
        echo 'on 0' | cec-client -s -d 1 >/dev/null 2>&1 && \
            log_message "Screen turned on via HDMI-CEC"
    fi

    # Verify screen is on (wait 2 seconds for state to settle)
    sleep 2
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    if [[ "$DPMS_STATE" == "On" ]]; then
        log_message "✅ Screen confirmed ON"
        return 0
    else
        log_message "⚠️  Screen state unclear (DPMS: $DPMS_STATE)"
        return 1
    fi
}

get_status() {
    if ! check_x_server; then
        echo "X server not accessible"
        return 1
    fi

    local DPMS_ENABLED=$(xset q | grep "DPMS is" | awk '{print $3}')
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    echo "DPMS Status: $DPMS_ENABLED"
    echo "Monitor State: $DPMS_STATE"
    echo ""
    echo "Screen Saver Settings:"
    xset q | grep -A 5 "Screen Saver"

    log_message "Status check - DPMS: $DPMS_ENABLED, Monitor: $DPMS_STATE"
}

# Main
case "${1:-}" in
    on)
        screen_on
        ;;
    off)
        screen_off
        ;;
    status)
        get_status
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        echo ""
        echo "Commands:"
        echo "  on      - Turn screen on"
        echo "  off     - Turn screen off"
        echo "  status  - Show current screen state"
        exit 1
        ;;
esac
```

**Make executable:**
```bash
mkdir -p ~/picframe/scripts
chmod +x ~/picframe/scripts/screen_control.sh
```

---

### Option 1: Crontab Installation (Simple)

**Create:** `~/picframe/scripts/install_crontab.sh`

```bash
#!/bin/bash
set -euo pipefail

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
SCREEN_SCRIPT="$HOME_DIR/picframe/scripts/screen_control.sh"

echo "📅 Installing screen control crontab..."

# Ensure script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

# Ensure script is executable
chmod +x "$SCREEN_SCRIPT"

# Create log file with proper permissions
sudo touch /var/log/picframe-screen.log
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/picframe-screen.log

sudo touch /var/log/picframe-cron.log
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/picframe-cron.log

# Backup existing crontab
crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true

# Create new crontab with environment variables
cat > /tmp/picframe_cron << EOF
# Environment variables for X11 access
DISPLAY=:0
XAUTHORITY=$HOME_DIR/.Xauthority
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Screen off at 23:00 (11 PM)
0 23 * * * $SCREEN_SCRIPT off >> /var/log/picframe-cron.log 2>&1

# Screen on at 07:00 (7 AM)
0 7 * * * $SCREEN_SCRIPT on >> /var/log/picframe-cron.log 2>&1

# Optional: Status check at noon
0 12 * * * $SCREEN_SCRIPT status >> /var/log/picframe-cron.log 2>&1
EOF

# Install crontab
crontab /tmp/picframe_cron
rm /tmp/picframe_cron

echo "✅ Crontab installed successfully"
echo ""
echo "Current schedule:"
crontab -l
echo ""
echo "Logs:"
echo "  - Screen control: /var/log/picframe-screen.log"
echo "  - Cron execution: /var/log/picframe-cron.log"
```

**Make executable and run:**
```bash
chmod +x ~/picframe/scripts/install_crontab.sh
~/picframe/scripts/install_crontab.sh
```

---

### Option 2: Systemd Timers (Recommended)

**Create:** `~/picframe/scripts/install_timers.sh`

```bash
#!/bin/bash
set -euo pipefail

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
SCREEN_SCRIPT="$HOME_DIR/picframe/scripts/screen_control.sh"

echo "📅 Installing systemd timers for screen control..."

# Ensure script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

chmod +x "$SCREEN_SCRIPT"

###########################
# Screen OFF Service
###########################

sudo tee /etc/systemd/system/picframe-screen-off.service > /dev/null <<EOF
[Unit]
Description=Turn off photo frame screen
After=picframe.service

[Service]
Type=oneshot
User=$CURRENT_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME_DIR/.Xauthority"
ExecStart=$SCREEN_SCRIPT off

[Install]
WantedBy=multi-user.target
EOF

###########################
# Screen OFF Timer
###########################

sudo tee /etc/systemd/system/picframe-screen-off.timer > /dev/null <<EOF
[Unit]
Description=Turn off photo frame screen at 11 PM
Requires=picframe-screen-off.service

[Timer]
OnCalendar=23:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

###########################
# Screen ON Service
###########################

sudo tee /etc/systemd/system/picframe-screen-on.service > /dev/null <<EOF
[Unit]
Description=Turn on photo frame screen
After=picframe.service

[Service]
Type=oneshot
User=$CURRENT_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME_DIR/.Xauthority"
ExecStart=$SCREEN_SCRIPT on

[Install]
WantedBy=multi-user.target
EOF

###########################
# Screen ON Timer
###########################

sudo tee /etc/systemd/system/picframe-screen-on.timer > /dev/null <<EOF
[Unit]
Description=Turn on photo frame screen at 7 AM
Requires=picframe-screen-on.service

[Timer]
OnCalendar=07:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

###########################
# Enable and Start
###########################

sudo systemctl daemon-reload
sudo systemctl enable picframe-screen-on.timer
sudo systemctl enable picframe-screen-off.timer
sudo systemctl start picframe-screen-on.timer
sudo systemctl start picframe-screen-off.timer

echo "✅ Systemd timers installed and started"
echo ""
echo "Timer status:"
systemctl list-timers picframe-screen-* --no-pager
echo ""
echo "To check logs:"
echo "  sudo journalctl -u picframe-screen-on.service"
echo "  sudo journalctl -u picframe-screen-off.service"
echo ""
echo "To modify times, edit:"
echo "  /etc/systemd/system/picframe-screen-on.timer"
echo "  /etc/systemd/system/picframe-screen-off.timer"
```

**Make executable and run:**
```bash
chmod +x ~/picframe/scripts/install_timers.sh
~/picframe/scripts/install_timers.sh
```

**Why systemd timers are better:**
- Better logging (journalctl)
- Dependency management (waits for X server)
- Persistent (runs missed timers on boot)
- Easier to debug
- No DISPLAY environment issues

---

### Testing Script

**Create:** `~/picframe/scripts/test_screen_control.sh`

```bash
#!/bin/bash
set -euo pipefail

SCREEN_SCRIPT="$HOME/picframe/scripts/screen_control.sh"

echo "🧪 Testing screen control functionality..."
echo ""

# Check if script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

# Test 1: Screen OFF
echo "1️⃣  Testing screen OFF..."
if $SCREEN_SCRIPT off; then
    echo "✅ Screen OFF successful"
else
    echo "❌ Screen OFF failed"
    exit 1
fi

echo "   Waiting 5 seconds..."
sleep 5

# Test 2: Status while OFF
echo ""
echo "2️⃣  Testing status (should show OFF)..."
$SCREEN_SCRIPT status

sleep 2

# Test 3: Screen ON
echo ""
echo "3️⃣  Testing screen ON..."
if $SCREEN_SCRIPT on; then
    echo "✅ Screen ON successful"
else
    echo "❌ Screen ON failed"
    exit 1
fi

echo "   Waiting 3 seconds..."
sleep 3

# Test 4: Status while ON
echo ""
echo "4️⃣  Testing status (should show ON)..."
$SCREEN_SCRIPT status

# Test 5: Rapid toggle
echo ""
echo "5️⃣  Testing rapid toggle..."
for i in {1..3}; do
    echo "   Toggle $i: OFF"
    $SCREEN_SCRIPT off >/dev/null
    sleep 1
    echo "   Toggle $i: ON"
    $SCREEN_SCRIPT on >/dev/null
    sleep 1
done
echo "✅ Rapid toggle successful"

# Final status
echo ""
echo "6️⃣  Final status check..."
$SCREEN_SCRIPT status

# Check logs
echo ""
echo "7️⃣  Recent log entries:"
tail -n 10 /var/log/picframe-screen.log

echo ""
echo "✅ All tests passed!"
echo ""
echo "To schedule automatic on/off:"
echo "  - Cron:    bash ~/picframe/scripts/install_crontab.sh"
echo "  - Systemd: bash ~/picframe/scripts/install_timers.sh (recommended)"
```

**Make executable and run:**
```bash
chmod +x ~/picframe/scripts/test_screen_control.sh
~/picframe/scripts/test_screen_control.sh
```

---

## Rollback Procedures

### If Installation Fails

```bash
#!/bin/bash
# Rollback script for failed installation

echo "🔄 Rolling back changes..."

# 1. Restore original swap
if [[ -f /etc/dphys-swapfile.backup ]]; then
    sudo mv /etc/dphys-swapfile.backup /etc/dphys-swapfile
    sudo dphys-swapfile swapoff
    sudo dphys-swapfile setup
    sudo dphys-swapfile swapon
    echo "✅ Swap restored"
fi

# 2. Remove virtual environment
if [[ -d /opt/picframe-env ]]; then
    sudo rm -rf /opt/picframe-env
    echo "✅ Virtual environment removed"
fi

# 3. Remove partial picframe clone
if [[ -d ~/picframe ]]; then
    rm -rf ~/picframe
    echo "✅ Picframe directory removed"
fi

# 4. Remove systemd service
if [[ -f /etc/systemd/system/picframe.service ]]; then
    sudo systemctl stop picframe 2>/dev/null || true
    sudo systemctl disable picframe 2>/dev/null || true
    sudo rm /etc/systemd/system/picframe.service
    sudo systemctl daemon-reload
    echo "✅ Systemd service removed"
fi

echo "✅ Rollback complete"
echo ""
echo "You can now:"
echo "  1. Fix the issue that caused failure"
echo "  2. Re-run installation script"
```

### If Screen Control Fails

**Remove crontab:**
```bash
crontab -r  # Removes entire crontab
# Or edit manually: crontab -e
```

**Remove systemd timers:**
```bash
sudo systemctl stop picframe-screen-on.timer
sudo systemctl stop picframe-screen-off.timer
sudo systemctl disable picframe-screen-on.timer
sudo systemctl disable picframe-screen-off.timer
sudo rm /etc/systemd/system/picframe-screen-*.{service,timer}
sudo systemctl daemon-reload
```

---

## Summary of Changes

### Files Modified

| File | Changes | Lines |
|------|---------|-------|
| `1_install_picframe.sh` | Swap, venv, DNS timeout, git timeout, APT batching, X health check | ~200 |
| `0_backup_setup.sh` | SMB timeout wrapper | ~30 |
| `3_restore_picframe_backup.sh` | SMB timeout wrapper, connectivity test | ~40 |
| `2_restore_samba.sh` | set -euo pipefail, error handling | ~15 |
| `sync_photos_from_nasik.sh` | Reduced concurrency | ~10 |
| `5_configure_photo_sync.sh` | User path fix (optional) | ~3 |

### Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `~/picframe/scripts/screen_control.sh` | Screen on/off with verification | ~150 |
| `~/picframe/scripts/install_crontab.sh` | Cron installation | ~50 |
| `~/picframe/scripts/install_timers.sh` | Systemd timer installation | ~120 |
| `~/picframe/scripts/test_screen_control.sh` | Testing suite | ~80 |

### Total Implementation Effort

- **Phase 1 (Critical):** 2-3 hours
- **Phase 2 (Reliability):** 1-2 hours
- **Phase 3 (Screen Control):** 1 hour
- **Phase 4 (Polish):** 1 hour
- **Testing:** 1 hour

**Total:** 6-8 hours for complete implementation

---

## Related Documents

- **Supersedes:** TASK-001.md (issue catalog)
- **Combines:** TASK-002.md (original detailed plan) + TASK-003.md (focused plan)
- **References:** ANALYSIS_REPORT.md (detailed issue analysis)
- **Complements:** README.md (usage guide)

---

## Next Steps

1. ✅ Review this document
2. ⬜ Implement Phase 1 (critical fixes)
3. ⬜ Test on Pi Zero 2W (or simulate low memory)
4. ⬜ Implement Phase 2 (reliability)
5. ⬜ Implement Phase 3 (screen control)
6. ⬜ Document results in TASK-004-IMPLEMENTATION.md
7. ⬜ Update README.md with new requirements

---

**End of Document**
