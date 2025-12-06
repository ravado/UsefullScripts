#!/bin/bash
#===============================================================================
# Script: install_and_configure_docker_vm.sh
# Description: Installs Docker, Docker Compose, and Portainer on a Debian/Ubuntu VM
# Usage: Run as root or with sudo: sudo bash install_and_configure_docker_vm.sh
# Tested on: Debian 11/12, Ubuntu 22.04/24.04
#===============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Create Docker network for Portainer
create_docker_network() {
    log_info "Creating Docker network for Portainer..."
    
    # Create network if it doesn't exist
    if ! docker network ls | grep -q "portainer_network"; then
        docker network create portainer_network
        log_success "Docker network 'portainer_network' created"
    else
        log_warn "Docker network 'portainer_network' already exists"
    fi
}

# Install Portainer
install_portainer() {
    log_info "Installing Portainer..."
    
    # Create volume for Portainer data
    docker volume create portainer_data
    
    # Stop and remove existing Portainer container if exists
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Run Portainer container
    docker run -d \
        -p 8000:8000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    # Verify Portainer is running
    sleep 5
    if docker ps | grep -q portainer; then
        log_success "Portainer installed and running"
    else
        log_error "Portainer installation failed"
        exit 1
    fi
}

# Add current user to docker group (optional)
add_user_to_docker_group() {
    if [ -n "$SUDO_USER" ]; then
        log_info "Adding user '$SUDO_USER' to docker group..."
        usermod -aG docker "$SUDO_USER"
        log_success "User '$SUDO_USER' added to docker group"
        log_warn "Please log out and log back in for group changes to take effect"
    fi
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
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}Installation Complete!${NC}"
    echo "==============================================================================="
    echo ""
    echo "Docker version:"
    docker --version
    echo ""
    echo "Docker Compose version:"
    docker compose version
    echo ""
    echo "Portainer is running on:"
    echo -e "  ${BLUE}HTTPS:${NC} https://<YOUR_VM_IP>:9443"
    echo ""
    echo "To get your VM's IP address, run:"
    echo "  ip addr show | grep 'inet ' | grep -v '127.0.0.1'"
    echo ""
    echo "==============================================================================="
    echo "Next Steps:"
    echo "==============================================================================="
    echo "1. Access Portainer at https://<YOUR_VM_IP>:9443"
    echo "2. Create your admin user on first login"
    echo "3. Start deploying containers!"
    echo ""
    echo "Useful Docker commands:"
    echo "  docker ps                    - List running containers"
    echo "  docker ps -a                 - List all containers"
    echo "  docker images                - List images"
    echo "  docker compose up -d         - Start services from docker-compose.yml"
    echo "  docker compose down          - Stop services"
    echo "  docker logs <container>      - View container logs"
    echo "==============================================================================="
}

# Main execution
main() {
    echo ""
    echo "==============================================================================="
    echo "Docker, Docker Compose & Portainer Installation Script"
    echo "==============================================================================="
    echo ""
    
    check_root
    detect_os
    update_system
    install_prerequisites
    install_docker
    install_docker_compose
    create_docker_network
    install_portainer
    add_user_to_docker_group
    # configure_firewall  # Uncomment if you want to configure firewall
    print_summary
}

# Run main function
main "$@"
