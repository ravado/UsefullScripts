# Standardize on 'ivan' Username for PicFrame Installation

## Goal
Modify `1_install_picframe_developer_mode.sh` to use `ivan` as the standard user instead of `pi`, eliminating username-related path and permission issues across all installations.

## Current Problem
Script currently uses `INSTALL_USER="pi"` but we need to standardize on `ivan` to:
- Avoid conflicts with default Raspberry Pi user
- Match personal identifier (not generic `pi`)
- Create consistency across all future installations
- Simplify future backup/restore operations

## Benefits of Using 'ivan'
1. **Personal identifier** - clearly identifies owner, not generic
2. **Shorter than `ivan.cherednychok`** - cleaner paths, easier typing
3. **Security** - avoids well-known default `pi` username
4. **Consistency** - single username standard going forward
5. **Path clarity** - `/home/ivan` is obvious and unambiguous

## Changes Required

### 1. Update Configuration Variable
- [ ] Line 8: Change `INSTALL_USER="pi"` to `INSTALL_USER="ivan"`

That's it! All other references use the `$INSTALL_USER` variable, so they'll automatically update:
- `/home/$INSTALL_USER/` paths (lines 11-13, 16-17, etc.)
- `su - $INSTALL_USER` commands (all instances)
- Sudoers entry (line 86)
- Samba configuration (lines 207-210)
- All log messages (lines 91, 403, 424, etc.)

### 2. Verify No Hardcoded 'pi' References
- [ ] Search script for any hardcoded `pi` strings not using variable
- [ ] Check comments for accuracy (e.g., line 152 "boot in console as user")

### 3. Update Documentation Comments
- [ ] Verify header comments still accurate
- [ ] Ensure no misleading references to `pi` user in comments

## Files to Modify
- `/Users/ivan.cherednychok/Projects/usefull-scripts/photo-frame/migration/1_install_picframe_developer_mode.sh`

## Verification Steps
After making changes:
```bash
# 1. Verify no hardcoded '/home/pi' paths remain
grep -n "/home/pi" 1_install_picframe_developer_mode.sh | grep -v "\$INSTALL_USER"

# 2. Verify no hardcoded 'su - pi' commands remain
grep -n "su - pi" 1_install_picframe_developer_mode.sh

# 3. Verify INSTALL_USER is set to ivan
grep -n "^INSTALL_USER=" 1_install_picframe_developer_mode.sh

# 4. Check that all critical paths use variable
grep -n "INSTALL_USER" 1_install_picframe_developer_mode.sh | head -20
```

Expected results:
- ✅ No hardcoded `/home/pi` paths (except in variable definitions using `$INSTALL_USER`)
- ✅ No hardcoded `su - pi` commands
- ✅ `INSTALL_USER="ivan"` on line 8
- ✅ All paths properly use `$INSTALL_USER` variable

## Testing Checklist
Before deployment to actual hardware:
- [ ] Run script validation: `bash -n 1_install_picframe_developer_mode.sh`
- [ ] Verify syntax is valid
- [ ] Confirm no shell errors

On test Raspberry Pi:
- [ ] Create user `ivan` before running: `sudo adduser ivan`
- [ ] Run script and verify it creates paths under `/home/ivan/`
- [ ] Verify venv created at `/home/ivan/venv_picframe`
- [ ] Verify config at `/home/ivan/picframe_data/config/configuration.yaml`
- [ ] Verify systemd service references correct paths

## Rollback
If issues arise:
1. Change line 8 back to `INSTALL_USER="pi"`
2. All paths and commands will automatically revert
3. Re-run installation on fresh system

## Path Comparison

| Component | Old (pi) | New (ivan) |
|-----------|----------|------------|
| Virtual env | `/home/pi/venv_picframe` | `/home/ivan/venv_picframe` |
| Repository | `/home/pi/picframe` | `/home/ivan/picframe` |
| Data directory | `/home/pi/picframe_data` | `/home/ivan/picframe_data` |
| Pictures | `/home/pi/Pictures` | `/home/ivan/Pictures` |
| Deleted pics | `/home/pi/DeletedPictures` | `/home/ivan/DeletedPictures` |
| Log file | `/home/pi/install_log.txt` | `/home/ivan/install_log.txt` |
| Progress file | `/home/pi/install_progress.txt` | `/home/ivan/install_progress.txt` |
| Autostart | `/home/pi/start_picframe.sh` | `/home/ivan/start_picframe.sh` |
| labwc config | `/home/pi/.config/labwc/` | `/home/ivan/.config/labwc/` |
| systemd service | `/home/pi/.config/systemd/user/` | `/home/ivan/.config/systemd/user/` |

## Pre-requisites
Before running modified script on Raspberry Pi:
- User `ivan` must exist on the system
- User `ivan` must be in `sudo` group
- User `ivan` home directory must be `/home/ivan`

Create user with:
```bash
sudo adduser ivan
sudo usermod -aG sudo ivan
```

## Future Implications
This change means:
- **Backup scripts** - will need to backup from `/home/ivan` (future work)
- **Restore scripts** - will restore to `/home/ivan` (future work)
- **Documentation** - should reference `ivan` user consistently
- **All new installations** - will use `ivan` as standard
- **CLAUDE.md** - should be updated to reflect `ivan` as the standard user

## Success Criteria
- ✅ Script modified with single line change
- ✅ All paths automatically use new username via variable
- ✅ No hardcoded `pi` references remain (except in old documentation)
- ✅ Script passes bash syntax check
- ✅ Installation creates all files/folders under `/home/ivan`
