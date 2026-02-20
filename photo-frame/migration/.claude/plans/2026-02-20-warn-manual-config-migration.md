# Warn User: Config Files Require Manual Migration

## Goal
Add visible user-facing warnings in `3_restore_picframe_backup.sh` for config files that are skipped during restore and must be migrated manually.

## Steps
- [ ] After extracting the backup and restoring `picframe_data/`, print a clear warning that `configuration.yaml` was **not** automatically applied and must be reviewed and copied manually
- [ ] At the end of the script (Next steps section), add numbered reminders for each file requiring manual action:
  - `configuration.yaml` — paths changed between X11 and community install (user, photo dirs)
  - `picframe.service` — old service is incompatible; new one installed by installer
- [ ] Keep the existing inline comments but surface them as `⚠️` output lines so they are visible during a real run

## Changes
Single file: `3_restore_picframe_backup.sh`

1. After the `picframe_data` restore block (~line 151), add:
   ```
   ⚠️  configuration.yaml was NOT automatically applied.
       The old config references X11 paths and the old user — it needs manual review.
       After restore, diff and adapt it:
         diff <backup>/picframe_data/config/configuration.yaml ~/picframe_data/config/configuration.yaml
       Then copy when ready:
         cp ~/picframe_data/config/configuration.yaml.bak ~/picframe_data/config/configuration.yaml
   ```

2. Update the "Next steps" section to include a manual config migration step.

## Rollback
Revert edits to `3_restore_picframe_backup.sh` — no structural changes, only added `echo` lines.
