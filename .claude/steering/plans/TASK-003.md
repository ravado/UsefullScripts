# TASK-003: Improve Installation & Restoration Reliability

## Summary
Improve the robustness and reliability of the PhotoFrame installation and restoration scripts. This task builds upon the findings from the analysis of `photo-frame/migration` scripts, specifically addressing system stability during installation (RAM usage) and network reliability during restoration.

**Context:**
- Target hardware: Raspberry Pi Zero 2W.
- Target OS: Fresh install.
- **Note:** Overwriting files (SSH keys, crontab) is EXPECTED behavior for this fresh install use case.
- **Note:** Hardcoded user `ivan.cherednychok` is ACCEPTABLE and INTENTIONAL.

## Issues to Address

### 1. Installation Stability (RAM & Swap)
The compilation of Python packages (numpy, Pillow) on a Pi Zero 2W often fails due to OOM (Out of Memory).
*   **Fix:** Temporarily increase swap size significantly (e.g., to 1GB or 2GB) during the installation process and revert it afterwards.

### 2. Network Reliability (Timeouts)
Scripts contain potential infinite loops or operations without timeouts that can hang indefinitely if the network is unstable.
*   **Fix (`1_install_picframe.sh`):** Add a max retry limit and timeout to the DNS availability check loop (`until ping...`).
*   **Fix (`3_restore_picframe_backup.sh`):** Ensure network operations (smbclient, git clone) have appropriate timeouts.

### 3. Modern Best Practices (Virtual Environment)
The scripts currently use `--break-system-packages`, which is discouraged.
*   **Fix:** Migrate to using a Python virtual environment (`venv`) for the PicFrame application and its dependencies. This ensures a clean separation from system packages.

### 4. Restoration Logic
*   **Fix (`3_restore_picframe_backup.sh`):** Ensure the restored service file is correct for the target environment (verified accepted as `ivan.cherednychok`, but ensuring the file path logic is sound is still good practice).

## Implementation Plan

### Phase 1: Installation Script Improvements (`1_install_picframe.sh`)
- [ ] Implement swap file size increase/restore logic.
- [ ] Replace `--break-system-packages` with a dedicated `venv` at `/opt/picframe` (or user home).
- [ ] Add timeout/retry logic to the DNS wait loop.

### Phase 2: Restore Script Improvements (`3_restore_picframe_backup.sh`)
- [ ] Verify `smbclient` commands have timeouts.
- [ ] Verify `git clone` has a timeout.

## Verification
- Test installation on a Raspberry Pi Zero 2W (if available) or simulate low-memory environment.
- Verify `venv` creation and package installation.
- Verify script handles network interruptions gracefully (timeouts working).

---

## Implementation Details

**For complete implementation code and detailed instructions, see [TASK-004.md](./TASK-004.md)**

TASK-004 provides:
- Production-ready bash code for all fixes
- Screen control implementation (systemd timers + cron)
- Comprehensive testing scripts
- Rollback procedures
- Step-by-step implementation guide

**Quick overview:** TASK-003 (this document) = WHAT to fix
**Detailed implementation:** TASK-004 = HOW to fix with complete code
