#!/bin/bash

################################################################################
# NVIDIA GPU Power Management Setup for Proxmox VFIO Passthrough
# This script automates the setup of NVIDIA driver and persistence daemon
# to reduce idle GPU power consumption from ~40W to minimal levels
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_info "Starting NVIDIA GPU Power Management Setup for Proxmox..."
echo ""

################################################################################
# STEP 0: Get GPU Information
################################################################################

print_info "Step 0: Detecting NVIDIA GPUs..."
echo ""

# List all NVIDIA devices
nvidia_devices=$(lspci -nn | grep -i nvidia || true)

if [ -z "$nvidia_devices" ]; then
    print_error "No NVIDIA devices found!"
    exit 1
fi

echo "Found NVIDIA devices:"
echo "$nvidia_devices"
echo ""

# Prompt user to enter GPU PCI IDs
print_warning "Please identify your GPU PCI IDs from the list above."
echo "Example format: 0000:65:00.0 for GPU and 0000:65:00.1 for Audio"
echo ""

read -p "Enter GPU Video PCI ID (e.g., 0000:65:00.0): " GPU_VGA
read -p "Enter GPU Audio PCI ID (e.g., 0000:65:00.1): " GPU_AUDIO
read -p "Enter VM ID that will use this GPU (e.g., 311): " VM_ID

echo ""
print_info "Configuration:"
echo "  GPU Video: $GPU_VGA"
echo "  GPU Audio: $GPU_AUDIO"
echo "  VM ID: $VM_ID"
echo ""
read -p "Is this correct? (y/n): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_error "Setup cancelled by user"
    exit 1
fi

################################################################################
# STEP 1: Install Prerequisites
################################################################################

print_info "Step 1: Installing prerequisites..."
apt update
apt install -y build-essential dkms pve-headers pkg-config

# Verify kernel headers
current_kernel=$(uname -r)
print_info "Current kernel: $current_kernel"

if ! dpkg -l | grep -q "pve-headers-$current_kernel"; then
    print_warning "Kernel headers may not match running kernel"
fi

print_success "Prerequisites installed"
echo ""

################################################################################
# STEP 2: Blacklist Conflicting Drivers
################################################################################

print_info "Step 2: Configuring driver blacklist..."

blacklist_file="/etc/modprobe.d/blacklist.conf"

# Backup existing file if it exists
if [ -f "$blacklist_file" ]; then
    cp "$blacklist_file" "${blacklist_file}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Add blacklist entries if not already present
if ! grep -q "blacklist nouveau" "$blacklist_file" 2>/dev/null; then
    echo "blacklist nouveau" >> "$blacklist_file"
fi

if ! grep -q "blacklist radeon" "$blacklist_file" 2>/dev/null; then
    echo "blacklist radeon" >> "$blacklist_file"
fi

print_success "Driver blacklist configured"
echo ""

################################################################################
# STEP 3: Check for NVIDIA Driver
################################################################################

print_info "Step 3: Checking for NVIDIA driver..."

if command -v nvidia-smi &> /dev/null; then
    print_info "NVIDIA driver appears to be installed"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    echo ""
    read -p "Do you want to skip driver installation? (y/n): " skip_driver
    
    if [[ $skip_driver =~ ^[Yy]$ ]]; then
        print_info "Skipping driver installation"
        driver_installed=true
    else
        driver_installed=false
    fi
else
    print_warning "NVIDIA driver not detected"
    driver_installed=false
fi

if [ "$driver_installed" = false ]; then
    print_info "Please download the NVIDIA driver from: https://www.nvidia.com/en-us/drivers/"
    read -p "Enter the full path to NVIDIA driver installer (e.g., ./NVIDIA-Linux-x86_64-XXX.run): " driver_path
    
    if [ ! -f "$driver_path" ]; then
        print_error "Driver file not found: $driver_path"
        exit 1
    fi
    
    # Temporarily unbind GPU from VFIO if bound
    print_info "Temporarily unbinding GPU from VFIO for driver installation..."
    
    if [ -d "/sys/bus/pci/devices/$GPU_VGA/driver" ]; then
        echo "$GPU_VGA" > /sys/bus/pci/devices/$GPU_VGA/driver/unbind 2>/dev/null || true
    fi
    
    if [ -d "/sys/bus/pci/devices/$GPU_AUDIO/driver" ]; then
        echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
    fi
    
    echo "" > /sys/bus/pci/devices/$GPU_VGA/driver_override 2>/dev/null || true
    echo "" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override 2>/dev/null || true
    
    print_info "Installing NVIDIA driver..."
    chmod +x "$driver_path"
    
    # Run installer with no X configuration
    "$driver_path" --no-questions --ui=none --no-x-check
    
    print_success "NVIDIA driver installed"
    
    # Verify installation
    if command -v nvidia-smi &> /dev/null; then
        print_success "Driver installation verified"
        nvidia-smi
    else
        print_error "Driver installation may have failed"
        exit 1
    fi
