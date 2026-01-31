#!/bin/bash
################################################################################
# Proxmox Storage Configuration Script
################################################################################
# Configures ISO over NFS and Proxmox Backup Server storage locations
#
# Usage:
#   1. Configure storage settings in .env file
#   2. Run: ./setup-storage.sh
#
# Features:
#   - ISO storage via NFS
#   - Proxmox Backup Server (multiple datastores/namespaces)
#   - Network connectivity checks with retry logic
#   - Dry-run mode support
################################################################################

set -euo pipefail

################################################################################
# Colors and Output Functions
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1"
}

print_question() {
    echo -e "${CYAN}❓ [QUESTION]${NC} $1"
}

print_cmd() {
    echo -e "${CYAN}   💻 ${NC}$1"
}

die() {
    print_error "$1"
    exit 1
}

################################################################################
# Utility Functions
################################################################################

need_root() {
    [ "$(id -u)" -eq 0 ] || die "This script must be run as root"
}

exists_storage() {
    local id="$1"
    pvesm status 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$id"
}

load_env() {
    local envfile="${1:-.env}"
    [ -f "$envfile" ] || die "Environment file '$envfile' not found"
    
    print_info "Loading configuration from: $envfile"
    source "$envfile"
    print_success "Configuration loaded"
}

# Check network connectivity to a host
check_network_host() {
    local host="$1"
    local port="${2:-22}"
    
    # Extract hostname/IP if port is included in format host:port
    local clean_host="${host%%:*}"
    
    # Try to connect
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$clean_host/$port" 2>/dev/null; then
        return 0  # Host is reachable
    else
        return 1  # Host not reachable
    fi
}

# Check NFS server connectivity specifically
check_nfs_server() {
    local server="$1"
    
    # Try port 2049 (NFS) first
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$server/2049" 2>/dev/null; then
        return 0
    fi
    
    # Alternatively, try showmount as a fallback
    if timeout 5 showmount -e "$server" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# Retry logic for network-dependent operations
retry_with_user_choice() {
    local operation_name="$1"
    local server="$2"
    local check_type="${3:-generic}"  # 'nfs' or 'generic'
    
    while true; do
        print_info "Checking connectivity to $operation_name server: $server"
        
        local is_reachable=false
        if [ "$check_type" = "nfs" ]; then
            if check_nfs_server "$server"; then
                is_reachable=true
            fi
        else
            if check_network_host "$server" 8007; then  # PBS uses port 8007
                is_reachable=true
            fi
        fi
        
        if [ "$is_reachable" = true ]; then
            print_success "$operation_name server is reachable"
            return 0
        else
            print_warning "$operation_name server not reachable: $server"
            print_info "This could mean:"
            echo "  • Server is offline"
            echo "  • Network is down"
            echo "  • Firewall blocking connection"
            echo "  • Wrong IP/hostname in .env"
            if [ "$check_type" = "nfs" ]; then
                echo "  • NFS service not running (port 2049)"
            else
                echo "  • PBS service not running (port 8007)"
            fi
            echo ""
            
            print_question "What would you like to do?"
            echo "  1) ⏭️  Skip $operation_name and continue"
            echo "  2) 🔄 Retry (check network/server and try again)"
            echo "  3) 🛑 Abort setup"
            echo ""
            read -p "Enter choice [1/2/3]: " choice
            
            case $choice in
                1)
                    print_info "Skipping $operation_name configuration..."
                    return 1  # Skip
                    ;;
                2)
                    print_info "Retrying connection to $operation_name server..."
                    sleep 2
                    continue
                    ;;
                3)
                    die "Setup aborted by user"
                    ;;
                *)
                    print_warning "Invalid choice, please try again"
                    sleep 1
                    continue
                    ;;
            esac
        fi
    done
}

################################################################################
# ISO over NFS Storage Configuration
################################################################################

add_or_update_iso_storage() {
    print_header "💿 ISO Storage via NFS"
    
    # Validate required variables
    [ -n "${ISO_ID:-}" ] || { print_warning "ISO_ID not configured, skipping..."; return 0; }
    [ -n "${ISO_SERVER:-}" ] || die "ISO_SERVER is required"
    [ -n "${ISO_EXPORT:-}" ] || die "ISO_EXPORT is required"
    
    local id="$ISO_ID"
    local server="$ISO_SERVER"
    local export="$ISO_EXPORT"
    local content="${ISO_CONTENT:-iso}"
    
    print_info "Configuration:"
    echo "  📦 Storage ID: $id"
    echo "  🖥️  Server: $server"
    echo "  📂 Export: $export"
    echo "  📋 Content: $content"
    [ -n "${ISO_NODES:-}" ] && echo "  🔗 Nodes: $ISO_NODES"
    [ -n "${ISO_NFS_VERSION:-}" ] && echo "  🔧 NFS Version: $ISO_NFS_VERSION"
    echo ""
    
    # Check network connectivity first (NFS-specific check)
    if ! retry_with_user_choice "ISO NFS" "$server" "nfs"; then
        print_warning "ISO storage configuration skipped"
        return 0
    fi
    
    # Build command
    local cmd=(pvesm add nfs "$id" --server "$server" --export "$export" --content "$content")
    
    # Add optional parameters
    [ -n "${ISO_NODES:-}" ] && cmd+=(--nodes "$ISO_NODES")
    [ -n "${ISO_NFS_VERSION:-}" ] && cmd+=(--options "vers=$ISO_NFS_VERSION")
    
    # Check if storage exists
    if exists_storage "$id"; then
        print_warning "Storage '$id' already exists"
        print_info "NFS settings cannot be updated in place, recreating..."
        
        if [ "${DRY_RUN:-false}" = "true" ]; then
            print_cmd "pvesm remove $id"
        else
            pvesm remove "$id"
            print_success "Old storage removed"
        fi
    fi
    
    # Add storage
    print_info "Adding ISO storage '$id'..."
    print_cmd "${cmd[*]}"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        print_info "[DRY RUN] Command not executed"
    else
        if "${cmd[@]}"; then
            print_success "ISO storage '$id' configured successfully"
        else
            print_error "Failed to configure ISO storage"
            return 1
        fi
    fi
}

