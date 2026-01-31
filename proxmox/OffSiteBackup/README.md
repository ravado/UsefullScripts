# 🛰️ Off-Site Backup Setup for Raspberry Pi / Mini Node

Build a **portable, low-power off-site backup node** in minutes — just copy & run the one-liners below 🧑‍💻

---

## ⚙️ Quick Start — One-Liners

Before calling any of the commands you would need `curl`

```bash
apt install curl -y
```

## 🌍 SECTION 1 — Remote Backup Device (e.g., Raspberry Pi / Mini Node)

These commands prepare your off-site backup node — a small device that stores your backups and joins your Tailscale network.


### 🧹 0. Prepare Disk

Detects the USB SSD, offers to format it to ext4, mounts it under `/mnt/backupdisk`, and adds it to `/etc/fstab`.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/main/proxmox/OffSiteBackup/0_setup_disc.sh)"
```

---

### 🔄 1. Setup Rsync Service

Installs and configures `rsyncd`, asks for username & password, and enables the daemon on port 873.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/main/proxmox/OffSiteBackup/1_setup_rsync_service.sh)"
```

---

### 🌐 2. Join Tailnet (Pi)

Installs Tailscale, asks for hostname, and connects your Pi securely to your Tailnet.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/main/proxmox/OffSiteBackup/2_setup_tailscale_pi.sh)"
```

---

## 🏠 SECTION 2 — LAN Gateway (Proxmox LXC / Local Router)

This LXC or lightweight VM acts as a Tailscale gateway — routing your NAS traffic to the remote Pi without installing Tailscale on the NAS itself.

### 🛜 3. Setup Tailscale Router *(optional)*

Turns a router or Proxmox node into a Tailscale subnet router.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/main/proxmox/OffSiteBackup/3_setup_tailscale_router.sh)"
```

---

### ☁️ 4. MinIO Alternative *(optional not yet fully tested)*

Deploys a MinIO S3-compatible server on the mounted disk for S3-style backups.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/main/proxmox/OffSiteBackup/setup_minio_with_disk.sh)"
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

Maintained by [@ravado](https://github.com/ravado)\
Part of the 📦 [usefull-scripts → proxmox → OffSiteBackup](https://github.com/ravado/usefull-scripts/tree/main/proxmox/OffSiteBackup)