# Fix Picframe Initialization in Developer Install Script

## Goal
Fix the picframe initialization process in `1_install_picframe_developer_mode.sh` so that `picframe -i` properly creates configuration files, or provide a robust fallback.

## Problem Analysis

### Why picframe -i Failed
The expect script (lines 322-335) doesn't handle all prompts from `picframe -i`:

**Handled:**
- "picture directory*" → sends `\r` (accept default)
- "Deleted picture directory*" → sends `\r`
- "Configuration file*" → sends `\r`

**Missing:**
- "Enter locale" → NO HANDLER → expect times out → picframe aborts

**Result:** Configuration file never created because initialization incomplete.

### Why Fallback Failed
Line 359 looks for template at wrong path:
- ❌ Current: `$REPO_PATH/src/picframe/data/configuration.yaml`
- ✅ Correct: `$REPO_PATH/src/picframe/config/configuration_example.yaml`

## Solution Options

### Option A: Fix Expect Script (Recommended)
Add locale prompt handler to complete initialization properly.

**Pros:**
- Uses picframe's intended initialization flow
- Handles all directory creation automatically
- More maintainable if picframe adds more prompts

**Cons:**
- Relies on expect script fragility

### Option B: Skip Interactive Init
Instead of `picframe -i` with expect, manually:
1. Copy template directories
2. Copy configuration_example.yaml → configuration.yaml
3. Use sed to substitute paths

**Pros:**
- More reliable, no expect needed
- Full control over process
- Clearer what's happening

**Cons:**
- Duplicates picframe's logic
- Might break if picframe changes directory structure

### Recommendation: **Hybrid Approach**
1. Try picframe -i with fixed expect script
2. If it fails, fall back to manual setup with correct paths

## Implementation Steps

### Step 1: Fix Expect Script
**File:** `1_install_picframe_developer_mode.sh` lines 322-335

Add locale prompt handler:
```expect
#!/usr/bin/expect -f
set timeout 30
set venv_path [lindex $argv 0]
set install_user [lindex $argv 1]

spawn su - $install_user -c "$venv_path/bin/picframe -i /home/$install_user/"
expect {
    "picture directory*" { send "\r"; exp_continue }
    "Deleted picture directory*" { send "\r"; exp_continue }
    "Enter locale*" { send "\r"; exp_continue }
    "Configuration file*" { send "\r"; exp_continue }
    eof
}

# Capture exit code
catch wait result
exit [lindex $result 3]
```

**Changes:**
- Add `"Enter locale*" { send "\r"; exp_continue }` pattern
- Capture and return picframe's exit code for proper error detection

### Step 2: Fix Fallback Template Path
**File:** `1_install_picframe_developer_mode.sh` line 359

Change:
```bash
# OLD
if [ -f "$REPO_PATH/src/picframe/data/configuration.yaml" ]; then

# NEW
if [ -f "$REPO_PATH/src/picframe/config/configuration_example.yaml" ]; then
```

And line 360:
```bash
# OLD
su - $INSTALL_USER -c "cp $REPO_PATH/src/picframe/data/configuration.yaml $CONFIG_FILE"

# NEW
su - $INSTALL_USER -c "cp $REPO_PATH/src/picframe/config/configuration_example.yaml $CONFIG_FILE"
```

### Step 3: Improve Fallback Robustness
**File:** `1_install_picframe_developer_mode.sh` after line 360

Add proper directory setup if manual creation needed:
```bash
# Ensure all required directories exist
su - $INSTALL_USER -c "mkdir -p $DATA_PATH/config"
su - $INSTALL_USER -c "mkdir -p $DATA_PATH/data"
su - $INSTALL_USER -c "mkdir -p $DATA_PATH/html"

# Copy all template directories from source
if [ -d "$REPO_PATH/src/picframe/data" ]; then
    su - $INSTALL_USER -c "cp -r $REPO_PATH/src/picframe/data/* $DATA_PATH/data/"
    log_message "✅ Copied data directory"
fi

if [ -d "$REPO_PATH/src/picframe/html" ]; then
    su - $INSTALL_USER -c "cp -r $REPO_PATH/src/picframe/html/* $DATA_PATH/html/"
    log_message "✅ Copied html directory"
fi

# Copy configuration template
if [ -f "$REPO_PATH/src/picframe/config/configuration_example.yaml" ]; then
    su - $INSTALL_USER -c "cp $REPO_PATH/src/picframe/config/configuration_example.yaml $CONFIG_FILE"
    log_message "✅ Copied configuration template"

    # Update paths in configuration to match installation
    su - $INSTALL_USER -c "sed -i 's|~/Pictures|/home/$INSTALL_USER/Pictures|g' $CONFIG_FILE"
    su - $INSTALL_USER -c "sed -i 's|~/DeletedPictures|/home/$INSTALL_USER/DeletedPictures|g' $CONFIG_FILE"
    log_message "✅ Updated configuration paths"
else
    log_message "❌ FATAL: Cannot find configuration template"
    exit 1
fi
```

### Step 4: Add Better Verification
**File:** `1_install_picframe_developer_mode.sh` after line 368

Add verification that all initialization completed:
```bash
# Verify all expected files and directories exist
REQUIRED_PATHS=(
    "$CONFIG_FILE"
    "$DATA_PATH/data"
    "$DATA_PATH/html"
    "/home/$INSTALL_USER/Pictures"
    "/home/$INSTALL_USER/DeletedPictures"
)

for path in "${REQUIRED_PATHS[@]}"; do
    if [ ! -e "$path" ]; then
        log_message "❌ ERROR: Required path missing: $path"
        log_message "   Initialization incomplete - manual setup required"
        exit 1
    fi
done

log_message "✅ All required paths verified"
```

## Testing Plan

1. **Clean test**: Remove any existing picframe_data and run script
2. **Verify**: Check that config file exists and contains correct paths
3. **Verify**: Check that data, html directories copied correctly
4. **Test picframe**: Run `picframe --version` and verify it can load config

## Rollback

If changes cause issues:
1. Revert to commit before changes: `git checkout HEAD~1`
2. Or manually fix config: `cp ~/picframe/src/picframe/config/configuration_example.yaml ~/picframe_data/config/configuration.yaml`

## Success Criteria

- [ ] Script completes without "Configuration file not created" error
- [ ] `~/picframe_data/config/configuration.yaml` exists
- [ ] `~/picframe_data/data/` contains fonts, shaders, etc.
- [ ] `~/picframe_data/html/` contains web UI files
- [ ] Configuration file has correct paths (/home/ivan/Pictures not ~/Pictures)
- [ ] `picframe --version` runs without errors
