# Proxmox GPU Passthrough with Power Management

Automated setup for NVIDIA GPU passthrough with dynamic power management on Proxmox VE. This enables your GPU to consume only 5-15W when the VM is off (instead of 40-50W), saving ~$30-35/year in electricity costs.

## Quick Start

### 1. Prerequisites

- Proxmox VE installed
- NVIDIA GPU (RTX 30/40/50 series or GTX 10+ series)
- VT-d (Intel) or AMD-Vi (AMD) enabled in BIOS
- Root access to Proxmox host

### 2. Download Setup Files

```bash
# Download to your Proxmox host
wget https://your-repo/setup-gpu-passthrough.sh
wget https://your-repo/.env.example

chmod +x setup-gpu-passthrough.sh
```

### 3. Configure Your Environment

```bash
# Copy example configuration
cp .env.example .env

# Edit with your GPU details
nano .env
```

**Required Configuration:**

```bash
# Find your GPU PCI IDs
lspci -nn | grep -i nvidia

# Example output:
# 01:00.0 VGA ... [10de:2d04]  ← Use this for GPU_VGA_PCI_ID and GPU_VGA_DEVICE_ID
# 01:00.1 Audio ... [10de:22eb] ← Use this for GPU_AUDIO_PCI_ID and GPU_AUDIO_DEVICE_ID

# In .env file, set:
GPU_VGA_PCI_ID="0000:01:00.0"
GPU_AUDIO_PCI_ID="0000:01:00.1"
GPU_VGA_DEVICE_ID="10de:2d04"
GPU_AUDIO_DEVICE_ID="10de:22eb"
VM_ID="200"  # Your VM ID
CPU_VENDOR="intel"  # or "amd"
```

### 4. Run Setup Script

```bash
# Run as root
./setup-gpu-passthrough.sh
```

The script will:
1. ✅ Configure IOMMU and VFIO modules
2. ✅ Install NVIDIA driver (correct version for your GPU)
3. ✅ Set up persistence daemon
4. ✅ Create hook scripts for automatic GPU switching
5. ✅ Configure boot initialization

**The script handles reboots automatically** - just run it once and follow the prompts!

### 5. Add GPU to VM

After setup completes:

1. Open Proxmox web UI
2. Select your VM → Hardware → Add → PCI Device
3. Select your GPU
4. Check **"All Functions"** (includes audio)
5. Check **"PCI-Express"**
6. Click Add

### 6. Verify Setup

After final reboot:

```bash
# Check GPU is in low power state
nvidia-smi --query-gpu=name,pstate,power.draw,persistence_mode --format=csv

# Expected: P8 state, 5-15W power draw

# Monitor in real-time
watch -n 1 'nvidia-smi --query-gpu=name,pstate,power.draw --format=table'
```

## How It Works

### Dynamic GPU Switching

**VM Off (Host Control):**
```
GPU → nvidia driver → Persistence mode enabled → P8 low power state (5-15W)
```

**VM Starting (Hook Script):**
```
Hook script: Disable persistence → Unbind nvidia → Bind vfio-pci → VM uses GPU
```

**VM Running:**
```
GPU fully available to VM (40-200W depending on load)
```

**VM Stopping (Hook Script):**
```
Hook script: Unbind vfio-pci → Bind nvidia → Enable persistence → P8 state
```

### What Gets Configured

**System Configuration:**
- `/etc/default/grub` - IOMMU parameters
- `/etc/modules-load.d/vfio.conf` - VFIO modules
- `/etc/modprobe.d/blacklist.conf` - Driver blacklist

**NVIDIA Setup:**
- `/usr/local/bin/nvidia-gpu-init.sh` - Boot initialization
- `/etc/systemd/system/nvidia-persistenced.service` - Persistence daemon
- `/etc/systemd/system/nvidia-gpu-init.service` - Init service

**VM Integration:**
- `/var/lib/vz/snippets/gpu-{VM_ID}-hook.sh` - Hook script
- `/etc/pve/qemu-server/{VM_ID}.conf` - VM configuration

## Configuration Options

### .env File Reference

```bash
# GPU Configuration (REQUIRED)
GPU_VGA_PCI_ID="0000:01:00.0"      # GPU video PCI ID
GPU_AUDIO_PCI_ID="0000:01:00.1"    # GPU audio PCI ID
GPU_VGA_DEVICE_ID="10de:2d04"      # GPU vendor:device ID
GPU_AUDIO_DEVICE_ID="10de:22eb"    # Audio vendor:device ID

# VM Configuration (REQUIRED)
VM_ID="200"                         # VM that will use GPU

# Driver Configuration (REQUIRED)
NVIDIA_DRIVER_VERSION="580.119.02"  # Driver version
NVIDIA_DRIVER_URL="https://..."     # Download URL
NVIDIA_MODULE_TYPE="MIT"            # "MIT" or "Proprietary"

# System Configuration (REQUIRED)
CPU_VENDOR="intel"                  # "intel" or "amd"
AUTO_REBOOT="false"                 # Auto-reboot between phases

# Storage (Optional)
STORAGE_DRIVE_1=""                  # Additional drives for VM
STORAGE_DRIVE_2=""
```

