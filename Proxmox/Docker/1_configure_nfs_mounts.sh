#!/bin/bash
#===============================================================================
# Script: setup_nfs_mount.sh
# Description: Mounts NFS share from NAS for general storage use
# NFS Server: 192.168.91.198 (nasik.lan)
# NFS Share: Books
# Mount Point: /mnt/books
# Usage: Run as root or with sudo: sudo bash setup_nfs_mount.sh
#===============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NFS_SERVER="192.168.91.198"
NFS_SERVER_HOSTNAME="nasik.lan"
NFS_SHARE="Books"
MOUNT_POINT="/mnt/books"
NFS_OPTIONS="defaults,_netdev,nfsvers=4"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if NFS client is installed
check_nfs_client() {
    log_info "Checking if NFS client is installed..."
    
    if ! command -v mount.nfs &> /dev/null; then
        log_warn "NFS client not found, installing..."
        apt-get update -y
        apt-get install -y nfs-common
        log_success "NFS client installed"
    else
        log_success "NFS client is already installed"
    fi
}

# Test NFS server connectivity
test_nfs_server() {
    log_info "Testing connectivity to NFS server..."
    
    # Test by IP
    if ping -c 2 -W 2 "$NFS_SERVER" > /dev/null 2>&1; then
        log_success "NFS server $NFS_SERVER is reachable"
    else
        log_error "Cannot reach NFS server at $NFS_SERVER"
        log_error "Please check your network connection and server IP"
        exit 1
    fi
    
    # Test by hostname
    if ping -c 2 -W 2 "$NFS_SERVER_HOSTNAME" > /dev/null 2>&1; then
        log_success "NFS server $NFS_SERVER_HOSTNAME is reachable"
        USE_HOSTNAME=true
    else
        log_warn "Hostname $NFS_SERVER_HOSTNAME is not reachable, will use IP address"
        USE_HOSTNAME=false
    fi
}

# Check if NFS share is available
check_nfs_share() {
    log_info "Checking if NFS share '$NFS_SHARE' is available..."
    
    if showmount -e "$NFS_SERVER" 2>/dev/null | grep -q "$NFS_SHARE"; then
        log_success "NFS share '$NFS_SHARE' is available on server"
    else
        log_error "NFS share '$NFS_SHARE' not found on server $NFS_SERVER"
        log_info "Available shares on $NFS_SERVER:"
        showmount -e "$NFS_SERVER" 2>/dev/null || log_error "Could not list shares"
        exit 1
    fi
}

# Create mount point directory
create_mount_point() {
    log_info "Creating mount point at $MOUNT_POINT..."
    
    if [ -d "$MOUNT_POINT" ]; then
        log_warn "Mount point $MOUNT_POINT already exists"
        
        # Check if already mounted
        if mountpoint -q "$MOUNT_POINT"; then
            log_warn "Mount point is already in use"
            read -p "Do you want to unmount it first? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                umount "$MOUNT_POINT"
                log_success "Unmounted $MOUNT_POINT"
            else
                log_error "Cannot proceed while mount point is in use"
                exit 1
            fi
        fi
    else
        mkdir -p "$MOUNT_POINT"
        log_success "Created mount point at $MOUNT_POINT"
    fi
}

# Mount NFS share
mount_nfs() {
    log_info "Mounting NFS share..."
    
    # Determine which server identifier to use
    if [ "$USE_HOSTNAME" = true ]; then
        NFS_SOURCE="${NFS_SERVER_HOSTNAME}:/${NFS_SHARE}"
    else
        NFS_SOURCE="${NFS_SERVER}:/${NFS_SHARE}"
    fi
    
    # Mount the share
    if mount -t nfs -o "$NFS_OPTIONS" "$NFS_SOURCE" "$MOUNT_POINT"; then
        log_success "Successfully mounted $NFS_SOURCE to $MOUNT_POINT"
    else
        log_error "Failed to mount NFS share"
        exit 1
    fi
}

# Test mount by creating a test file
test_mount() {
    log_info "Testing NFS mount..."
    
    TEST_FILE="$MOUNT_POINT/.nfs_test_$(date +%s)"
    
    if touch "$TEST_FILE" 2>/dev/null; then
        rm "$TEST_FILE"
        log_success "Mount is writable - test passed"
    else
        log_warn "Mount appears to be read-only or you don't have write permissions"
        log_warn "This might cause issues with BookLore"
    fi
    
    # Show mount info
    log_info "Mount information:"
    df -h "$MOUNT_POINT" | tail -1
}