################################################################################
# Proxmox Backup Server Configuration (Generic)
################################################################################

add_or_update_pbs_storage() {
    local id="$1"
    local datastore="$2"
    local namespace="${3:-}"
    local label="$4"
    
    print_header "💾 PBS Storage - $label"
    
    # Validate required variables
    [ -n "${PBS_SERVER:-}" ] || die "PBS_SERVER is required"
    [ -n "${PBS_USERNAME:-}" ] || die "PBS_USERNAME is required"
    [ -n "${PASSWORD_OR_TOKEN:-}" ] || die "PASSWORD_OR_TOKEN is required"
    [ -n "${PBS_FINGERPRINT:-}" ] || die "PBS_FINGERPRINT is required"
    
    local server="$PBS_SERVER"
    local user="$PBS_USERNAME"
    local secret="$PASSWORD_OR_TOKEN"
    local fp="$PBS_FINGERPRINT"
    local content="${PBS_CONTENT:-backup}"
    
    print_info "Configuration:"
    echo "  📦 Storage ID: $id"
    echo "  🖥️  Server: $server"
    echo "  💾 Datastore: $datastore"
    echo "  👤 Username: $user"
    echo "  🔐 Fingerprint: ${fp:0:20}..."
    echo "  📋 Content: $content"
    [ -n "$namespace" ] && echo "  📁 Namespace: $namespace"
    [ -n "${PBS_NODES:-}" ] && echo "  🔗 Nodes: $PBS_NODES"
    echo ""
    
    # Build command based on whether storage exists
    local cmd
    if exists_storage "$id"; then
        print_info "PBS storage '$id' already exists, updating..."
        cmd=(pvesm set "$id" --type pbs --server "$server" --datastore "$datastore" \
             --username "$user" --password "$secret" --fingerprint "$fp" --content "$content")
    else
        print_info "Adding PBS storage '$id'..."
        cmd=(pvesm add pbs "$id" --server "$server" --datastore "$datastore" \
             --username "$user" --password "$secret" --fingerprint "$fp" --content "$content")
    fi
    
    # Add optional parameters
    [ -n "${PBS_NODES:-}" ] && cmd+=(--nodes "$PBS_NODES")
    [ -n "$namespace" ] && cmd+=(--namespace "$namespace")
    
    # Execute command
    print_cmd "${cmd[*]}"
    
    if [ "${DRY_RUN:-false}" = "true" ]; then
        print_info "[DRY RUN] Command not executed"
    else
        if "${cmd[@]}"; then
            print_success "PBS storage '$id' configured successfully"
        else
            print_error "Failed to configure PBS storage"
            print_info "Check credentials and server accessibility"
            return 1
        fi
    fi
}

################################################################################
# Configure All PBS Storage Locations
################################################################################

configure_pbs_storages() {
    # Check PBS server connectivity once
    if ! retry_with_user_choice "PBS" "$PBS_SERVER" "generic"; then
        print_warning "PBS server not reachable, skipping all PBS storage configuration"
        return 0
    fi
    
    # Configure each PBS storage location
    
    # Root namespace (current Proxmox backups)
    if [ -n "${PBS_PROXIC_ID:-}" ] && [ -n "${PBS_PROXIC_DATASTORE:-}" ]; then
        add_or_update_pbs_storage \
            "$PBS_PROXIC_ID" \
            "$PBS_PROXIC_DATASTORE" \
            "${PBS_PROXIC_NAMESPACE:-}" \
            "Proxic (Current Host)"
    fi
    
    # NucBox namespace
    if [ -n "${PBS_NUCBOX_ID:-}" ] && [ -n "${PBS_NUCBOX_DATASTORE:-}" ]; then
        add_or_update_pbs_storage \
            "$PBS_NUCBOX_ID" \
            "$PBS_NUCBOX_DATASTORE" \
            "${PBS_NUCBOX_NAMESPACE:-}" \
            "NucBox"
    fi
    
    # Add more namespace-based storages as needed
    # Example for future additions:
    # if [ -n "${PBS_HOMELAB_ID:-}" ] && [ -n "${PBS_HOMELAB_DATASTORE:-}" ]; then
    #     add_or_update_pbs_storage \
    #         "$PBS_HOMELAB_ID" \
    #         "$PBS_HOMELAB_DATASTORE" \
    #         "${PBS_HOMELAB_NAMESPACE:-}" \
    #         "Homelab"
    # fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "🌐 Proxmox Storage Configuration"
    
    # Check root privileges
    need_root
    
    # Load environment
    load_env "${1:-.env}"
    
    # Show dry-run status
    if [ "${DRY_RUN:-false}" = "true" ]; then
        print_warning "DRY RUN MODE - Commands will be shown but not executed"
    fi
    
    echo ""
    
    # Configure each storage type
    add_or_update_iso_storage
    echo ""
    
    configure_pbs_storages
    echo ""
    
    # Show final status
    print_header "📊 Storage Configuration Summary"
    
    print_info "Current Proxmox storage configuration:"
    if pvesm status; then
        echo ""
        print_success "Storage configuration complete!"
    else
        print_error "Failed to retrieve storage status"
    fi
}

main "$@"