# Developer Mode Installation Script

## Goal
Create installation script that installs picframe fork (develop branch) in developer mode, testing installation and service startup on RPi.

## Context
- Community script uses `pi` user and works reliably
- Backups use `ivan.cherednychok` user (dots not allowed by Pi Imager)
- **First iteration**: Focus on getting dev install working with `pi` user
- **Later iteration**: Handle username migration strategy

## Steps

### 1. Create `1_install_picframe_developer_mode.sh` based on community script
- [ ] Copy community script structure (progress tracking, reboot handling)
- [ ] Keep `pi` user for first iteration (simplify testing)
- [ ] Replace PyPI install with git clone + editable install:
  ```bash
  git clone https://github.com/ravado/picframe.git
  cd picframe
  git checkout develop
  pip install -e .
  ```
- [ ] Update paths:
  - Clone to: `/home/pi/picframe` (repo)
  - Venv: `/home/pi/venv_picframe` (same as community)
  - Data: `/home/pi/picframe_data/` (same as community)

### 2. Key differences from community script
- [ ] Install git dependencies before cloning
- [ ] Clone fork repo instead of `pip install picframe`
- [ ] Checkout develop branch
- [ ] Use `pip install -e .` for editable/developer mode
- [ ] Keep all other configurations identical (labwc, systemd, mosquitto)

### 3. Variables to parameterize (for future flexibility)
- [ ] Add variables at top:
  ```bash
  INSTALL_USER="pi"
  REPO_URL="https://github.com/ravado/picframe.git"
  REPO_BRANCH="develop"
  VENV_PATH="/home/$INSTALL_USER/venv_picframe"
  REPO_PATH="/home/$INSTALL_USER/picframe"
  ```

### 4. Testing checklist (after installation)
- [ ] Verify repo cloned to correct location
- [ ] Verify develop branch checked out
- [ ] Verify venv created and picframe installed in editable mode
- [ ] Verify systemd user service starts
- [ ] Verify picframe runs without errors

## Username Strategy (Future)
**Not in this iteration**, but document options:
1. **Post-install user creation**: Create `pi` via imager, then script creates `ivan.cherednychok` and migrates
2. **Underscore username**: Use `ivan_cherednychok` (allowed by imager), symlink/alias compatibility
3. **Simple username**: Use `ivan` with path mapping for backups

For v1: Accept `pi` user limitation, focus on dev mode installation working.

## Files Changed
- **New file**: `1_install_picframe_developer_mode.sh`

## Rollback
- Re-flash SD card and use community script if dev install fails
- Progress tracking allows resume from any step
