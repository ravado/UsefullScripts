# Fix Installation Dependencies and Initialization Issues

## Goal

Make the installation script more robust by adding proper error handling, dependency validation, and fixing the picframe initialization step that's currently failing silently.

## Problem Analysis

**Current Issue**: User runs picframe after installation and gets:
```
FileNotFoundError: [Errno 2] No such file or directory: '/home/pi/picframe_data/config/configuration.yaml'
```

**Root Causes Identified**:
1. Step 5 (picframe installation) uses `if (echo ... | ...) then` which may succeed even if initialization fails
2. No verification that `configuration.yaml` was actually created
3. Missing error output when initialization fails
4. No pre-flight checks for system dependencies
5. Progress tracking continues even if critical steps fail
6. No rollback or retry mechanism for failed steps
7. **Missing hardware sensor Python packages** (gpiod, Adafruit CircuitPython libraries)
8. No verification that installed packages are actually importable

## Changes

### 1. Add Pre-Flight Dependency Check (New Step 0)

**File**: `1_install_picframe_developer_mode.sh`

**Insert before Step 1** (before line 101):

```bash
# Step 0: Pre-flight system checks
if [ "$LAST_COMPLETED_STEP" -lt 0 ]; then
    log_message "Step 0: Running pre-flight checks..."

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_message "❌ ERROR: Do not run this script as root (use regular user with sudo access)"
        exit 1
    fi

    # Check if target user exists
    if ! id "$INSTALL_USER" &>/dev/null; then
        log_message "❌ ERROR: User '$INSTALL_USER' does not exist on this system"
        log_message "   Create the user first with: sudo adduser $INSTALL_USER"
        exit 1
    fi

    # Check if current user has sudo access
    if ! sudo -n true 2>/dev/null; then
        log_message "⚠️  WARNING: Current user may need to enter sudo password during installation"
    fi

    # Check available disk space (need at least 2GB)
    available_space=$(df /home | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 2000000 ]; then
        log_message "❌ ERROR: Insufficient disk space (need at least 2GB free in /home)"
        exit 1
    fi

    # Check available memory (warn if less than 512MB)
    available_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$available_mem" -lt 512 ]; then
        log_message "⚠️  WARNING: Low memory detected (${available_mem}MB). Installation may be slow."
        log_message "   Consider increasing swap size: sudo dphys-swapfile swapoff && sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile && sudo dphys-swapfile setup && sudo dphys-swapfile swapon"
    fi

    # Check internet connectivity
    check_internet_connection

    log_message "✅ Pre-flight checks passed"
    update_progress 0
fi
```

**Adjust all subsequent step numbers**: Step 1 becomes "if [ $LAST_COMPLETED_STEP -lt 1 ]" (already correct)

### 2. Fix Step 5 - Add Robust Error Handling for Picframe Installation

**File**: `1_install_picframe_developer_mode.sh`

**Replace lines 193-235** (entire Step 5):

