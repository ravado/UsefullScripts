# TASK-001: Fix Migration Scripts Issues

## Summary

The PhotoFrame migration scripts have **14 issues** that cause system hangs, memory exhaustion, and network failures on Raspberry Pi Zero 2W (512MB-1GB RAM, USB-based WiFi).

### Issue Breakdown

| Severity | Count | Examples |
|----------|-------|----------|
| Critical | 6 | Infinite loops, OOM during compilation, package conflicts |
| High | 4 | Deprecated pip flags, missing timeouts, high concurrency |
| Medium | 4 | Missing error handling, no bandwidth limits |

---

## Root Cause

Python C extension compilation (Adafruit_DHT, numpy) exhausts memory → heavy swapping → SD card I/O bottleneck → USB bandwidth saturation → WiFi driver crashes → "Network unreachable" errors.

---

## Fix Plan

### Phase 1: Critical Fixes (Priority 1-4)

#### 1.1 Add swap configuration before pip install
**File:** `PhotoFrame/migration/1_install_picframe.sh`
**Effort:** Low | **Impact:** Critical

Add before any pip install:
```bash
# Increase swap for compilation
sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

#### 1.2 Use virtual environment instead of --break-system-packages
**File:** `PhotoFrame/migration/1_install_picframe.sh`
**Effort:** Medium | **Impact:** Critical

Replace:
```bash
pip3 install --break-system-packages picframe
```

With:
```bash
python3 -m venv /opt/picframe
source /opt/picframe/bin/activate
pip install picframe adafruit-circuitpython-dht paho-mqtt
```

#### 1.3 Add timeout to DNS polling loop
**File:** `PhotoFrame/migration/1_install_picframe.sh:47-49`
**Effort:** Low | **Impact:** Critical

Replace infinite loop with max 30 retries:
```bash
MAX_RETRIES=30
RETRY_COUNT=0
until ping -c1 -W5 8.8.8.8 >/dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  [[ $RETRY_COUNT -ge $MAX_RETRIES ]] && { echo "❌ DNS timeout"; exit 1; }
  sleep 2
done
```

#### 1.4 Add SMB timeout wrapper
**Files:** `0_backup_setup.sh`, `3_restore_picframe_backup.sh`
**Effort:** Low | **Impact:** Critical

Add helper function:
```bash
smb_with_timeout() {
    timeout 60 smbclient "$@"
    [[ $? -eq 124 ]] && { echo "❌ SMB timeout"; return 1; }
}
```

---

### Phase 2: High Priority Fixes (Priority 5-8)

#### 2.1 Remove deprecated --install-option flag
**File:** `PhotoFrame/migration/1_install_picframe.sh:66`
**Effort:** Low | **Impact:** High

Remove:
```bash
pip3 install Adafruit_DHT --install-option="--force-pi"
```

Use only CircuitPython version (no compilation needed):
```bash
pip install adafruit-circuitpython-dht
```

#### 2.2 Reduce rclone concurrency
**File:** `PhotoFrame/sync_photos_from_nasik.sh:39-46`
**Effort:** Low | **Impact:** High

Change from `--transfers=4 --checkers=8` to:
```bash
--transfers=1 \
--checkers=2 \
--buffer-size=16M \
--timeout 60s
```

#### 2.3 Add timeout to git clone
**File:** `PhotoFrame/migration/1_install_picframe.sh:80-82`
**Effort:** Low | **Impact:** High

```bash
timeout 300 git clone --depth 1 -b main https://github.com/ravado/picframe.git
```

#### 2.4 Batch APT installations
**File:** `PhotoFrame/migration/1_install_picframe.sh:16-28`
**Effort:** Medium | **Impact:** High

Split into smaller groups with timeouts.

---

### Phase 3: Medium Priority Fixes (Priority 9-12)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 9 | Conflicting DHT libraries | `1_install_picframe.sh:66-67` | Remove `Adafruit_DHT`, keep only `adafruit-circuitpython-dht` |
| 10 | Missing `set -euo pipefail` | `2_restore_samba.sh:1` | Add after shebang |
| 11 | smbpasswd no error check | `2_restore_samba.sh:69-72` | Wrap with `if !` checks |
| 12 | rsync no bandwidth limit | `4_sync_photos.sh:21-23` | Add `--bwlimit=2000 --timeout=120` |

---

### Phase 4: Low Priority Fixes (Priority 13-14)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 13 | Hardcoded user paths | `1_install_picframe.sh:123`, `5_configure_photo_sync.sh:21-24` | Use `$HOME_DIR` variable |
| 14 | X server fixed sleep | `1_install_picframe.sh:97-98` | Add health check loop |

---

## Files to Modify

| File | Issues |
|------|--------|
| `PhotoFrame/migration/1_install_picframe.sh` | 1, 3, 4, 11, 12, 13, 9, 10, 13, 14 |
| `PhotoFrame/migration/0_backup_setup.sh` | 2 |
| `PhotoFrame/migration/2_restore_samba.sh` | 6, 7 |
| `PhotoFrame/migration/3_restore_picframe_backup.sh` | 2 |
| `PhotoFrame/migration/4_sync_photos.sh` | 8 |
| `PhotoFrame/migration/5_configure_photo_sync.sh` | 9 |
| `PhotoFrame/sync_photos_from_nasik.sh` | 5 |

---

## Expected Outcome

After fixes:
- Memory usage reduced from 640-1070MB to ~330-430MB
- All network operations have timeouts (no infinite hangs)
- Scripts fail gracefully with clear error messages
- Compatible with pip 25.0+
- No package conflicts between apt and pip

---

## Checklist

- [ ] Phase 1: Critical fixes
  - [ ] 1.1 Add swap configuration
  - [ ] 1.2 Use virtual environment
  - [ ] 1.3 Add DNS timeout
  - [ ] 1.4 Add SMB timeout wrapper
- [ ] Phase 2: High priority fixes
  - [ ] 2.1 Remove deprecated pip flag
  - [ ] 2.2 Reduce rclone concurrency
  - [ ] 2.3 Add git clone timeout
  - [ ] 2.4 Batch APT installations
- [ ] Phase 3: Medium priority fixes
- [ ] Phase 4: Low priority fixes
- [ ] Test on Pi Zero 2W
