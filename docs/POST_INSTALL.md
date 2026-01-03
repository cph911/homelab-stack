# Post-Installation Guide

Congratulations! Your homelab stack is installed. This guide walks you through the essential next steps to get everything configured and running smoothly.

## Step 1: Verify Installation

### Check Service Status

```bash
# All services should show "Up"
docker compose ps

# Check auto-connector
sudo systemctl status cosmos-network-connector

# Verify network connectivity
docker network inspect homelab-shared
```

**Expected output:**
- All containers in "Up" state
- Auto-connector active (running)
- Multiple containers on homelab-shared network

### Test Web Access

Open your browser and test each service:

```
https://cosmos.your-domain.com       # Should load Cosmos dashboard
https://n8n.your-domain.com          # Should load n8n login
https://jellyfin.your-domain.com     # Should load Jellyfin setup
https://portainer.your-domain.com    # Should load Portainer (if installed)
https://uptime.your-domain.com       # Should load Uptime Kuma (if installed)
https://pihole.your-domain.com/admin # Should load Pi-hole (if installed)
```

**If services don't load:**
- Check DNS resolution: `nslookup cosmos.your-domain.com`
- Disable browser DNS-over-HTTPS (see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#dns-and-domain-issues))
- Check Cosmos logs: `docker logs cosmos`

## Step 2: Secure Cosmos

Cosmos is your entry point to everything. Secure it first.

### 1. Change Admin Password

1. Log into Cosmos: `https://cosmos.your-domain.com`
2. Default credentials: (set during installation)
3. Settings → Users → Change admin password
4. Use a strong, unique password (16+ characters)

### 2. Configure Authentication

**Option A: Basic Auth (Simple)**
1. Cosmos → URLs → Select a service
2. Security → Toggle "Require Authentication"
3. Select "Basic Auth"
4. Save

**Option B: OAuth (Better for multiple users)**
1. Cosmos → Settings → Authentication
2. Configure OAuth provider (Google, GitHub, etc.)
3. Apply to all routes

### 3. Review Public Routes

1. Cosmos → URLs → Review all routes
2. Ensure nothing sensitive is set to "Public"
3. Example: Don't make Portainer or n8n public!

**Safe to make public (with auth):**
- Jellyfin (media streaming)
- Uptime Kuma (status page)

**NEVER public:**
- Portainer (Docker control)
- n8n (workflow automation)
- Cosmos itself (system control)
- Pi-hole (DNS control)

## Step 3: Configure n8n

n8n is your automation engine. Set it up properly to avoid issues.

### 1. Initial Setup

1. Visit `https://n8n.your-domain.com`
2. Create owner account (use strong password)
3. Set up email (optional but recommended for notifications)

### 2. Configure Webhook URL

n8n needs to know its public URL for webhooks to work.

1. n8n → Settings → General
2. Webhook URL: `https://n8n.your-domain.com/`
3. Ensure it uses HTTPS (not HTTP)
4. Save

### 3. Test Database Connection

```bash
# n8n should be connected to PostgreSQL
docker logs n8n | grep postgres

# Should see: "Successfully connected to database"
```

If n8n can't connect to postgres:
```bash
# Check if both are on homelab-shared
docker network inspect homelab-shared | grep -E "n8n|postgres"

# Connect if missing
docker network connect homelab-shared n8n
docker network connect homelab-shared postgres

# Restart n8n
docker restart n8n
```

### 4. Secure API Access

1. n8n → Settings → API
2. Generate API key
3. Store securely (password manager)
4. Use for external integrations only

## Step 4: Set Up Jellyfin

Jellyfin is your media server. Initial setup is crucial.

### 1. Run Initial Wizard

1. Visit `https://jellyfin.your-domain.com`
2. Select language
3. Create admin account (strong password!)
4. Set up media libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
   - Music: `/media/music`

### 2. Enable Hardware Transcoding

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **VAAPI** (or appropriate for your GPU)
3. Enable hardware decoding for:
   - H264
   - HEVC
   - VP9 (if supported)
4. Save

**Test transcoding:**
- Play a 4K video
- Check CPU usage (should be low if GPU is working)
- Check Jellyfin logs: `docker logs jellyfin | grep -i vaapi`

### 3. Add Media

```bash
# Navigate to media directory
cd jellyfin-media

# Organize as follows:
# movies/Movie Name (Year)/Movie Name (Year).mkv
# tv/Show Name/Season 01/Show Name - S01E01.mkv
# music/Artist/Album/01 - Track Name.mp3

# Example:
# jellyfin-media/
# ├── movies/
# │   ├── Inception (2010)/
# │   │   └── Inception (2010).mkv
# │   └── The Matrix (1999)/
# │       └── The Matrix (1999).mkv
# └── tv/
#     └── Breaking Bad/
#         ├── Season 01/
#         │   ├── Breaking Bad - S01E01.mkv
#         │   └── Breaking Bad - S01E02.mkv
#         └── Season 02/
#             └── ...
```

### 4. Scan Libraries

1. Jellyfin → Dashboard → Libraries
2. Select library → Scan Library
3. Wait for metadata to download

## Step 5: Configure Optional Services

### Portainer (if installed)

1. Visit `https://portainer.your-domain.com`
2. Create admin account
3. Select "Docker" environment
4. Endpoint URL: `/var/run/docker.sock` (already configured)

**Recommended settings:**
- Enable "Use SSL" for remote connections
- Set session timeout (15 minutes)
- Disable "Allow collection of anonymous statistics"

### Uptime Kuma (if installed)

1. Visit `https://uptime.your-domain.com`
2. Create admin account
3. Add monitors for your services:
   - Type: HTTP(s)
   - URL: `https://jellyfin.your-domain.com`
   - Heartbeat interval: 60 seconds

**Services to monitor:**
- Cosmos
- n8n
- Jellyfin
- Any public-facing services

### Pi-hole (if installed)

1. Visit `https://pihole.your-domain.com/admin`
2. Login with password from installation
3. Add blocklists (Settings → Blocklists):
   ```
   https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
   https://v.firebog.net/hosts/AdguardDNS.txt
   https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
   ```
4. Tools → Update Gravity

**Configure devices to use Pi-hole:**
- Option A: Set DNS in router DHCP (recommended)
- Option B: Manually set DNS on each device to server IP

## Step 6: Set Up Remote Access (Optional)

Choose **one** method based on your needs.

### Option A: Cloudflare Tunnel (Recommended for public sharing)

**Pros:**
- No open ports on router
- DDoS protection
- Free tier available
- Can add Cloudflare Access for zero-trust auth

**Setup:**
1. Create Cloudflare account
2. Add your domain to Cloudflare
3. Cosmos → Settings → Cloudflare
4. Follow Cloudflare Tunnel setup wizard
5. Create routes for services you want accessible remotely

**Security:**
- Enable Cloudflare Access for sensitive services
- Use IP allowlisting (whitelist your work/home IPs)
- Enable rate limiting

### Option B: Tailscale VPN (Recommended for personal use)

**Pros:**
- End-to-end encrypted
- No traffic through third parties
- Peer-to-peer when possible
- Zero-trust by default

**Setup:**
1. Create Tailscale account
2. Install Tailscale on server:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
3. Install Tailscale on client devices
4. Access services via Tailscale IP: `https://100.x.x.x`

**Security:**
- Use ACLs to restrict access
- Enable MFA on Tailscale account
- Regularly review connected devices

### Option C: No Remote Access (Most Secure)

Keep everything LAN-only:
- Highest security
- No attack surface from internet
- Access via VPN when traveling (Tailscale without MagicDNS)

## Step 7: Configure Backups

**What to backup:**

```
Priority 1 (Daily):
- Docker volumes: /var/lib/docker/volumes/homelab-stack_*
- Cosmos config: ./cosmos-config/
- Environment: ./.env
- docker-compose.yml

Priority 2 (Weekly):
- Jellyfin metadata: homelab-stack_jellyfin_config volume
- n8n workflows: homelab-stack_n8n_data volume
- Auto-connector logs: /var/log/cosmos-network-connector.log

Priority 3 (Optional):
- Media files: ./jellyfin-media/ (if not already backed up elsewhere)
```

### Backup Script Example

```bash
#!/bin/bash
# Save as: /usr/local/bin/backup-homelab.sh

BACKUP_DIR="/mnt/backup/homelab"
DATE=$(date +%Y%m%d)

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Backup volumes
sudo cp -r /var/lib/docker/volumes/homelab-stack_* "$BACKUP_DIR/$DATE/"

# Backup configs
cp -r cosmos-config .env docker-compose.yml "$BACKUP_DIR/$DATE/"

# Backup logs
sudo cp /var/log/cosmos-network-connector.log "$BACKUP_DIR/$DATE/"

# Compress
cd "$BACKUP_DIR"
tar -czf "homelab-$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

# Keep only last 7 days
find "$BACKUP_DIR" -name "homelab-*.tar.gz" -mtime +7 -delete

echo "Backup completed: homelab-$DATE.tar.gz"
```

**Automate with cron:**
```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * /usr/local/bin/backup-homelab.sh
```

**Test restore:**
```bash
# Extract backup
tar -xzf /mnt/backup/homelab/homelab-20260103.tar.gz

# Stop services
docker compose down

# Restore volumes
sudo cp -r 20260103/homelab-stack_* /var/lib/docker/volumes/

# Restore configs
cp -r 20260103/cosmos-config ./
cp 20260103/.env ./

# Restart services
docker compose up -d
```

## Step 8: Enable Monitoring

### System Monitoring

**Install monitoring tools:**
```bash
sudo apt update
sudo apt install -y htop iotop nethogs ncdu
```

**Create monitoring script:**
```bash
#!/bin/bash
# Save as: /usr/local/bin/check-homelab.sh

echo "=== System Resources ==="
free -h
df -h | grep -E "/$|/var"

echo -e "\n=== Docker Status ==="
docker compose ps

echo -e "\n=== Container Resources ==="
docker stats --no-stream

echo -e "\n=== Network Status ==="
docker network inspect homelab-shared | grep -c "Containers"

echo -e "\n=== Auto-Connector Status ==="
sudo systemctl is-active cosmos-network-connector
sudo tail -5 /var/log/cosmos-network-connector.log
```

**Run weekly:**
```bash
chmod +x /usr/local/bin/check-homelab.sh
./check-homelab.sh
```

### Uptime Kuma Configuration

If you installed Uptime Kuma, set up comprehensive monitoring:

**Add monitors for:**
1. All web services (HTTP check)
2. Docker daemon (Port 2375 if exposed, or use Push monitor)
3. System resources (use Docker monitor type)
4. Database (PostgreSQL port check)

**Set up notifications:**
1. Uptime Kuma → Settings → Notifications
2. Add notification channels:
   - Email (SMTP)
   - Telegram/Discord/Slack (webhooks)
   - Pushover/Gotify (mobile push)
3. Set notification rules (when to alert)

## Step 9: Security Hardening

### 1. Change All Default Passwords

- [ ] Cosmos admin
- [ ] n8n owner
- [ ] Jellyfin admin
- [ ] Portainer admin (if installed)
- [ ] Uptime Kuma admin (if installed)
- [ ] Pi-hole admin (if installed)

### 2. Enable MFA Where Possible

- [ ] Cosmos (Settings → Security)
- [ ] Portainer (Settings → Authentication)
- [ ] n8n (via OAuth if configured)

### 3. Configure Firewall

```bash
# Install UFW
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if needed)
sudo ufw allow 22/tcp

# Allow from LAN only (adjust subnet)
sudo ufw allow from 192.168.1.0/24

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### 4. Review Cosmos Routes

1. Cosmos → URLs
2. For each route, ensure:
   - Authentication is enabled (unless intentionally public)
   - SSL is enforced
   - Appropriate users have access

### 5. Disable Unused Services

```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Comment out services you don't need
# For example, if you don't use Jellyfin:
#  jellyfin:
#    image: jellyfin/jellyfin:latest
#    ...

# Restart stack
docker compose up -d
```

## Step 10: Test Everything

### Service Availability

- [ ] Can access all services via web browser
- [ ] DNS resolution works from all devices
- [ ] SSL certificates are valid (or expected warnings for self-signed)
- [ ] Auto-connector detects new containers

### Inter-Service Communication

Test container-to-container communication:

```bash
# From n8n to postgres
docker exec n8n ping postgres

# From any Cosmos app to docker-compose services
docker exec Notifiarr ping qbittorrent
```

Should respond without errors.

### Resource Usage

```bash
# Check if services are within limits
docker stats

# Check system load
uptime
free -h
df -h
```

Ensure no services are constantly hitting memory limits.

### Backup and Restore

```bash
# Run backup script
/usr/local/bin/backup-homelab.sh

# Verify backup exists
ls -lh /mnt/backup/homelab/

# Test restore on a non-production system (if possible)
```

## Step 11: Document Your Setup

Create a personal documentation file with:

**Access Details:**
```
Cosmos Admin: https://cosmos.hameed.tech (admin / ********)
n8n: https://n8n.hameed.tech (owner@email.com / ********)
Jellyfin: https://jellyfin.hameed.tech (admin / ********)
...

Server IP: 192.168.1.69
Domain: hameed.tech
DNS: Pi-hole at 192.168.1.69
```

**Customizations:**
- List of installed Cosmos apps
- Custom routes you created
- Workflow automation you set up
- Special firewall rules

**Maintenance Schedule:**
- Backup schedule (daily 3 AM)
- Update schedule (monthly, first Saturday)
- Monitoring review (weekly)

Store this document securely (password manager, encrypted file).

## Next Steps

You're now running a production-ready homelab! Here's what to explore:

### Expand with Cosmos Market

Install additional apps from Cosmos market:
- **Sonarr/Radarr** - Automatic TV show and movie downloads
- **qBittorrent** - Torrent client
- **Nextcloud** - Personal cloud storage
- **Vaultwarden** - Password manager
- **Home Assistant** - Smart home automation
- **Bookstack** - Documentation wiki

All will automatically join `homelab-shared` network.

### Learn n8n Workflows

Create useful automations:
- Monitor disk space → alert on Telegram
- New Jellyfin episode → notify Discord
- RSS feed → download via qBittorrent
- GitHub release → update docker containers

### Optimize Performance

- Move Docker volumes to SSD
- Set up reverse proxy caching
- Configure CDN for media delivery
- Implement log rotation

### Enhance Security

- Set up intrusion detection (Fail2ban)
- Implement network segmentation (VLANs)
- Add web application firewall (Cloudflare WAF)
- Set up security monitoring (Wazuh)

## Common Post-Install Issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

**Quick fixes:**

**Can't access services via domain:**
- Disable browser DNS-over-HTTPS
- Clear DNS cache
- Check Pi-hole is running

**Service won't start:**
- Check logs: `docker logs service_name`
- Check resources: `docker stats`
- Check dependencies: `docker compose ps`

**Inter-service communication broken:**
- Check network: `docker network inspect homelab-shared`
- Connect manually: `docker network connect homelab-shared service_name`
- Restart auto-connector: `sudo systemctl restart cosmos-network-connector`

## Getting Help

If you encounter issues:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Check [GitHub Issues](https://github.com/cph911/homelab-stack/issues)
3. Review service logs: `docker compose logs service_name`
4. Open a detailed GitHub issue with:
   - System info (`uname -a`, `docker --version`)
   - Service status (`docker compose ps`)
   - Relevant logs
   - Steps to reproduce

## Further Reading

- [ARCHITECTURE.md](ARCHITECTURE.md) - How the stack works
- [SECURITY.md](SECURITY.md) - Security model and best practices
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

Enjoy your homelab! 🚀
