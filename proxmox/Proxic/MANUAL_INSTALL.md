# Proxmox Setup Guide - RTX 5060 Ti with Power Management

## 1. Apply Post Install Script
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

## 2. Update System
```bash
apt update && apt full-upgrade -y
```

## 3. Attach Drives
Add .env
```bash
nano .env
# (copy from Proxmox/PCIPassthrough/.env)
```

Invoke 
```bash
./Proxmox/PCIPassthrough/0_add_required_storage_locations.sh
```

## 4. Restore Win11 VM from PBS

## 5. Attach Drives for Win VM
```bash
qm set 200 -sata0 /dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S5B3NY0M902681A
qm set 200 -sata1 /dev/disk/by-id/ata-WDC_WD20EFRX-68EUZN0_WD-WMC4M1501124
```

---

## 6. Configure PCIe Passthrough (Manual Setup)

### 6.1. Enable IOMMU in GRUB
```bash
nano /etc/default/grub
```

Find the line with `GRUB_CMDLINE_LINUX_DEFAULT` and change to:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

Update GRUB:
```bash
update-grub
```

### 6.2. Load VFIO Modules
```bash
nano /etc/modules-load.d/vfio.conf
```

Add these lines:
```bash
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

### 6.3. Blacklist Conflicting Drivers
```bash
nano /etc/modprobe.d/blacklist.conf
```

Add:
```bash
blacklist nouveau
blacklist radeon
# Do NOT blacklist nvidia - we need it for power management
```

### 6.4. Disable Any Existing VFIO Auto-Binding
```bash
# If PECU or other tools created this file, disable it
mv /etc/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf.disabled 2>/dev/null || true
```

### 6.5. Update Initramfs and Reboot
```bash
update-initramfs -u
reboot
```

### 6.6. Verify IOMMU After Reboot
```bash
# Check IOMMU is enabled
dmesg | grep -i iommu

# Should show: "IOMMU enabled" or "DMAR: IOMMU enabled"

# Check kernel parameters
cat /proc/cmdline

# Should include: intel_iommu=on iommu=pt
```

---

## 7. Install NVIDIA Driver and Configure Power Management

### 7.1. Install Prerequisites
```bash
apt install -y build-essential dkms pve-headers pkg-config
```

### 7.2. Check Kernel and Headers Match
```bash
uname -r
dpkg -l | grep headers
```

Ensure you have `proxmox-headers-X.XX.X-X-pve` matching your kernel version.

### 7.3. Identify Your GPU
```bash
lspci -nn | grep -i nvidia
```

Example output:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GB206 [GeForce RTX 5060 Ti] [10de:2d04] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22eb] (rev a1)
```

**Note your PCI IDs:** `01:00.0` and `01:00.1`

### 7.4. Unbind GPU (If Currently Bound)
```bash
# Unbind GPU from any current driver
echo 0000:01:00.0 > /sys/bus/pci/devices/0000:01:00.0/driver/unbind 2>/dev/null || true
echo 0000:01:00.1 > /sys/bus/pci/devices/0000:01:00.1/driver/unbind 2>/dev/null || true

# Clear any driver overrides
echo "" > /sys/bus/pci/devices/0000:01:00.0/driver_override 2>/dev/null || true
```

### 7.5. Download NVIDIA Driver
```bash
# Create downloads directory
mkdir -p ~/nvidia-driver
cd ~/nvidia-driver

# Download driver for RTX 5060 Ti (580.x required)
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.119.02/NVIDIA-Linux-x86_64-580.119.02.run

# Make executable
chmod +x NVIDIA-Linux-x86_64-580.119.02.run
```

### 7.6. Install NVIDIA Driver
```bash
./NVIDIA-Linux-x86_64-580.119.02.run
```

**Installation prompts:**