### Driver Versions

**RTX 50 Series (5060 Ti, 5070, 5080, 5090):**
- Minimum: `580.x`
- Recommended: `580.119.02` or newer

**RTX 30/40 Series:**
- Minimum: `550.x`
- Recommended: Latest production branch

**GTX 10 Series:**
- Minimum: `470.x`
- Recommended: `550.x`

Find drivers at: https://www.nvidia.com/en-us/drivers/

## Monitoring and Debugging

### Check GPU Status

```bash
# Quick status
nvidia-smi

# Detailed power info
nvidia-smi --query-gpu=name,pstate,power.draw,persistence_mode --format=table

# Real-time monitoring
watch -n 1 'nvidia-smi --query-gpu=name,pstate,power.draw --format=table'
```

### Check Driver Binding

```bash
# What driver is currently using GPU
lspci -nnk -s 01:00.0

# Expected when VM off: Kernel driver in use: nvidia
# Expected when VM on:  Kernel driver in use: vfio-pci
```

### View Hook Script Logs

```bash
# Real-time hook script logs
journalctl -f | grep "GPU Hook"

# Recent logs
journalctl -n 50 | grep "GPU Hook"
```

### Check Services

```bash
# Persistence daemon
systemctl status nvidia-persistenced

# GPU initialization
systemctl status nvidia-gpu-init

# View boot logs
journalctl -u nvidia-gpu-init
```

## Troubleshooting

### GPU Not Entering P8 State

```bash
# Manually enable persistence
nvidia-smi -pm 1

# Check if bound to nvidia
lspci -nnk -s 01:00.0

# Restart services
systemctl restart nvidia-persistenced
systemctl restart nvidia-gpu-init
```

### VM Won't Start

```bash
# Remove stale locks
rm /var/lock/qemu-server/lock-*.conf

# Check hook script
bash -n /var/lib/vz/snippets/gpu-{VM_ID}-hook.sh

# View VM logs
journalctl -xe | grep -i "qemu\|kvm"
```

### Driver Not Loading

```bash
# Check if module exists
lsmod | grep nvidia

# Load manually
modprobe nvidia

# Check DKMS status
dkms status

# Rebuild for current kernel
dkms install nvidia/{VERSION} -k $(uname -r)
```

### IOMMU Not Working

```bash
# Check IOMMU in kernel parameters
cat /proc/cmdline | grep iommu

# Check IOMMU groups
dmesg | grep -i iommu

# Verify BIOS settings
# Intel: VT-d must be enabled
# AMD: AMD-Vi must be enabled
```

### Reset Setup

```bash
# Clear setup state and start over
rm /root/.proxmox-gpu-setup-state
./setup-gpu-passthrough.sh
```

## Expected Results

### Power Consumption

| State | Driver | Power State | Power Draw | Annual Cost* |
|-------|--------|-------------|------------|--------------|
| VM Off | nvidia | P8 | 5-15W | $4-13 |
| VM Idle (old method) | vfio-pci | P0 | 40-50W | $35-45 |
| VM Running | vfio-pci | P0-P2 | 40-200W | Varies |

*At $0.10/kWh, running 24/7

### Power Savings

- **~40W** saved when VM is off
- **~$30-35/year** in electricity costs
- Reduced heat and fan noise
- Extended GPU lifespan

## Advanced Usage

### Multiple VMs Sharing GPU

Not recommended - only one VM can use GPU at a time. The hook script is tied to a single VM.

### Multiple GPUs

Create separate hook scripts for each VM/GPU combination:
- `gpu-200-hook.sh` for VM 200 with GPU 1
- `gpu-201-hook.sh` for VM 201 with GPU 2

Update `.env` for each GPU's PCI IDs.

### Manual Control

Force GPU to specific driver:

```bash
# Bind to nvidia (low power)
echo nvidia > /sys/bus/pci/devices/0000:01:00.0/driver_override
echo 0000:01:00.0 > /sys/bus/pci/drivers/nvidia/bind
nvidia-smi -pm 1

# Bind to vfio-pci (for VM)
echo vfio-pci > /sys/bus/pci/devices/0000:01:00.0/driver_override
echo 0000:01:00.0 > /sys/bus/pci/drivers/vfio-pci/bind
```

## References

- **Proxmox Forum Thread:** https://forum.proxmox.com/threads/power-consumption-when-gpu-idle-with-passthrough.143381/
- **NVIDIA Persistence:** https://forums.developer.nvidia.com/t/setting-up-nvidia-persistenced/47986
- **Proxmox Hookscripts:** https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_hookscripts
- **NVIDIA Drivers:** https://www.nvidia.com/en-us/drivers/

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review hook script logs: `journalctl -f | grep "GPU Hook"`
3. Verify IOMMU is enabled: `dmesg | grep -i iommu`
4. Ensure BIOS virtualization is enabled (VT-d/AMD-Vi)

## License

Based on community solutions from Proxmox forums and NVIDIA documentation.