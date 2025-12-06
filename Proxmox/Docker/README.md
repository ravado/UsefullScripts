# Docker VM Setup Guide

## What are Docker Volumes?

Docker volumes are the preferred way to persist data generated and used by Docker containers. When a container is deleted, all data inside it is lost - volumes solve this problem.

### Types of Storage in Docker:

| Type | Description | Use Case |
|------|-------------|----------|
| **Named Volumes** | Managed by Docker, stored in `/var/lib/docker/volumes/` | Simple persistence, databases |
| **Bind Mounts** | Maps a host directory to container directory | When you need direct access to files |
| **tmpfs Mounts** | Stored in host memory only | Sensitive data, temporary files |

### Volume Examples:

```bash
# Named volume (Docker manages location)
docker run -v mydata:/app/data myimage

# Bind mount (you control exact location)
docker run -v /opt/docker/myapp/data:/app/data myimage
```

---

## 📁 Best Practices for Organizing Docker Data

### Recommended Directory Structure:

```
/opt/docker/                     # Main Docker data directory
├── portainer/
│   └── data/                    # Portainer configuration
├── booklore/
│   ├── config/                  # App configuration files
│   ├── data/                    # App database/data
│   └── books/                   # User uploaded content
├── nextcloud/
│   ├── config/
│   ├── data/
│   └── html/
└── plex/
    ├── config/
    └── transcode/
```

### Why `/opt/docker/`?

1. **Easy backups** - One directory to backup
2. **Clear organization** - Each service has its own folder
3. **Survives updates** - Data persists when containers are rebuilt
4. **Easy migration** - Simple to move to another server
5. **Permission management** - Can set proper ownership per service

---

## 🛠️ Setting Up the Directory Structure

Run these commands on your Docker VM:

```bash
# Create main docker data directory
sudo mkdir -p /opt/docker

# Set ownership (replace 1000:1000 with your user's UID:GID)
sudo chown -R 1000:1000 /opt/docker

# Create directories for specific services
sudo mkdir -p /opt/docker/{portainer,booklore,homepage,nginx}
```

---

## 📚 Example: Setting Up Booklore

[Booklore](https://github.com/booklore/booklore) is a self-hosted ebook management system.

### 1. Create directories:

```bash
sudo mkdir -p /opt/docker/booklore/{config,data,books}
sudo chown -R 1000:1000 /opt/docker/booklore
```

### 2. Create docker-compose.yml:

Create file at `/opt/docker/booklore/docker-compose.yml`:

```yaml
version: "3.8"

services:
  booklore:
    image: ghcr.io/booklore/booklore:latest
    container_name: booklore
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      # Configuration files
      - /opt/docker/booklore/config:/config
      # Application data (database, etc.)
      - /opt/docker/booklore/data:/data
      # Your book library
      - /opt/docker/booklore/books:/books
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Kiev
```

### 3. Start the container:

```bash
cd /opt/docker/booklore
docker compose up -d
```

### 4. Access Booklore:

Open `http://<YOUR_VM_IP>:8080` in your browser.

---

## 🔄 Migration/Backup Strategy

### Backup all Docker data:

```bash
# Stop all containers first
docker compose down  # (in each service directory)

# Backup entire docker data directory
sudo tar -czvf docker-backup-$(date +%Y%m%d).tar.gz /opt/docker/
```

### Restore on new server:

```bash
# Extract backup
sudo tar -xzvf docker-backup-20240612.tar.gz -C /

# Start containers
cd /opt/docker/booklore && docker compose up -d
```

---

## 📊 Named Volumes vs Bind Mounts

### When to use Named Volumes:

- ✅ Simple applications
- ✅ Databases (PostgreSQL, MySQL, etc.)
- ✅ When you don't need direct file access
- ✅ Internal application data

```yaml
volumes:
  - portainer_data:/data  # Named volume
```

### When to use Bind Mounts:

- ✅ Media files (photos, videos, books)
- ✅ Configuration files you want to edit
- ✅ Log files you need to access
- ✅ Shared data between containers
- ✅ Data you want to backup easily

```yaml
volumes:
  - /opt/docker/booklore/books:/books  # Bind mount
```

---

## 🏠 Complete Example: Multi-Service Setup

Here's an example `/opt/docker/docker-compose.yml` for managing multiple services:

```yaml
version: "3.8"

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/docker/portainer/data:/data

  booklore:
    image: ghcr.io/booklore/booklore:latest
    container_name: booklore
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /opt/docker/booklore/config:/config
      - /opt/docker/booklore/data:/data
      - /opt/docker/booklore/books:/books
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Kiev

  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - /opt/docker/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=1000
      - PGID=1000
```

---

## 📝 Useful Commands

```bash
# List all volumes
docker volume ls

# Inspect a volume (see where it's stored)
docker volume inspect portainer_data

# Remove unused volumes (careful!)
docker volume prune

# Create a named volume
docker volume create my_volume

# View disk usage
docker system df

# See what's inside a volume
sudo ls -la /var/lib/docker/volumes/<volume_name>/_data/
```

---

## 🔐 Permissions Tips

Most containers run as a specific user (often UID 1000). Match this:

```bash
# Check your user's UID and GID
id

# Set correct ownership
sudo chown -R 1000:1000 /opt/docker/booklore/

# For some apps that need root
sudo chown -R root:root /opt/docker/portainer/
```

---

## Summary

| Approach | Location | Best For |
|----------|----------|----------|
| Named Volumes | `/var/lib/docker/volumes/` | Databases, internal data |
| Bind Mounts | `/opt/docker/<service>/` | Media, configs, accessible data |

**Recommendation**: Use bind mounts to `/opt/docker/<service>/` for most home server applications - it makes backups and management much easier!
