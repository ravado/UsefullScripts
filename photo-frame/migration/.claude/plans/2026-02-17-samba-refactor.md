# Samba Refactor: Remove from Install Script, Update for `ivan` User

## Goal
Remove Samba setup from `1_install_picframe_developer_mode.sh` (it belongs in `2_restore_samba.sh`), and update `2_restore_samba.sh` so the SMB share path points to `/home/ivan` (the new picframe user) while keeping `ivan.cherednychok` as the Samba auth user.

## Path Changes to Be Aware Of

| What | Before | After |
|------|--------|-------|
| SMB share path | `/home/ivan.cherednychok` | `/home/ivan` |
| System user created | `ivan.cherednychok` | `ivan.cherednychok` (unchanged, needed for Samba auth) |
| SMB username | `ivan.cherednychok` | `ivan.cherednychok` (unchanged) |
| SMB share name | `[ivan.cherednychok]` | `[ivan.cherednychok]` (unchanged) |

Existing clients that mount using `ivan.cherednychok` credentials will now see `/home/ivan/` contents (Pictures, picframe_data, etc.) instead of `/home/ivan.cherednychok/`.

## Steps

- [ ] **`1_install_picframe_developer_mode.sh`**: Remove Step 3 block (lines 159–220): `apt-get install samba`, `expect` setup, `smbpasswd`, `smb.conf` write, and `systemctl restart smbd`. Step numbering (4–9) stays unchanged — progress tracking still works correctly via `[ "$LAST_COMPLETED_STEP" -lt N ]` comparisons.

- [ ] **`2_restore_samba.sh`**: Add `PICFRAME_USER="ivan"` variable near the top.

- [ ] **`2_restore_samba.sh`**: Change the `smb.conf` share path from `/home/$USERNAME` to `/home/$PICFRAME_USER`.

- [ ] **`2_restore_samba.sh`**: After creating the `ivan.cherednychok` system user, add a step to grant it access to `/home/ivan` by adding `ivan.cherednychok` to the `ivan` group (`sudo usermod -aG ivan ivan.cherednychok`). Without this, Samba auth would succeed but file access would be denied.

- [ ] **`2_restore_samba.sh`**: Install `samba` package if not present (currently assumed installed; move `apt-get install samba` here from the install script).

## Rollback
Revert both files with `git checkout -- 1_install_picframe_developer_mode.sh 2_restore_samba.sh`.