```bash
# Step 5: Installing picframe in developer mode
if [ "$LAST_COMPLETED_STEP" -lt 5 ]; then
    check_internet_connection
    log_message "Step 5: Installing picframe in developer mode..."

    # Clone the repository
    log_message "Cloning picframe repository from $REPO_URL..."
    if [ ! -d "$REPO_PATH" ]; then
        if ! su - $INSTALL_USER -c "git clone $REPO_URL $REPO_PATH" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "❌ ERROR: Failed to clone repository"
            exit 1
        fi
    else
        log_message "Repository already exists at $REPO_PATH"
    fi

    # Checkout develop branch
    log_message "Checking out $REPO_BRANCH branch..."
    if ! su - $INSTALL_USER -c "cd $REPO_PATH && git checkout $REPO_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "❌ ERROR: Failed to checkout $REPO_BRANCH branch"
        exit 1
    fi

    # Create virtual environment
    log_message "Creating virtual environment for picframe..."
    if ! su - $INSTALL_USER -c "python3 -m venv $VENV_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "❌ ERROR: Failed to create virtual environment"
        exit 1
    fi

    # Upgrade pip first
    log_message "Upgrading pip in virtual environment..."
    if ! su - $INSTALL_USER -c "$VENV_PATH/bin/pip install --upgrade pip" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "⚠️  WARNING: Failed to upgrade pip (continuing anyway)"
    fi

    # Install paho-mqtt
    log_message "Installing paho-mqtt..."
    if ! su - $INSTALL_USER -c "$VENV_PATH/bin/pip install paho-mqtt" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "❌ ERROR: Failed to install paho-mqtt"
        exit 1
    fi

    # Install hardware sensor dependencies (Adafruit CircuitPython libraries)
    # NOTE: Using CircuitPython versions to avoid C compilation that can OOM on Pi Zero 2W
    log_message "Installing hardware sensor libraries..."
    SENSOR_PACKAGES=(
        "gpiod"
        "adafruit-blinka"
        "adafruit-platformdetect"
        "adafruit-circuitpython-bme280"
        "adafruit-circuitpython-dht"
        "adafruit-circuitpython-bme680"
        "adafruit-circuitpython-ahtx0"
    )

    for package in "${SENSOR_PACKAGES[@]}"; do
        log_message "Installing $package..."
        if ! su - $INSTALL_USER -c "$VENV_PATH/bin/pip install $package" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "⚠️  WARNING: Failed to install $package (continuing anyway)"
            log_message "   Sensor functionality may be limited"
        else
            log_message "✅ $package installed successfully"
        fi
    done

    # Install picframe in developer/editable mode
    log_message "Installing picframe in developer/editable mode..."
    if ! su - $INSTALL_USER -c "cd $REPO_PATH && $VENV_PATH/bin/pip install -e ." 2>&1 | tee -a "$LOG_FILE"; then
        log_message "❌ ERROR: Failed to install picframe"
        exit 1
    fi

    # Verify picframe was installed
    if ! su - $INSTALL_USER -c "$VENV_PATH/bin/picframe --version" &>/dev/null; then
        log_message "⚠️  WARNING: picframe command not found after installation"
    else
        PICFRAME_VERSION=$(su - $INSTALL_USER -c "$VENV_PATH/bin/picframe --version" 2>&1 || echo "unknown")
        log_message "✅ picframe installed successfully (version: $PICFRAME_VERSION)"
    fi

    # Initialize Picframe and confirm default directories
    log_message "Initializing Picframe with default directories..."

    # Create a temporary expect script to handle initialization prompts
    INIT_SCRIPT="/tmp/picframe_init_$$.exp"
    cat > "$INIT_SCRIPT" <<'EOF'
#!/usr/bin/expect -f
set timeout 30
set venv_path [lindex $argv 0]
set install_user [lindex $argv 1]

spawn su - $install_user -c "$venv_path/bin/picframe -i /home/$install_user/"
expect {
    "picture directory*" { send "\r"; exp_continue }
    "Deleted picture directory*" { send "\r"; exp_continue }
    "Configuration file*" { send "\r"; exp_continue }
    eof
}
EOF
    chmod +x "$INIT_SCRIPT"

    # Run initialization with expect for better control
    if expect "$INIT_SCRIPT" "$VENV_PATH" "$INSTALL_USER" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "Picframe initialization command completed"
    else
        log_message "⚠️  WARNING: Picframe initialization returned non-zero exit code"
    fi

    rm -f "$INIT_SCRIPT"

    # CRITICAL: Verify configuration file was actually created
    CONFIG_FILE="$DATA_PATH/config/configuration.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "❌ ERROR: Configuration file not created at $CONFIG_FILE"
        log_message "   Attempting manual creation from template..."

        # Create directories manually
        su - $INSTALL_USER -c "mkdir -p $DATA_PATH/config"
        su - $INSTALL_USER -c "mkdir -p /home/$INSTALL_USER/Pictures"
        su - $INSTALL_USER -c "mkdir -p /home/$INSTALL_USER/DeletedPictures"

        # Try to copy default config from picframe package
        if [ -f "$REPO_PATH/src/picframe/data/configuration.yaml" ]; then
            su - $INSTALL_USER -c "cp $REPO_PATH/src/picframe/data/configuration.yaml $CONFIG_FILE"
            log_message "✅ Copied default configuration from package"
        else
            log_message "❌ FATAL: Cannot find default configuration template"
            log_message "   Installation cannot continue - picframe will not run without config"
            exit 1
        fi
    else
        log_message "✅ Configuration file verified at $CONFIG_FILE"
    fi

    # Verify all expected directories exist
    for dir in "$DATA_PATH/config" "/home/$INSTALL_USER/Pictures" "/home/$INSTALL_USER/DeletedPictures"; do
        if [ ! -d "$dir" ]; then
            log_message "⚠️  WARNING: Expected directory missing: $dir (creating now)"
            su - $INSTALL_USER -c "mkdir -p $dir"
        fi
    done

    log_message "✅ Step 5 completed successfully"
    update_progress 5
fi
```

