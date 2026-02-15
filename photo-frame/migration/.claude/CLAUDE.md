# PicFrame Migration Project

Digital photo frame deployment on Raspberry Pi Zero 2W using fork of [picframe](https://github.com/helgeerbe/picframe). Fork is here https://github.com/ravado/picframe

## Hardware Constraints
- **512MB RAM**, quad-core ARM Cortex-A53
- **USB-based WiFi** shares bandwidth with SD card
- **100MB default swap** — increase to 1GB before any C compilation

Memory exhaustion → swap thrashing → USB saturation → WiFi hangs. This chain causes most "network errors".

## Current State
Two approaches exist:
1. **Custom scripts** (`0_backup_setup.sh` → `5_configure_photo_sync.sh`) — complex, stability issues
2. **Community script** — uses venv, labwc/Wayland, user `pi`, simpler but missing WireGuard/rclone/backup

Migration goal: Use community install + restore configs from custom backups.
How picframe should be installed: using venv and no `--break-system-packages` flags
OS: PiOS 64bit based on Debian Trixie

## Key Paths

| Component | Custom Scripts | Community Install |
|-----------|---------------|-------------------|
| User | `ivan.cherednychok` | `pi` |
| PicFrame config | `~/picframe/picframe_data/config/` | `~/picframe_data/config/` |
| Photos | `~/Pictures/PhotoFrame/` | `~/Pictures/` |
| Python | System (`--break-system-packages`) | venv (`~/venv_picframe/`) |
| Display | X11 (`xinit`) | Wayland (`labwc`) |
| Service | `/etc/systemd/system/picframe.service` | `~/.config/systemd/user/picframe.service` |

## What Backups Contain
Archive: `picframe_<prefix>_setup_backup_<timestamp>.tar.gz`
```
├── picframe_data/config/configuration.yaml
├── ssh/id_ed25519, id_ed25519.pub
├── wireguard_config/*.conf, privatekey
├── smb_config/smb.conf
├── crontab.txt          # display on/off schedule
├── git_config/          # user.name, user.email
└── picframe.service     # old systemd unit
```

## Environment Variables
All scripts source `env_loader.sh` → `backup.env`:
```bash
SMB_HOST, SMB_BACKUPS_PATH, SMB_PICFRAMES_PATH
USERNAME, PASSWORD, SMB_CRED_USER, SMB_CRED_PASS
```

## Scripts Overview
| Script | Purpose |
|--------|---------|
| `0_backup_setup.sh <prefix>` | Backup to SMB share |
| `1_install_picframe.sh` | Full install (X11-based) |
| `2_restore_samba.sh` | Configure local Samba |
| `3_restore_picframe_backup.sh <prefix> latest` | Restore from SMB |
| `5_configure_photo_sync.sh <prefix>` | Setup rclone sync service |
| `community_installation.sh` | The way community suggest installing on a fresh device |

## Conventions
- Bash with `set -euo pipefail`
- Emoji status prefixes: ✅ ❌ ⚠️ 📦 🔄
- Prefix param (`home`, `batanovs`, `cherednychoks`) identifies which frame

## Known Issues
- Network ops lack timeouts → hangs on flaky WiFi
- rclone defaults (4 transfers, 8 checkers) exhaust RAM
- `Adafruit_DHT` C compilation can OOM — use `adafruit-circuitpython-dht` instead
- X11 display commands (`xset`) don't work with Wayland (`wlr-randr` instead)

## Workflow Rules

**Always create a plan before implementing.** No code changes without approved plan.

1. Create `.claude/plans/YYYY-MM-DD-<short-title>.md`
2. Present plan and wait for explicit "approved" / "go ahead" / "do it"
3. Only then implement

### Plan Format
```markdown
# Title

## Goal
One sentence: what are we achieving?

## Steps
- [ ] Step with specific files/commands

## Rollback
How to undo if needed
```