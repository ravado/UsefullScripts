# run post install script from https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pbs-install
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pbs-install.sh)"
# ^ update when asked too



# Quick Mount

# Mount it
mkdir -p /mnt/internal-backups
mount /dev/sdb1 /mnt/internal-backups

# Verify
df -h | grep sdb1


# Make It Permanent

# Get UUID
blkid /dev/sdb1

# Add to /etc/fstab (replace UUID with yours)
echo "UUID=adf0758a-ced3-4e63-8464-008c07acaeb3 /mnt/internal-backups ext4 defaults 0 2" >> /etc/fstab

# Test fstab works
umount /mnt/internal-backups

# reload
systemctl daemon-reload

mount -a
df -h | grep internal-backups


# Add datastore from UI (skip datastore generation if drive is already with backups)