### 3. Add Post-Installation Verification Step

**File**: `1_install_picframe_developer_mode.sh`

**Insert after Step 8** (before the final cleanup, around line 322):

```bash
# Step 9: Post-installation verification
if [ "$LAST_COMPLETED_STEP" -ge 8 ] && [ "$LAST_COMPLETED_STEP" -lt 9 ]; then
    log_message "Step 9: Running post-installation verification..."

    # Verify picframe binary exists and is executable
    if [ ! -x "$VENV_PATH/bin/picframe" ]; then
        log_message "❌ ERROR: picframe binary not found or not executable"
        exit 1
    fi

    # Verify configuration file exists
    CONFIG_FILE="$DATA_PATH/config/configuration.yaml"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "❌ ERROR: Configuration file missing at $CONFIG_FILE"
        exit 1
    fi

    # Verify systemd service exists
    SYSTEMD_SERVICE_FILE="/home/$INSTALL_USER/.config/systemd/user/picframe.service"
    if [ ! -f "$SYSTEMD_SERVICE_FILE" ]; then
        log_message "❌ ERROR: Systemd service file missing"
        exit 1
    fi

    # Verify directories exist and are writable
    for dir in "/home/$INSTALL_USER/Pictures" "/home/$INSTALL_USER/DeletedPictures" "$DATA_PATH"; do
        if [ ! -d "$dir" ]; then
            log_message "❌ ERROR: Required directory missing: $dir"
            exit 1
        fi
        if [ ! -w "$dir" ]; then
            log_message "❌ ERROR: Directory not writable: $dir"
            exit 1
        fi
    done

    # Test picframe config validation (don't actually start it)
    log_message "Testing picframe configuration..."
    if su - $INSTALL_USER -c "$VENV_PATH/bin/python3 -c 'import yaml; yaml.safe_load(open(\"$CONFIG_FILE\"))'" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "✅ Configuration file is valid YAML"
    else
        log_message "⚠️  WARNING: Configuration file may have YAML syntax errors"
    fi

    # Verify critical Python packages are importable
    log_message "Verifying Python package installations..."
    CRITICAL_PACKAGES=("picframe" "paho.mqtt.client" "yaml")
    SENSOR_PACKAGES=("board" "adafruit_dht" "adafruit_bme280" "adafruit_bme680" "adafruit_ahtx0")

    for package in "${CRITICAL_PACKAGES[@]}"; do
        package_import=$(echo "$package" | sed 's/\..*//') # Get first part for import
        if su - $INSTALL_USER -c "$VENV_PATH/bin/python3 -c 'import $package_import'" 2>/dev/null; then
            log_message "✅ $package is importable"
        else
            log_message "❌ ERROR: $package cannot be imported"
            exit 1
        fi
    done

    # Sensor packages are optional (warn but don't fail)
    for package in "${SENSOR_PACKAGES[@]}"; do
        if su - $INSTALL_USER -c "$VENV_PATH/bin/python3 -c 'import $package'" 2>/dev/null; then
            log_message "✅ $package is importable"
        else
            log_message "⚠️  WARNING: $package cannot be imported (sensor features may not work)"
        fi
    done

    log_message "✅ Post-installation verification completed"
    log_message ""
    log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "📦 Installation Summary:"
    log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "User:              $INSTALL_USER"
    log_message "Virtual Env:       $VENV_PATH"
    log_message "Repository:        $REPO_PATH (branch: $REPO_BRANCH)"
    log_message "Data Directory:    $DATA_PATH"
    log_message "Config File:       $CONFIG_FILE"
    log_message "Pictures:          /home/$INSTALL_USER/Pictures"
    log_message "Deleted Pictures:  /home/$INSTALL_USER/DeletedPictures"
    log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message ""
    log_message "✅ All checks passed! PicFrame is ready to use."
    log_message ""
    log_message "Next steps:"
    log_message "1. Add photos to /home/$INSTALL_USER/Pictures/"
    log_message "2. Edit config: nano $CONFIG_FILE"
    log_message "3. Start picframe: systemctl --user start picframe"
    log_message "4. Check status: systemctl --user status picframe"
    log_message ""

    update_progress 9
fi

# Final step: Remove the systemd service only if all steps are completed
if [ "$LAST_COMPLETED_STEP" -ge 9 ]; then
    remove_systemd_service
    log_message "Installation complete! System will reboot in 10 seconds..."
    sleep 10
    sudo reboot
fi
```