# Add to /etc/fstab for persistent mounting
add_to_fstab() {
    log_info "Configuring automatic mount on boot..."
    
    # Determine which server identifier to use
    if [ "$USE_HOSTNAME" = true ]; then
        FSTAB_SOURCE="${NFS_SERVER_HOSTNAME}:/${NFS_SHARE}"
    else
        FSTAB_SOURCE="${NFS_SERVER}:/${NFS_SHARE}"
    fi
    
    FSTAB_ENTRY="$FSTAB_SOURCE $MOUNT_POINT nfs $NFS_OPTIONS 0 0"
    
    # Check if entry already exists
    if grep -q "$MOUNT_POINT" /etc/fstab; then
        log_warn "An entry for $MOUNT_POINT already exists in /etc/fstab"
        log_info "Current entry:"
        grep "$MOUNT_POINT" /etc/fstab
        echo
        read -p "Do you want to replace it? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Backup fstab
            cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
            log_info "Backed up /etc/fstab"
            
            # Remove old entry and add new one
            sed -i "\|$MOUNT_POINT|d" /etc/fstab
            echo "$FSTAB_ENTRY" >> /etc/fstab
            log_success "Updated /etc/fstab entry"
        else
            log_info "Keeping existing /etc/fstab entry"
        fi
    else
        # Backup fstab
        cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
        log_info "Backed up /etc/fstab"
        
        # Add new entry
        echo "" >> /etc/fstab
        echo "# NFS mount for BookLore storage - Added by setup_nfs_mount.sh" >> /etc/fstab
        echo "$FSTAB_ENTRY" >> /etc/fstab
        log_success "Added entry to /etc/fstab for automatic mounting on boot"
    fi
    
    # Test fstab
    log_info "Testing /etc/fstab configuration..."
    if mount -a 2>/dev/null; then
        log_success "/etc/fstab configuration is valid"
    else
        log_error "/etc/fstab configuration test failed"
        log_error "Restoring backup..."
        cp /etc/fstab.backup.$(date +%Y%m%d_%H%M%S) /etc/fstab
        exit 1
    fi
}

# Display mounted contents
show_mount_contents() {
    log_info "Showing contents of mounted share..."
    echo ""
    ls -lh "$MOUNT_POINT" | head -20
    echo ""
    
    FILE_COUNT=$(find "$MOUNT_POINT" -type f 2>/dev/null | wc -l)
    DIR_COUNT=$(find "$MOUNT_POINT" -type d 2>/dev/null | wc -l)
    
    log_info "Statistics:"
    echo "  Files: $FILE_COUNT"
    echo "  Directories: $DIR_COUNT"
}

# Print summary
print_summary() {
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}NFS Mount Setup Complete!${NC}"
    echo "==============================================================================="
    echo ""
    echo "Configuration:"
    echo "  NFS Server:    $NFS_SERVER ($NFS_SERVER_HOSTNAME)"
    echo "  NFS Share:     $NFS_SHARE"
    echo "  Mount Point:   $MOUNT_POINT"
    echo "  Mount Options: $NFS_OPTIONS"
    echo ""
    echo "Status:"
    df -h "$MOUNT_POINT" | tail -1
    echo ""
    echo "==============================================================================="
    echo "Useful Commands:"
    echo "==============================================================================="
    echo "  df -h $MOUNT_POINT           - Check mount status and space"
    echo "  ls -la $MOUNT_POINT          - List files on NFS share"
    echo "  mountpoint $MOUNT_POINT      - Check if directory is a mount point"
    echo "  umount $MOUNT_POINT          - Unmount the share"
    echo "  mount -a                     - Mount all entries in /etc/fstab"
    echo "  showmount -e $NFS_SERVER     - List available NFS shares"
    echo ""
    echo "==============================================================================="
    echo "Next Steps:"
    echo "==============================================================================="
    echo "  1. Test the mount by creating a file: touch $MOUNT_POINT/test.txt"
    echo "  2. Verify contents: ls -lh $MOUNT_POINT"
    echo "  3. The share will automatically mount on system boot"
    echo "  4. You can now use $MOUNT_POINT in your applications"
    echo ""
    echo "==============================================================================="
    echo ""
}

# Main execution
main() {
    echo ""
    echo "==============================================================================="
    echo "NFS Mount Setup Script"
    echo "==============================================================================="
    echo ""
    echo "This script will mount the NFS share '$NFS_SHARE' from $NFS_SERVER"
    echo "to $MOUNT_POINT for storage use."
    echo ""
    
    check_root
    check_nfs_client
    test_nfs_server
    check_nfs_share
    create_mount_point
    mount_nfs
    test_mount
    add_to_fstab
    show_mount_contents
    print_summary
    
    log_success "Setup complete! Your NFS share is ready to use."
    echo ""
}

# Run main function
main "$@"