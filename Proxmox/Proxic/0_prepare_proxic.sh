#1. Apply Post Install Script
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"

#2. Update
apt update && apt full-upgrade -y

#3. Attach drives
Add .env
- nano .env
- (copy from Proxmox/PCIPassthrough/.env)
Invoke 
- Proxmox/PCIPassthrough/0_add_required_storage_locations.sh

#4. Restore Win11 vm from PBS

#5. Attach drives for win vm
qm set 200 -sata0 /dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S5B3NY0M902681A
qm set 200 -sata1 /dev/disk/by-id/ata-WDC_WD20EFRX-68EUZN0_WD-WMC4M1501124

# 6 Configure GPU paththrough
# bash <(curl -sL \https://raw.githubusercontent.com/Danilop95/Proxmox-Enhanced-Configuration-Utility/refs/heads/main/scripts/pecu_release_selector.sh)
# --> obsolete, try to do manually....

# 6. Configure GPU
# **Step 0 — Preparation**
apt install build-essential dkms pve-headers pkg-config

## 6.2. Check kernel and headers:
uname -r
# dpkg -l | grep pve-headers
dpkg -l | grep headers
> - Ensure headers match the running kernel (e.g., `6.14.11-2-pve`).

## 6.3. Blacklist conflicting modules in /etc/modprobe.d/blacklist.conf:
> #blacklist nouveau
> blacklist radeon
> blacklist nvidia

## 6.4 Update initramfs and reboot:
update-initramfs -u
reboot


# **Step 1 — Prepare GPUs for Driver Installation**

# 1. List all NVIDIA GPUs:
lspci -nn | grep -i nvidia
# Example output:
>01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GB206 [GeForce RTX 5060 Ti] [10de:2d04] (rev a1)
>01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:22eb] (rev a1)

# 2. **Important:** Both P400 and GTX 1060 **must be visible to the host** when installing the NVIDIA driver. This ensures the NVIDIA persistence daemon can manage both GPUs, allowing idle power management and avoiding errors during passthrough.
# 3. Temporarily unbind the GPU you want to dedicate to VFIO (GTX 1060) **only for driver installation**, so the driver can see it:
echo 0000:01:00.0 > /sys/bus/pci/devices/0000:01:00.0/driver/unbind
echo 0000:01:00.1 > /sys/bus/pci/devices/0000:01:00.1/driver/unbind
echo "" > /sys/bus/pci/devices/0000:01:00.0/driver_override


# Create downloads directory and download nvidia
mkdir -p ~/nvidia-driver
cd ~/nvidia-driver

wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.119.02/NVIDIA-Linux-x86_64-580.119.02.run


# Make it executable
chmod +x NVIDIA-Linux-x86_64-580.119.02.run


# Run installer:
./NVIDIA-Linux-x86_64-580.119.02.run


  -> Multiple kernel module types are available for this system. Which would you like to use?
  --> MIT

->WARNING: nvidia-installer was forced to guess the X library path '/usr/lib' and X module path '/usr/lib/xorg/modules'; these
           paths were not queryable from the system.  If X fails to find the NVIDIA X driver module, please install the
           `pkg-config` utility and the X.Org SDK/development package for your distribution and reinstall the driver.             
--> OK

-> WARNING: Unable to find a suitable destination to install 32-bit compatibility libraries. Your system may not be set up for     
           32-bit compatibility. 32-bit compatibility files will not be installed; if you wish to install them, re-run the        
           installation and set a valid directory with the --compat32-libdir option.
--> OK
  
-> Would you like to register the kernel module sources with DKMS? This will allow DKMS to automatically build a new module, if    
  your kernel changes later.
--> Yes

-> Would you like to run the nvidia-xconfig utility to automatically update your X configuration file so that the NVIDIA X driver
  will be used when you restart X?  Any pre-existing X configuration file will be backed up.                                      
--> NO

-> Installation of the NVIDIA Accelerated Graphics Driver for Linux-x86_64 (version: 580.119.02) is now complete.  Please update   
  your xorg.conf file as appropriate; see the file /usr/share/doc/NVIDIA_GLX-1.0/README.txt for details.
--> OK



# **Step 3 — Verify Driver Installation**
nvidia-smi
lsmod | grep nvidia


## **Step 4 — Enable NVIDIA Persistence Daemon**
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


# Reload systemd and enable:
systemctl daemon-reload
systemctl enable nvidia-persistenced
systemctl start nvidia-persistenced
systemctl status nvidia-persistenced


## **Step 5 — Return GTX 1060 to VFIO for Passthrough**
echo vfio-pci > /sys/bus/pci/devices/0000:01:00.0/driver_override
echo vfio-pci > /sys/bus/pci/devices/0000:01:00.1/driver_override
echo 0000:01:00.0 > /sys/bus/pci/drivers_probe
echo 0000:01:00.1 > /sys/bus/pci/drivers_probe