### 4. Update Final Cleanup Logic

**File**: `1_install_picframe_developer_mode.sh`

**Replace lines 323-327**:

```bash
# Final step: Remove the systemd service only if all steps are completed
if [ "$LAST_COMPLETED_STEP" -ge 9 ]; then
    remove_systemd_service
    log_message "Installation complete! System will reboot in 10 seconds..."
    sleep 10
    sudo reboot
fi
```

### 5. Add Recovery Command Documentation

**File**: Create new `INSTALLATION_TROUBLESHOOTING.md`

```markdown
# PicFrame Installation Troubleshooting

## Quick Diagnostics

### Check Installation Progress
```bash
cat ~/install_progress.txt
```
Should show `9` when fully complete.

### Check Installation Log
```bash
less ~/install_log.txt
# Or search for errors:
grep -i "error\|failed" ~/install_log.txt
```

### Verify Config Exists
```bash
ls -la ~/picframe_data/config/configuration.yaml
```

### Test PicFrame Binary
```bash
~/venv_picframe/bin/picframe --version
```

## Common Issues

### Issue 1: Config File Missing

**Symptom**: `FileNotFoundError: configuration.yaml`

**Fix**:
```bash
# Manual initialization
cd ~
~/venv_picframe/bin/picframe -i ~/
# Press Enter 3 times to accept defaults

# If that fails, copy from template:
mkdir -p ~/picframe_data/config
cp ~/picframe/src/picframe/data/configuration.yaml ~/picframe_data/config/
```

### Issue 2: Installation Stuck at Step X

**Check current step**:
```bash
cat ~/install_progress.txt
```

**Resume from current step**:
```bash
sudo ./1_install_picframe_developer_mode.sh <username>
```

The script automatically resumes from the last completed step.

### Issue 3: Virtual Environment Broken

**Symptom**: `command not found: picframe`

**Fix**:
```bash
# Recreate venv
rm -rf ~/venv_picframe
python3 -m venv ~/venv_picframe

# Reinstall all dependencies
cd ~/picframe
~/venv_picframe/bin/pip install --upgrade pip
~/venv_picframe/bin/pip install paho-mqtt

# Install hardware sensor libraries
~/venv_picframe/bin/pip install gpiod adafruit-blinka adafruit-platformdetect
~/venv_picframe/bin/pip install adafruit-circuitpython-bme280 adafruit-circuitpython-dht
~/venv_picframe/bin/pip install adafruit-circuitpython-bme680 adafruit-circuitpython-ahtx0

# Install picframe in developer mode
~/venv_picframe/bin/pip install -e .
```

### Issue 4: Sensor Import Errors

**Symptom**: `ModuleNotFoundError: No module named 'adafruit_dht'` or similar

**Fix**:
```bash
# Install missing sensor packages
~/venv_picframe/bin/pip install gpiod adafruit-blinka adafruit-platformdetect
~/venv_picframe/bin/pip install adafruit-circuitpython-bme280 adafruit-circuitpython-dht
~/venv_picframe/bin/pip install adafruit-circuitpython-bme680 adafruit-circuitpython-ahtx0