1. **Kernel module type?** → `MIT` (or `Proprietary`, either works)
2. **X library path warning?** → `OK` (we don't need X)
3. **32-bit compatibility warning?** → `OK` (not needed)
4. **Register with DKMS?** → `Yes` (important for kernel updates)
5. **Run nvidia-xconfig?** → `No` (headless server)

### 7.7. Verify Driver Installation
```bash
# Check driver installed
nvidia-smi

# Check modules loaded
lsmod | grep nvidia

# Check DKMS status
dkms status
```

---

## 8. Configure NVIDIA Persistence Daemon

### 8.1. Create Persistence Service
```bash
cat <<EOF > /etc/systemd/system/nvidia-persistenced.service
[Unit]
Description=NVIDIA Persistence Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user root --no-persistence-mode
ExecStop=/usr/bin/nvidia-persistenced --terminate
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
```

**Note:** `--no-persistence-mode` allows hook scripts to control persistence dynamically.

### 8.2. Enable Persistence Service
```bash
systemctl daemon-reload
systemctl enable nvidia-persistenced
systemctl start nvidia-persistenced
systemctl status nvidia-persistenced
```

---

## 9. Configure GPU Boot Initialization

### 9.1. Create Initialization Script
```bash
nano /usr/local/bin/nvidia-gpu-init.sh
```

Add this content (replace PCI IDs with yours):
```bash
#!/bin/bash
# NVIDIA GPU Initialization on Boot

GPU_VGA="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"

# Wait for system to settle
sleep 5

logger "nvidia-gpu-init: Starting GPU initialization"

# Check if already bound to nvidia
if [ -e "/sys/bus/pci/devices/$GPU_VGA/driver" ]; then
    CURRENT_DRIVER=$(readlink /sys/bus/pci/devices/$GPU_VGA/driver | awk -F'/' '{print $NF}')
    
    if [ "$CURRENT_DRIVER" == "nvidia" ]; then
        logger "nvidia-gpu-init: GPU already on nvidia driver"
        /usr/bin/nvidia-smi -pm 1
        exit 0
    fi
    
    # Unbind from current driver
    echo "$GPU_VGA" > /sys/bus/pci/devices/$GPU_VGA/driver/unbind 2>/dev/null || true
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
fi

# Bind to nvidia driver
echo "nvidia" > /sys/bus/pci/devices/$GPU_VGA/driver_override
echo "$GPU_VGA" > /sys/bus/pci/drivers/nvidia/bind

# Wait and enable persistence
sleep 2
/usr/bin/nvidia-smi -pm 1

logger "nvidia-gpu-init: GPU initialization complete"
exit 0
```

Make it executable:
```bash
chmod +x /usr/local/bin/nvidia-gpu-init.sh
```

### 9.2. Create Systemd Service
```bash
nano /etc/systemd/system/nvidia-gpu-init.service
```

Add:
```ini
[Unit]
Description=NVIDIA GPU Initialization on Boot
After=nvidia-persistenced.service
Requires=nvidia-persistenced.service
Before=pve-guests.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-gpu-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
systemctl daemon-reload
systemctl enable nvidia-gpu-init.service
```

---

## 10. Create VM Hook Script

### 10.1. Create Hook Script

```bash
mkdir -p /var/lib/vz/snippets
chmod 755 /var/lib/vz/snippets
```

```bash
nano /var/lib/vz/snippets/5060ti-hook.sh
```

Add this content (replace PCI IDs with yours):
```bash
#!/usr/bin/env bash
################################################################################
# GPU Passthrough Hook for VM 200
################################################################################

GPU_VGA="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"

if [ "$2" == "pre-start" ]; then
    # VM starting - bind GPU to vfio-pci
    logger "GPU Hook: VM $1 starting - binding GPU to vfio-pci"
    
    # Disable persistence mode
    nvidia-smi -i "$GPU_VGA" --persistence-mode=0 2>/dev/null || true
    
    # Unbind from NVIDIA driver
    echo "$GPU_VGA" > /sys/bus/pci/devices/$GPU_VGA/driver/unbind 2>/dev/null || true
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
    
    # Bind to vfio-pci
    echo vfio-pci > /sys/bus/pci/devices/$GPU_VGA/driver_override
    echo vfio-pci > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
    echo "$GPU_VGA" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    
    logger "GPU Hook: GPU bound to vfio-pci for VM $1"

elif [ "$2" == "post-stop" ]; then
    # VM stopped - return GPU to nvidia driver
    logger "GPU Hook: VM $1 stopped - returning GPU to nvidia driver"
    
    # Unbind from vfio-pci
    echo "$GPU_VGA" > /sys/bus/pci/devices/$GPU_VGA/driver/unbind 2>/dev/null || true
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
    
    # Bind to nvidia driver
    echo nvidia > /sys/bus/pci/devices/$GPU_VGA/driver_override
    echo "" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
    echo "$GPU_VGA" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null || true
    
    # Re-enable persistence mode
    sleep 1
    nvidia-smi -i "$GPU_VGA" --persistence-mode=1 2>/dev/null || true
    
    logger "GPU Hook: GPU returned to nvidia driver with persistence mode"
fi

exit 0
```

Make it executable:
```bash
chmod +x /var/lib/vz/snippets/5060ti-hook.sh
```

### 10.2. Add Hook Script to VM Config
```bash
nano /etc/pve/qemu-server/200.conf
```

Add this line:
```ini
hookscript: local:snippets/5060ti-hook.sh
```

---

## 11. Add GPU to VM (Proxmox Web UI)

1. Select VM 200
2. Hardware → Add → PCI Device
3. Select your GPU (01:00.0)
4. Check **"All Functions"** (includes audio device)?
5. Check **"PCI-Express"**
6. Click Add

Your VM config should now have:
```ini
hostpci0: 0000:01:00,pcie=1
```

---

## 12. Final Reboot and Testing

### 12.1. Reboot System
```bash
reboot
```

### 12.2. After Reboot - Verify Setup

**Check GPU is on nvidia driver:**
```bash
lspci -nnk -s 01:00.0
# Should show: Kernel driver in use: nvidia
```

**Check power state:**
```bash
nvidia-smi --query-gpu=name,pstate,power.draw,persistence_mode --format=csv
# Should show: P8 state, ~5-15W power
```

**Monitor in real-time:**
```bash
watch -n 1 'nvidia-smi --query-gpu=name,pstate,power.draw --format=table'
```

### 12.3. Test VM Start/Stop

**Terminal 1 - Monitor GPU:**
```bash
watch -n 1 'lspci -nnk -s 01:00.0 | grep "driver in use"; nvidia-smi 2>&1 | head -15'
```

**Terminal 2 - Control VM:**
```bash
# Start VM
qm start 200
# GPU should switch to vfio-pci

# Stop VM
qm stop 200
# GPU should return to nvidia driver and enter P8 state
```

**Check hook script logs:**
```bash
journalctl -f | grep "GPU Hook"
```

---

## Expected Results

### VM Off:
- Driver: `nvidia`
- Power State: `P8`
- Power Draw: `5-15W`

### VM Running:
- Driver: `vfio-pci`
- Power State: `N/A` (managed by VM)
- Power Draw: `40-200W` (depending on load)

### Power Savings:
- **~40W savings** when VM is idle
- **~$30-35/year** at $0.10/kWh

---

## Troubleshooting

### GPU Not Entering P8:
```bash
# Manually enable persistence
nvidia-smi -pm 1

# Check if bound to nvidia
lspci -nnk -s 01:00.0
```

### VM Won't Start:
```bash
# Remove stale locks
rm /var/lock/qemu-server/lock-200.conf

# Check hook script syntax
bash -n /var/lib/vz/snippets/5060ti-hook.sh

# View logs
journalctl -xe | grep -i "qemu\|kvm\|hook"
```

### Driver Not Loading After Reboot:
```bash
# Check if module exists
lsmod | grep nvidia

# Load manually
modprobe nvidia

# Check DKMS
dkms status

# Rebuild if needed
dkms install nvidia/580.119.02 -k $(uname -r)
```

---

## Notes

- **IOMMU** must be enabled in BIOS (VT-d for Intel)
- **Headers** must match running kernel exactly
- **Don't blacklist nvidia driver** - we need it for power management
- **Hook scripts** automatically switch GPU between nvidia and vfio-pci
- **Persistence daemon** with `--no-persistence-mode` allows hook script control