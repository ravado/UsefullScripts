# Fix 3_restore_picframe_backup.sh for Community Install

## Goal
Update the restore script so it correctly installs backup data onto a fresh community-install device (user `pi`, Wayland/labwc, user systemd service, `~/picframe_data/`) instead of the old custom-install layout.

## Context
The old picframes ran a custom install (user `ivan.cherednychok`, X11, system-wide service, `~/picframe/picframe_data/`). `0_backup_setup.sh` was run on those old devices, so all available backup archives reflect the old layout. The restore script hardcodes those old paths and makes X11-specific assumptions throughout.

## What the Backup Contains (old layout)
```
picframe_data/config/configuration.yaml   ← config we want
ssh/id_ed25519, id_ed25519.pub
wireguard_config/*.conf, privatekey
smb_config/smb.conf
crontab.txt          ← has vcgencmd display_power 0/1 entries
git_config/user.name, user.email
picframe.service     ← old X11 / system-unit file — NOT directly reusable
```

## Problems to Fix

| # | Lines | Current (wrong) | Correct |
|---|-------|-----------------|---------|
| 1 | 14-15 | `PICFRAME_DATA=$HOME/picframe/picframe_data` | `$HOME/picframe_data` |
| 2 | 158 | `mkdir -p ~/picframe … ~/.config/picframe` | Remove both; keep `~/Documents/Scripts ~/.config ~/Pictures` |
| 3 | 136-148 | Patches crontab: `vcgencmd` → `xset dpms` (X11) and adds `DISPLAY=:0` | Patch to `wlr-randr` (Wayland); set `WAYLAND_DISPLAY=wayland-1` instead |
| 4 | 191-194 | Restores service to `/etc/systemd/system/` via `sudo systemctl` | Restore to `~/.config/systemd/user/` via `systemctl --user`; add ⚠️ that service file is for old X11 install and will need review |
| 5 | 249 | Creates `~/Pictures/PhotoFrame ~/Pictures/PhotoFrameOriginal ~/Pictures/PhotoFrameDeleted` | `mkdir -p ~/Pictures` only — community install uses flat `~/Pictures/` |
| 6 | 274-278 | Verbose summary references `~/.config/picframe/` and `/etc/systemd/system/picframe.service` | Update to `~/picframe_data/` and `~/.config/systemd/user/picframe.service` |

## Steps

**File: `photo-frame/migration/3_restore_picframe_backup.sh`**

- [ ] **Lines 14-15**: Remove `PICFRAME_BASE`; set `PICFRAME_DATA="$HOME/picframe_data"`

- [ ] **Line 158**: Change to:
  ```bash
  mkdir -p ~/Documents/Scripts ~/.config ~/Pictures
  ```

- [ ] **Lines 130-152 (crontab patching block)**: Replace X11 patching with Wayland patching:
  ```bash
  echo "🔧 Patching restored crontab for Wayland display control..."
  TMP_CRON_PATCHED="$LOCAL_TMP/patched_crontab.txt"

  crontab -l | \
      sed 's|vcgencmd display_power 0|wlr-randr --output HDMI-A-1 --off|g' | \
      sed 's|vcgencmd display_power 1|wlr-randr --output HDMI-A-1 --on|g' | \
      sed '/xset dpms/d' > "$TMP_CRON_PATCHED"

  # Use WAYLAND_DISPLAY for Wayland (replaces X11's DISPLAY=:0)
  if grep -q "wlr-randr" "$TMP_CRON_PATCHED" && ! grep -q "^WAYLAND_DISPLAY=" "$TMP_CRON_PATCHED"; then
      sed -i '1iWAYLAND_DISPLAY=wayland-1' "$TMP_CRON_PATCHED"
      echo "✅ Set WAYLAND_DISPLAY=wayland-1 in crontab"
  fi
  # Remove any stale DISPLAY=:0 lines
  sed -i '/^DISPLAY=/d' "$TMP_CRON_PATCHED"

  crontab "$TMP_CRON_PATCHED"
  rm "$TMP_CRON_PATCHED"
  echo "✅ Crontab patched for Wayland (wlr-randr --output HDMI-A-1)"
  echo "⚠️  If your HDMI output name differs, edit crontab manually (run: wlr-randr to list outputs)"
  ```

- [ ] **Lines 188-200 (service restore block)**: Change to user-service path and add advisory:
  ```bash
  if [[ $RESTORE_SERVICE -eq 1 ]]; then
      echo "⚙️ Restoring systemd service..."
      if [ -f "$BACKUP_FULL/picframe.service" ]; then
          echo "⚠️  The archived picframe.service was created for the old X11 install."
          echo "   Review it before enabling — the community install service may differ."
          mkdir -p ~/.config/systemd/user
          cp -v "$BACKUP_FULL/picframe.service" ~/.config/systemd/user/
          systemctl --user daemon-reload
          systemctl --user enable picframe
          echo "✅ picframe.service placed at ~/.config/systemd/user/ (review before starting)"
      else
          echo "⚠️ No picframe.service found in backup"
      fi
  else
      echo "ℹ️ Skipping service restore (use --with-service to enable)"
  fi
  ```

- [ ] **Line 249**: Replace photo subdirs with:
  ```bash
  mkdir -p ~/Pictures
  echo "✅ ~/Pictures/ ready"
  ```

- [ ] **Lines 274-278 (verbose summary)**: Update to:
  ```
  Restored PicFrame config to: ~/picframe_data/config/
  Restored systemd service to: ~/.config/systemd/user/picframe.service
  ```

## What Is NOT Changed
- SMB download / extraction logic
- SSH key restore (`~/.ssh/`)
- Git config restore
- WireGuard restore (`/etc/wireguard/`)
- Scripts repo clone (`~/Documents/Scripts`)
- Cleanup

## Rollback
`git checkout -- photo-frame/migration/3_restore_picframe_backup.sh`