fi

echo ""

################################################################################
# STEP 4: Configure NVIDIA Persistence Daemon
################################################################################

print_info "Step 4: Configuring NVIDIA Persistence Daemon..."

persistenced_service="/etc/systemd/system/nvidia-persistenced.service"

cat > "$persistenced_service" << 'EOF'
[Unit]
Description=NVIDIA Persistence Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user root --persistence-mode
ExecStop=/usr/bin/nvidia-persistenced --terminate
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

print_success "Persistence daemon service created"

# Reload systemd
systemctl daemon-reload

# Enable and start the service
systemctl enable nvidia-persistenced
systemctl start nvidia-persistenced

# Check status
if systemctl is-active --quiet nvidia-persistenced; then
    print_success "NVIDIA Persistence Daemon is running"
else
    print_warning "NVIDIA Persistence Daemon may not be running correctly"
    systemctl status nvidia-persistenced --no-pager
fi

echo ""

################################################################################
# STEP 5: Create Hook Script
################################################################################

print_info "Step 5: Creating VM hook script..."

hook_dir="/var/lib/vz/snippets"
hook_file="$hook_dir/gpu-${VM_ID}-hook.sh"

# Create snippets directory if it doesn't exist
mkdir -p "$hook_dir"

# Create the hook script
cat > "$hook_file" << EOF
#!/usr/bin/env bash
################################################################################
# GPU Passthrough Hook for VM $VM_ID
# Automatically manages GPU power state during VM start/stop
################################################################################

GPU_VGA="$GPU_VGA"
GPU_AUDIO="$GPU_AUDIO"

if [ "\$2" == "pre-start" ]; then
    # VM is starting - prepare GPU for passthrough
    
    # Disable persistence mode to allow unbinding
    nvidia-smi -i "\$GPU_VGA" --persistence-mode=0 2>/dev/null || true
    
    # Unbind from NVIDIA driver
    echo "\$GPU_VGA" > /sys/bus/pci/devices/\$GPU_VGA/driver/unbind 2>/dev/null || true
    echo "\$GPU_AUDIO" > /sys/bus/pci/devices/\$GPU_AUDIO/driver/unbind 2>/dev/null || true
    
    # Override to vfio-pci
    echo vfio-pci > /sys/bus/pci/devices/\$GPU_VGA/driver_override
    echo vfio-pci > /sys/bus/pci/devices/\$GPU_AUDIO/driver_override
    
    # Bind to vfio-pci
    echo "\$GPU_VGA" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    echo "\$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    
    logger "GPU \$GPU_VGA bound to vfio-pci for VM $VM_ID"

elif [ "\$2" == "post-stop" ]; then
    # VM has stopped - return GPU to host for power management
    
    # Unbind from vfio-pci
    echo "\$GPU_VGA" > /sys/bus/pci/devices/\$GPU_VGA/driver/unbind 2>/dev/null || true
    echo "\$GPU_AUDIO" > /sys/bus/pci/devices/\$GPU_AUDIO/driver/unbind 2>/dev/null || true
    
    # Override to nvidia driver
    echo nvidia > /sys/bus/pci/devices/\$GPU_VGA/driver_override
    echo "" > /sys/bus/pci/devices/\$GPU_AUDIO/driver_override
    
    # Bind to nvidia driver
    echo "\$GPU_VGA" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null || true
    
    # Re-enable persistence mode for low power state
    sleep 1
    nvidia-smi -i "\$GPU_VGA" --persistence-mode=1 2>/dev/null || true
    
    logger "GPU \$GPU_VGA returned to NVIDIA driver with persistence mode enabled"
fi

exit 0
EOF

# Make hook script executable
chmod +x "$hook_file"

print_success "Hook script created: $hook_file"
echo ""

