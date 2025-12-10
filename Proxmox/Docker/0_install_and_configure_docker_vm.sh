#!/bin/bash
#===============================================================================
# Script: install_and_configure_docker_vm.sh
# Description: Installs Docker, Docker Compose, Portainer, and Proxmox tools on a Debian/Ubuntu VM
# Usage: Run as root or with sudo: sudo bash install_and_configure_docker_vm.sh
# Tested on: Debian 11/12, Ubuntu 22.04/24.04
# Enhanced with: NFS support, QEMU guest agent, Docker testing, Watchtower option
# Directory structure: /opt/docker/<app>/ with compose files alongside data
#===============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_ROOT="/opt/docker"

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

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_info "Detected OS: $OS $VERSION"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    log_success "System packages updated"
}

# Install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    log_success "Prerequisites installed"
}

# Install NFS client for network storage
install_nfs_client() {
    log_info "Installing NFS client for network storage..."
    apt-get install -y nfs-common
    log_success "NFS client installed"
    log_info "You can now mount NFS shares with: mount -t nfs <nfs-server>:/path /mnt/point"
}

# Install QEMU guest agent for better Proxmox integration
install_qemu_agent() {
    log_info "Installing QEMU guest agent for Proxmox integration..."
    apt-get install -y qemu-guest-agent
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent
    log_success "QEMU guest agent installed and started"
    log_info "This enables better VM management from Proxmox (shutdown, snapshots, IP detection)"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Remove old versions if they exist
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    
    if [[ "$OS" == "debian" ]]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add the repository to Apt sources
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    elif [[ "$OS" == "ubuntu" ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add the repository to Apt sources
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        log_error "Unsupported OS: $OS"
        exit 1
    fi
    
    # Update package index
    apt-get update -y
    
    # Install Docker packages
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    # Verify installation
    if docker --version; then
        log_success "Docker installed successfully"
    else
        log_error "Docker installation failed"
        exit 1
    fi
}

# Install Docker Compose (standalone version as backup)
install_docker_compose() {
    log_info "Docker Compose plugin is already installed with Docker..."
    
    # Verify docker compose plugin
    if docker compose version; then
        log_success "Docker Compose plugin is working"
    else
        log_warn "Docker Compose plugin not working, installing standalone version..."
        
        # Install standalone docker-compose as fallback
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        if docker-compose --version; then
            log_success "Docker Compose standalone installed successfully"
        else
            log_error "Docker Compose installation failed"
            exit 1
        fi
    fi
}

# Test Docker installation
test_docker() {
    log_info "Testing Docker installation..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker test passed - hello-world container ran successfully"
    else
        log_error "Docker test failed"
        exit 1
    fi
}

# Create Docker directory structure
create_docker_structure() {
    log_info "Creating Docker directory structure at $DOCKER_ROOT..."
    
    mkdir -p "$DOCKER_ROOT"
    
    log_success "Docker directory structure created at $DOCKER_ROOT"
    log_info "All containers will be organized under this directory"
}

# Install Portainer using bind mount
install_portainer() {
    log_info "Installing Portainer with bind mount structure..."
    
    # Create Portainer directory structure
    mkdir -p "$DOCKER_ROOT/portainer/data"
    
    # Stop and remove existing Portainer container if exists
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Create docker-compose.yml for Portainer
    cat > "$DOCKER_ROOT/portainer/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "8000:8000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
    environment:
      - TZ=Europe/Kiev
EOF
    
    log_success "Created docker-compose.yml at $DOCKER_ROOT/portainer/"
    
    # Start Portainer using docker-compose
    cd "$DOCKER_ROOT/portainer"
    docker compose up -d
    
    # Verify Portainer is running
    sleep 5
    if docker ps | grep -q portainer; then
        log_success "Portainer installed and running"
    else
        log_error "Portainer installation failed"
        exit 1
    fi
}

# Install Watchtower for automatic updates (optional)
install_watchtower() {
    echo ""
    log_info "Watchtower can automatically update your Docker containers"
    read -p "Would you like to install Watchtower for automatic container updates? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installing Watchtower..."
        
        # Create Watchtower directory structure
        mkdir -p "$DOCKER_ROOT/watchtower"
        
        # Stop and remove existing Watchtower container if exists
        docker stop watchtower 2>/dev/null || true
        docker rm watchtower 2>/dev/null || true
        
        # Create docker-compose.yml for Watchtower
        cat > "$DOCKER_ROOT/watchtower/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
      - TZ=Europe/Kiev
EOF
        
        log_success "Created docker-compose.yml at $DOCKER_ROOT/watchtower/"
        
        # Start Watchtower using docker-compose
        cd "$DOCKER_ROOT/watchtower"
        docker compose up -d
        
        if docker ps | grep -q watchtower; then
            log_success "Watchtower installed - will check for updates daily at 4 AM"
        else
            log_warn "Watchtower installation failed, continuing anyway..."
        fi
    else
        log_info "Skipping Watchtower installation"
    fi
}

# Add current user to docker group (optional)
add_user_to_docker_group() {
    if [ -n "$SUDO_USER" ]; then
        log_info "Adding user '$SUDO_USER' to docker group..."
        usermod -aG docker "$SUDO_USER"
        log_success "User '$SUDO_USER' added to docker group"
        log_warn "IMPORTANT: User must log out and log back in for group changes to take effect"
    fi
}

# Create README for Docker structure
create_readme() {
    log_info "Creating README file..."
    
    cat > "$DOCKER_ROOT/README.md" <<'EOF'
# Docker Container Organization

This directory contains all Docker containers organized in a structured way.

## Structure

```
/opt/docker/
├── <app-name>/
│   ├── docker-compose.yml    # Compose file for the app
│   ├── .env                  # Environment variables (optional)
│   ├── data/                 # Application data
│   ├── config/               # Configuration files
│   └── <other-folders>/      # App-specific directories
```

## Usage

### Starting a container
```bash
cd /opt/docker/<app-name>
docker compose up -d
```

### Stopping a container
```bash
cd /opt/docker/<app-name>
docker compose down
```

### Viewing logs
```bash
cd /opt/docker/<app-name>
docker compose logs -f
```

### Updating a container
```bash
cd /opt/docker/<app-name>
docker compose pull
docker compose up -d
```

### Restarting a container
```bash
cd /opt/docker/<app-name>
docker compose restart
```

## Installed Apps

- **portainer/** - Container management UI (https://localhost:9443)
- **watchtower/** - Automatic container updates (if installed)

## Adding New Apps

1. Create directory: `mkdir -p /opt/docker/<app-name>`
2. Create docker-compose.yml in that directory
3. Start the app: `cd /opt/docker/<app-name> && docker compose up -d`

## Backups

To backup an app, simply backup its directory:
```bash
tar -czf ~/backups/<app-name>-$(date +%Y%m%d).tar.gz /opt/docker/<app-name>
```

To backup everything:
```bash
tar -czf ~/backups/docker-all-$(date +%Y%m%d).tar.gz /opt/docker
```
EOF
    
    log_success "Created README.md at $DOCKER_ROOT/README.md"
}

# Configure firewall (optional - uncomment if needed)
# configure_firewall() {
#     log_info "Configuring firewall..."
#     if command -v ufw &> /dev/null; then
#         ufw allow 9443/tcp  # Portainer HTTPS
#         ufw allow 8000/tcp  # Portainer Edge Agent
#         ufw allow 2375/tcp  # Docker API (if needed)
#         ufw allow 2376/tcp  # Docker API TLS (if needed)
#         log_success "Firewall rules added"
#     else
#         log_warn "UFW not installed, skipping firewall configuration"
#     fi
# }

# Print summary
print_summary() {
    local PORTAINER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}Installation Complete!${NC}"
    echo "==============================================================================="
    echo ""
    echo "Installed Components:"
    echo "  ✓ Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo "  ✓ Docker Compose: $(docker compose version | cut -d' ' -f4)"
    echo "  ✓ Portainer: Running on ports 9443 (HTTPS) and 8000 (Edge Agent)"
    echo "  ✓ NFS Client: Ready for network storage"
    echo "  ✓ QEMU Guest Agent: Enabled for Proxmox integration"
    if docker ps | grep -q watchtower; then
        echo "  ✓ Watchtower: Automatic updates enabled (daily at 4 AM)"
    fi
    echo ""
    echo "Directory Structure:"
    echo "  $DOCKER_ROOT/"
    echo "  ├── portainer/"
    echo "  │   ├── docker-compose.yml"
    echo "  │   └── data/"
    if docker ps | grep -q watchtower; then
        echo "  ├── watchtower/"
        echo "  │   └── docker-compose.yml"
    fi
    echo "  └── README.md"
    echo ""
    echo "==============================================================================="
    echo "Access Portainer:"
    echo "==============================================================================="
    echo -e "  ${BLUE}HTTPS:${NC} https://${PORTAINER_IP}:9443"
    echo ""
    echo "  Note: You'll see a security warning because Portainer uses a self-signed"
    echo "        certificate. This is normal - proceed to the site and create your"
    echo "        admin account on first login."
    echo ""
    echo "==============================================================================="
    echo "Important Notes:"
    echo "==============================================================================="
    echo "  • All containers are organized under: $DOCKER_ROOT/"
    echo "  • Each app has its own folder with docker-compose.yml"
    echo "  • Use 'docker compose' (with space) not 'docker-compose' (with hyphen)"
    echo "  • If you were added to docker group, LOG OUT and LOG BACK IN"
    echo "  • Read $DOCKER_ROOT/README.md for usage examples"
    echo ""
    echo "==============================================================================="
    echo "Common Commands:"
    echo "==============================================================================="
    echo "  cd /opt/docker/<app>           - Navigate to app directory"
    echo "  docker compose up -d           - Start app"
    echo "  docker compose down            - Stop app"
    echo "  docker compose pull            - Update images"
    echo "  docker compose logs -f         - View logs"
    echo "  docker compose restart         - Restart app"
    echo ""
    echo "  docker ps                      - List running containers"
    echo "  docker ps -a                   - List all containers"
    echo "  ls -la $DOCKER_ROOT/           - List all apps"
    echo ""
    echo "==============================================================================="
    echo "Next Steps:"
    echo "==============================================================================="
    echo "  1. Access Portainer and create your admin account"
    echo "  2. Set up your NFS mounts if using network storage"
    echo "  3. Create directories for your apps under /opt/docker/"
    echo "  4. Deploy your containers with docker-compose.yml files"
    echo ""
    echo "Example - Adding a new app:"
    echo "  mkdir -p /opt/docker/myapp"
    echo "  nano /opt/docker/myapp/docker-compose.yml"
    echo "  cd /opt/docker/myapp && docker compose up -d"
    echo ""
    echo "==============================================================================="
}

# Main execution
main() {
    echo ""
    echo "==============================================================================="
    echo "Docker, Docker Compose & Portainer Installation Script"
    echo "Enhanced for Proxmox VMs with NFS and QEMU Guest Agent Support"
    echo "Directory Structure: /opt/docker/<app>/"
    echo "==============================================================================="
    echo ""
    
    check_root
    detect_os
    update_system
    install_prerequisites
    install_nfs_client
    install_qemu_agent
    install_docker
    install_docker_compose
    test_docker
    create_docker_structure
    install_portainer
    install_watchtower
    add_user_to_docker_group
    create_readme
    # configure_firewall  # Uncomment if you want to configure firewall
    print_summary
    
    echo ""
    log_success "Setup complete! Your Docker environment is ready at $DOCKER_ROOT"
    echo ""
}

# Run main function
main "$@"