# Verify imports work
~/venv_picframe/bin/python3 -c "import board; import adafruit_dht; print('✅ Sensor packages OK')"
```

### Issue 5: Permission Errors

**Fix**:
```bash
# Fix ownership
sudo chown -R $USER:$USER ~/picframe ~/picframe_data ~/venv_picframe

# Fix permissions
chmod -R u+rwX ~/picframe ~/picframe_data ~/venv_picframe
```

## Manual Verification Steps

After installation, verify everything works:

```bash
# 1. Check picframe binary
~/venv_picframe/bin/picframe --version

# 2. Verify config file
cat ~/picframe_data/config/configuration.yaml

# 3. Check directories
ls -la ~/Pictures ~/DeletedPictures ~/picframe_data

# 4. Test systemd service
systemctl --user status picframe

# 5. Try running picframe manually (Ctrl+C to stop)
~/venv_picframe/bin/picframe
```

## Reset and Start Over

If all else fails:

```bash
# Clean up
rm -rf ~/picframe ~/picframe_data ~/venv_picframe ~/Pictures ~/DeletedPictures
rm ~/install_progress.txt ~/install_log.txt
sudo systemctl disable install_script_service 2>/dev/null
sudo rm /etc/systemd/system/install_script_service.service 2>/dev/null

# Start fresh
sudo ./1_install_picframe_developer_mode.sh <username>
```
```

## Testing Plan

### Test 1: Fresh Installation on Clean System
```bash
# On fresh Pi with user 'ivan'
./1_install_picframe_developer_mode.sh ivan

# Verify:
# - Pre-flight checks pass
# - All 9 steps complete
# - Config file exists at ~/picframe_data/config/configuration.yaml
# - Picframe runs: ~/venv_picframe/bin/picframe --version
# - Post-installation summary shows all paths
```

### Test 2: Installation with Low Memory
```bash
# Test warning appears when memory < 512MB
free -m

./1_install_picframe_developer_mode.sh pi

# Verify warning message appears in log
```

### Test 3: Recovery from Failed Step 5
```bash
# Simulate failure: manually set progress to 4
echo "4" > ~/install_progress.txt

# Resume installation
./1_install_picframe_developer_mode.sh pi

# Verify Step 5 runs and creates config file
```

### Test 4: Invalid Username
```bash
# Should fail at pre-flight check
./1_install_picframe_developer_mode.sh nonexistent_user

# Verify error message about user not existing
```

### Test 5: Config File Verification
```bash
# After installation, manually delete config
rm ~/picframe_data/config/configuration.yaml

# Try to run picframe - should get clear error
~/venv_picframe/bin/picframe

# Then restore: should show how to fix
```

## Critical Files

- `/Users/ivan.cherednychok/Projects/usefull-scripts/photo-frame/migration/1_install_picframe_developer_mode.sh` - Main installation script
- `/Users/ivan.cherednychok/Projects/usefull-scripts/photo-frame/migration/INSTALLATION_TROUBLESHOOTING.md` - New troubleshooting guide (to create)

## Success Criteria

After implementation:
- [ ] Pre-flight checks validate system state before starting
- [ ] Step 5 has proper error handling for each sub-step
- [ ] Config file creation is verified (not assumed)
- [ ] Manual fallback creates config from template if auto-init fails
- [ ] Post-installation verification (Step 9) catches missing components
- [ ] Installation summary displays all paths and next steps
- [ ] Troubleshooting guide helps users fix common issues
- [ ] Failed installations can be resumed without starting over

## Rollback

If issues arise:
- Script preserves progress at each step (can resume)
- Log file captures all output for debugging
- Troubleshooting guide provides manual recovery procedures
- User can clean up and restart with documented commands

## Out of Scope

**Not included in this plan**:
- Automated backup/restore integration
- Network timeout handling for package downloads (separate issue)
- Memory optimization for rclone/compilation (separate issue)
- Migration from X11 to Wayland display commands (separate issue)

These will be addressed in future iterations.