################################################################################
# STEP 6: Configure VM
################################################################################

print_info "Step 6: Configuring VM $VM_ID..."

vm_config="/etc/pve/qemu-server/${VM_ID}.conf"

if [ ! -f "$vm_config" ]; then
    print_error "VM configuration file not found: $vm_config"
    print_warning "You will need to manually add the hook script to your VM configuration"
    echo "Add this line to /etc/pve/qemu-server/${VM_ID}.conf:"
    echo "hookscript: local:snippets/gpu-${VM_ID}-hook.sh"
else
    # Backup VM config
    cp "$vm_config" "${vm_config}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if hookscript already exists
    if grep -q "^hookscript:" "$vm_config"; then
        print_warning "Hook script entry already exists in VM config"
        read -p "Replace existing hook script? (y/n): " replace_hook
        
        if [[ $replace_hook =~ ^[Yy]$ ]]; then
            sed -i "s|^hookscript:.*|hookscript: local:snippets/gpu-${VM_ID}-hook.sh|" "$vm_config"
            print_success "Hook script updated in VM config"
        fi
    else
        echo "hookscript: local:snippets/gpu-${VM_ID}-hook.sh" >> "$vm_config"
        print_success "Hook script added to VM config"
    fi
fi

echo ""

################################################################################
# STEP 7: Initial GPU Setup
################################################################################

print_info "Step 7: Binding GPU to NVIDIA driver for initial setup..."

# Unbind from any current driver
if [ -d "/sys/bus/pci/devices/$GPU_VGA/driver" ]; then
    echo "$GPU_VGA" > /sys/bus/pci/devices/$GPU_VGA/driver/unbind 2>/dev/null || true
fi

if [ -d "/sys/bus/pci/devices/$GPU_AUDIO/driver" ]; then
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null || true
fi

# Set override to nvidia
echo nvidia > /sys/bus/pci/devices/$GPU_VGA/driver_override 2>/dev/null || true
echo "" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override 2>/dev/null || true

# Bind to nvidia driver
echo "$GPU_VGA" > /sys/bus/pci/drivers/nvidia/bind 2>/dev/null || true

# Enable persistence mode
sleep 1
nvidia-smi -i "$GPU_VGA" --persistence-mode=1 2>/dev/null || true

print_success "GPU bound to NVIDIA driver with persistence mode enabled"
echo ""

################################################################################
# STEP 8: Verification
################################################################################

print_info "Step 8: Verifying setup..."
echo ""

# Check nvidia-smi
print_info "Current GPU status:"
nvidia-smi --query-gpu=index,name,pstate,power.draw,persistence_mode --format=table

echo ""

# Check persistence daemon
print_info "Persistence daemon status:"
systemctl status nvidia-persistenced --no-pager | head -n 5

echo ""
print_success "Setup complete!"
echo ""

################################################################################
# Final Instructions
################################################################################

print_info "================================"
print_info "SETUP SUMMARY"
print_info "================================"
echo ""
echo "GPU Configuration:"
echo "  - GPU: $GPU_VGA"
echo "  - Audio: $GPU_AUDIO"
echo "  - VM ID: $VM_ID"
echo ""
echo "Files Created:"
echo "  - Persistence service: $persistenced_service"
echo "  - Hook script: $hook_file"
echo ""
echo "Expected Behavior:"
echo "  - VM OFF: GPU in P8 state (low power ~5-10W)"
echo "  - VM ON: GPU available for passthrough"
echo "  - Automatic switching when VM starts/stops"
echo ""
print_warning "NEXT STEPS:"
echo "  1. Reboot your system for all changes to take effect"
echo "  2. After reboot, verify GPU is in P8 state with: nvidia-smi"
echo "  3. Start VM $VM_ID and verify GPU passthrough works"
echo "  4. Stop VM $VM_ID and verify GPU returns to low power state"
echo ""
print_info "To monitor power consumption:"
echo "  watch -n 1 'nvidia-smi --query-gpu=name,pstate,power.draw,persistence_mode --format=table'"
echo ""
print_info "Hook script log messages can be viewed with:"
echo "  journalctl -f | grep GPU"
echo ""

read -p "Would you like to reboot now? (y/n): " reboot_now

if [[ $reboot_now =~ ^[Yy]$ ]]; then
    print_info "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    print_warning "Remember to reboot before testing!"
fi