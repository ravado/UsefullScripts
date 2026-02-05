# PhotoFrame Screen Control Scripts

Automated screen on/off control for Raspberry Pi photo frames using DPMS (Display Power Management Signaling) via X11.

## Scripts

### screen_control.sh
Main control script for managing screen power state.

**Usage:**
```bash
./screen_control.sh [on|off|status]
```

**Commands:**
- `on` - Turn screen on using DPMS
- `off` - Turn screen off using DPMS
- `status` - Show current screen state

**Features:**
- X server connectivity check
- DPMS state verification after each operation
- Logging to `/var/log/picframe-screen.log`
- Optional HDMI-CEC support (if cec-client installed)
- Fallback methods if primary method fails

### install_crontab.sh
Installs cron jobs for automated screen scheduling (simpler method).

**Default Schedule:**
- Screen OFF: 23:00 (11 PM)
- Screen ON: 07:00 (7 AM)
- Status check: 12:00 (Noon)

**Usage:**
```bash
./install_crontab.sh
```

**Logs:**
- Screen control: `/var/log/picframe-screen.log`
- Cron execution: `/var/log/picframe-cron.log`

### install_timers.sh
Installs systemd timers for automated screen scheduling (recommended method).

**Default Schedule:**
- Screen OFF: 23:00 (11 PM)
- Screen ON: 07:00 (7 AM)

**Usage:**
```bash
./install_timers.sh
```

**Advantages:**
- Better logging via journalctl
- Dependency management with picframe.service
- Can see timer status with `systemctl list-timers`
- Persistent (runs missed timers on boot)

**Check status:**
```bash
systemctl list-timers picframe-screen-*
journalctl -u picframe-screen-on.service
journalctl -u picframe-screen-off.service
```

### test_screen_control.sh
Comprehensive test script that validates all screen control functions.

**Tests:**
1. Screen OFF → verify
2. Status check (should show OFF)
3. Screen ON → verify
4. Status check (should show ON)
5. Rapid toggle test (3 cycles)
6. Final status check
7. Log verification

**Usage:**
```bash
./test_screen_control.sh
```

## Installation on Raspberry Pi

### 1. Copy Scripts to Pi

```bash
# If using git deployment
cd ~/Documents/Scripts
git pull

# Copy scripts to picframe directory
mkdir -p ~/picframe/scripts
cp ~/Documents/Scripts/photo-frame/scripts/* ~/picframe/scripts/
chmod +x ~/picframe/scripts/*.sh
```

### 2. Test Manually

```bash
# Test screen control
~/picframe/scripts/test_screen_control.sh
```

### 3. Install Scheduling

**Option A: Crontab (simpler)**
```bash
~/picframe/scripts/install_crontab.sh
```

**Option B: Systemd Timers (recommended)**
```bash
~/picframe/scripts/install_timers.sh
```

## Customizing Schedule

### For Crontab

Edit crontab with `crontab -e`:
```cron
# Screen off at 22:00 (10 PM)
0 22 * * * ~/picframe/scripts/screen_control.sh off >> /var/log/picframe-cron.log 2>&1

# Screen on at 06:00 (6 AM)
0 6 * * * ~/picframe/scripts/screen_control.sh on >> /var/log/picframe-cron.log 2>&1
```

### For Systemd Timers

Edit timer files:
```bash
# Edit screen-off timer
sudo nano /etc/systemd/system/picframe-screen-off.timer
# Change: OnCalendar=22:00

# Edit screen-on timer
sudo nano /etc/systemd/system/picframe-screen-on.timer
# Change: OnCalendar=06:00

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart picframe-screen-off.timer
sudo systemctl restart picframe-screen-on.timer
```

## Troubleshooting

### Screen doesn't turn off/on

1. **Check X server is accessible:**
```bash
DISPLAY=:0 xdpyinfo
```

2. **Check DPMS is enabled:**
```bash
DISPLAY=:0 xset q | grep DPMS
```

3. **Test manually:**
```bash
DISPLAY=:0 xset dpms force off  # Turn off
DISPLAY=:0 xset dpms force on   # Turn on
```

### Check Logs

```bash
# Screen control log
tail -50 /var/log/picframe-screen.log

# Cron log (if using crontab)
tail -50 /var/log/picframe-cron.log

# Systemd log (if using timers)
journalctl -u picframe-screen-off.service -n 50
journalctl -u picframe-screen-on.service -n 50
```

## Requirements

- Raspberry Pi with X11 display server
- `x11-xserver-utils` package (provides xset)
- `x11-utils` package (provides xdpyinfo)
- Optional: `cec-utils` for HDMI-CEC support
- Optional: `xdotool` for mouse cursor movement wake

## How It Works

The screen control uses DPMS (Display Power Management Signaling) commands via X11:

**Screen OFF:**
```bash
xset dpms force off    # Force DPMS power off
xset s activate        # Activate screensaver (backup)
```

**Screen ON:**
```bash
xset dpms force on     # Force DPMS power on
xset s reset           # Reset screensaver
```

**Verification:**
```bash
xset q | grep "Monitor is"    # Check actual state (On/Off/Standby)
```

## Related Documentation

- TASK-004.md - Full implementation plan (Section 2, Part B)
- TASK-004-IMPLEMENTATION-SUMMARY.md - Phase 1 implementation results
- X11 DPMS: `man xset`
- Systemd timers: `man systemd.timer`
