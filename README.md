# Homelab Stack

A complete homelab setup with media streaming, automation, and monitoring - all behind a reverse proxy with automatic SSL. One installer script handles everything.

## What's Included

### Core Services
- **Cosmos** - Reverse proxy with automatic SSL/HTTPS, authentication, and service discovery
- **Jellyfin** - Media server for movies, TV shows, music, and photos
- **n8n** - Workflow automation with 400+ integrations (think Zapier/Make but self-hosted)
- **PostgreSQL** - Database backend for n8n workflows
- **Cloudflare Tunnel** - Secure remote access without exposing ports or requiring static IP

### Optional Services (installer lets you choose)
- **Portainer** - Docker container management UI
- **Uptime Kuma** - Service monitoring with notifications
- **Pi-hole** - Network-wide ad blocking and DNS management

### What the Stack Provides
- Automatic HTTPS with SSL certificates for all services
- Unified authentication through Cosmos
- Smart Docker networking (services can communicate internally)
- RAM-aware resource limits based on your hardware
- Systemd integration for auto-start on boot
- Organized media library structure
- Health monitoring and restart policies

## Quick Start

```bash
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack
chmod +x install-homelab.sh
./install-homelab.sh
```

The installer will:
1. Check system requirements (Ubuntu/Debian, RAM, Docker)
2. Ask for your domain name
3. Let you choose optional services
4. Auto-detect RAM and configure limits
5. Generate docker-compose.yml with smart defaults
6. Create directory structure for media and config
7. Start all services with proper networking

**Installation time:** ~10 minutes depending on your internet connection

## After Installation

### Access Your Services

All services are accessible via Cosmos dashboard:
- **Dashboard:** `https://cosmos.your-domain.com`
- **Jellyfin:** `https://jellyfin.your-domain.com`
- **n8n:** `https://n8n.your-domain.com`
- **Portainer:** `https://portainer.your-domain.com` (if installed)
- **Uptime Kuma:** `https://uptime.your-domain.com` (if installed)

### Initial Setup

1. **Cosmos**: Create admin account and configure authentication
2. **Jellyfin**: Set up libraries pointing to `/media/movies`, `/media/tv`, etc.
3. **n8n**: Connect to included PostgreSQL database
4. **Add Media**: Upload to `jellyfin-media/movies/` and `jellyfin-media/tv/`

### Directory Structure

```
homelab-stack/
├── docker-compose.yml          # Generated with your settings
├── jellyfin-media/            # Your media files
│   ├── movies/
│   ├── tv/
│   ├── music/
│   └── photos/
├── n8n-data/                  # n8n workflows and credentials
├── postgres-data/             # Database storage
└── cosmos-data/               # Reverse proxy config
```

## Common Operations

### Managing Services

```bash
# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f jellyfin

# Restart all services
docker compose restart

# Restart specific service
docker compose restart jellyfin

# Stop everything
docker compose down

# Start everything
docker compose up -d

# Update all services to latest versions
docker compose pull
docker compose up -d
```

### Monitoring

```bash
# Check service status
docker compose ps

# Check resource usage
docker stats

# View container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Architecture

### Network Design
- **cosmos-network** (bridge): Main network for reverse proxy and services
- **n8n-network** (internal): Isolated network for n8n ↔ PostgreSQL communication
- All services connect through Cosmos for external access
- Internal service-to-service communication via Docker DNS

### SSL/HTTPS
- Cosmos handles SSL termination for all services
- Automatic certificate management
- HTTP → HTTPS redirection
- No manual certificate configuration needed

### Resource Management
- RAM limits auto-configured based on system memory
- Smart defaults: 2GB for Jellyfin, 1GB for n8n, 512MB for Cosmos
- Adjustable in docker-compose.yml if needed
- Restart policies ensure services auto-recover from crashes

## Remote Access Options

### Option 1: Tailscale (Recommended)
- Zero-trust VPN for secure remote access
- No port forwarding needed
- No static IP required
- Works with all services including LAN devices (Home Assistant, etc.)
- See [Tailscale Setup Guide](docs/advanced/TAILSCALE_SETUP.md)

### Option 2: Cloudflare Tunnel
- Included in stack (optional during install)
- Exposes services publicly without port forwarding
- Free tier available
- Good for sharing with family/friends

## Extras

### Telegram Health Bot
Monitor and control your homelab from Telegram:
- Check container health status
- Restart services via bot commands
- Automatic startup notifications (perfect for Wake-on-LAN)

```bash
./install-telegram-bot.sh
```

See [Telegram Bot Setup](docs/TELEGRAM_BOT.md) for details.

### Wake-on-LAN Support
All services configured with `restart: unless-stopped`:
- Boot server remotely with WoL
- Services auto-start when server powers on
- Telegram bot sends notification when ready
- No manual intervention needed

## Requirements

- **OS:** Ubuntu 20.04+, Debian 11+, or any systemd-based Linux
- **RAM:** 16GB minimum, 32GB+ recommended for smooth operation
- **Storage:** 50GB+ free space (more for media libraries)
- **Docker:** Version 20.10+ with Docker Compose V2
- **Network:** Local network access, domain name (can be .local for LAN-only)

**Don't have Docker?** The installer checks and guides you through installation.

## Troubleshooting

### Quick Fixes
- **Services not accessible?** Check firewall: `sudo ufw allow 80,443/tcp`
- **SSL errors?** Verify domain DNS points to server IP
- **Jellyfin can't find media?** Check file permissions in `jellyfin-media/`
- **High RAM usage?** Adjust limits in docker-compose.yml

### Common Issues
See [Common Issues Guide](docs/COMMON_ISSUES.md) for detailed troubleshooting.

### Advanced Documentation
- [Architecture Deep Dive](docs/advanced/ARCHITECTURE.md)
- [Security Hardening](docs/advanced/SECURITY.md)
- [Performance Tuning](docs/advanced/TROUBLESHOOTING.md)
- [Post-Install Configuration](docs/advanced/POST_INSTALL.md)

## Contributing

Contributions welcome! This project aims to stay beginner-friendly while remaining powerful.

**Guidelines:**
- Keep the installer simple and interactive
- Maintain smart defaults that work for most setups
- Document advanced features separately
- Test on real hardware before submitting PRs

## Credits

Built by [Hameed](https://hameed.tech) for the homelab community.

Inspired by [makhatib/AI-stack](https://github.com/makhatib/AI-stack) - adapted for general homelab use with focus on simplicity and reliability.

## License

MIT License - Use however you want, commercial or personal.

---

**Need more control?** Check the [advanced documentation](docs/advanced/) for deep dives into security, customization, and architecture.
