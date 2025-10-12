# 🛰️ Off-Site Backup Setup for Raspberry Pi / Mini Node

Build a **portable, low-power off-site backup node** in minutes — just copy & run the one-liners below 🧑‍💻

---

## ⚙️ Quick Start — One-Liners

### 🧹 0. Prepare Disk
Detects the USB SSD, offers to format it to ext4, mounts it under `/mnt/backupdisk`, and adds it to `/etc/fstab`.
```bash
curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/main/Proxmox/OffSiteBackup/0_setup_disc.sh | sudo bash
```

---

### 🔄 1. Setup Rsync Service
Installs and configures `rsyncd`, asks for username & password, and enables the daemon on port 873.
```bash
curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/main/Proxmox/OffSiteBackup/1_setup_rsync_service.sh | sudo bash
```

---

### 🌐 2. Join Tailnet (Pi)
Installs Tailscale, asks for hostname, and connects your Pi securely to your Tailnet.
```bash
curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/main/Proxmox/OffSiteBackup/1_setup_tailscale_pi.sh | sudo bash
```

---

### 🛜 3. Setup Tailscale Router *(optional)*
Turns a router or Proxmox node into a Tailscale subnet router.
```bash
curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/main/Proxmox/OffSiteBackup/2_setup_tailscale_router.sh | sudo bash
```

---

### ☁️ 4. MinIO Alternative *(optional)*
Deploys a MinIO S3-compatible server on the mounted disk for S3-style backups.
```bash
curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/main/Proxmox/OffSiteBackup/setup_minio_with_disk.sh | sudo bash
```

---

## 🧩 Typical Flow

1. 🧹 **Prepare disk** → `0_setup_disc.sh`  
2. 🔄 **Install rsync server** → `1_setup_rsync_service.sh`  
3. 🌐 **Join Tailnet** → `1_setup_tailscale_pi.sh`  
4. 🛜 *(optional)* expose LAN → `2_setup_tailscale_router.sh`  
5. ☁️ *(optional)* run MinIO → `setup_minio_with_disk.sh`

After that your node is reachable in Tailnet on port `873`:
```bash
rsync -av /data/ backup@100.x.x.x::backup
```

---

## 🧠 Notes

- 🧯 Scripts block formatting of `mmcblk0` (the system SD card).  
- ⚡ Raspberry Pi Zero 2 W + SSD consumes ≈ 3–4 W 24/7.  
- 🔐 All traffic via Tailscale is end-to-end encrypted.  
- 🔁 Each script can be safely re-run — they’re idempotent.

---

## 🧡 Author

Maintained by [@ravado](https://github.com/ravado)  
Part of the 📦 [UsefullScripts → Proxmox → OffSiteBackup](https://github.com/ravado/UsefullScripts/tree/main/Proxmox/OffSiteBackup)

