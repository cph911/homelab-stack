# 🏠 Homelab Stack

Lean, quick and easy home server installer for self-hosters who value simplicity over bloat.

Deploy n8n automation, Jellyfin media streaming, and essential services with automated SSL certificates, dynamic resource limits, and proper monitoring. Supports multiple server configurations (16GB to 64GB+ RAM) with intelligent resource allocation.


> ⚠️ IMPORTANT DISCLAIMER
>
> This installer has been reviewed and improved with bug fixes, DNS validation, error handling, and beginner-friendly features.
>
> Full credit goes to [Mahmoud Alkhatib](https://github.com/makhatib) for creating the [original AI-stack project](https://github.com/makhatib/AI-stack). This is a modified version optimized for homelab use with resource limits and essential services only.
>
> **Recommendations:**
> - Test in a non-production environment first
> - Ensure you have proper backups before deploying to production
> - Review the security section and secure the Traefik dashboard immediately after installation

-----

## 🎯 What You Get

### Core Services (Always Installed)

- n8n - Workflow automation platform (400+ integrations)
- Jellyfin - Media streaming server (your personal Netflix)
- Traefik - Reverse proxy with automatic SSL certificates
- PostgreSQL - Database backend for n8n

### Optional Services (You Choose)

- Portainer - Visual Docker container management
- Uptime Kuma - Service monitoring with alerts

### Optional Features (Post-Installation)

- **Telegram Health Bot** - Monitor and restart containers remotely via Telegram
  - **Separate installer** - Run `./install-telegram-bot.sh` after main installation
  - [Setup Guide](docs/TELEGRAM_BOT.md) - Interactive setup like the main installer
  - Check container health with `/health` command from your phone
  - Restart containers remotely with `/restart` command (shows interactive menu)
  - Runs 24/7 as systemd service with auto-restart
  - No internet exposure required, works on local network

### What's NOT Included (And Why)

- ❌ Supabase - Massive overhead (8+ containers), not needed for most homelabs
- ❌ Qdrant/Vector DBs - Only needed for AI/RAG workflows
- ❌ MinIO - S3 storage overkill, use local volumes
- ❌ Ollama - 8GB+ RAM hog, use API-based LLMs instead
- ❌ Grafana/Prometheus - Complex monitoring, Uptime Kuma is enough

-----

## 📊 Resource Usage

The installer now supports **dynamic resource limits** based on your server's RAM capacity. Choose the profile that matches your hardware:

### Profile 1: Conservative (16-32GB servers)
Total RAM: ~4.5GB (leaves plenty of headroom)

|Service    |RAM Limit|CPU Limit|Purpose        |
|-----------|---------|---------|---------------|
|Traefik    |256MB    |0.5 CPU  |SSL & routing  |
|PostgreSQL |512MB    |1.0 CPU  |Database       |
|n8n        |1GB      |1.0 CPU  |Automation     |
|Jellyfin   |2GB      |2.0 CPU  |Media streaming|
|Portainer  |256MB    |0.5 CPU  |Management     |
|Uptime Kuma|512MB    |0.5 CPU  |Monitoring     |

### Profile 2: Moderate (32-48GB servers)
Total RAM: ~7.5GB (balanced performance)

|Service    |RAM Limit|CPU Limit|Purpose        |
|-----------|---------|---------|---------------|
|Traefik    |512MB    |0.5 CPU  |SSL & routing  |
|PostgreSQL |1GB      |1.0 CPU  |Database       |
|n8n        |2GB      |2.0 CPU  |Automation     |
|Jellyfin   |4GB      |3.0 CPU  |Media streaming|
|Portainer  |512MB    |0.5 CPU  |Management     |
|Uptime Kuma|512MB    |0.5 CPU  |Monitoring     |

### Profile 3: Relaxed (48-64GB servers)
Total RAM: ~13GB (high performance)

|Service    |RAM Limit|CPU Limit|Purpose        |
|-----------|---------|---------|---------------|
|Traefik    |1GB      |1.0 CPU  |SSL & routing  |
|PostgreSQL |2GB      |2.0 CPU  |Database       |
|n8n        |4GB      |3.0 CPU  |Automation     |
|Jellyfin   |6GB      |4.0 CPU  |Media streaming|
|Portainer  |1GB      |0.5 CPU  |Management     |
|Uptime Kuma|1GB      |0.5 CPU  |Monitoring     |

### Profile 4: Minimal Limits (64GB+ servers)
Total RAM: ~22GB (maximum performance)

|Service    |RAM Limit|CPU Limit|Purpose        |
|-----------|---------|---------|---------------|
|Traefik    |2GB      |1.5 CPU  |SSL & routing  |
|PostgreSQL |4GB      |3.0 CPU  |Database       |
|n8n        |8GB      |4.0 CPU  |Automation     |
|Jellyfin   |8GB      |6.0 CPU  |Media streaming|
|Portainer  |2GB      |1.0 CPU  |Management     |
|Uptime Kuma|2GB      |1.0 CPU  |Monitoring     |

**Why resource limits matter:** Without them, one runaway process can kill your entire server. This is production-ready configuration, not a demo. The installer automatically detects your RAM and recommends the appropriate profile.

-----

## ⚡ Quick Start

### Prerequisites

#### System Requirements
- Ubuntu 20.04+ or Debian 11+ server
- **16GB+ RAM** (installer supports 16GB to 64GB+ with adaptive resource profiles)
- Domain name with DNS access
- Ports 80, 443, 8080 available

#### Required Tools

Before running the installer, ensure you have these tools installed:

**1. Essential Tools (git, curl, wget)**

For Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y git curl wget ca-certificates gnupg
```

**2. Docker 20.10+ and Docker Compose v2+**

Install Docker:
```bash
# Install Docker using official script
curl -fsSL https://get.docker.com | sh

# Add your user to docker group (no sudo needed)
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker

# Verify installation
docker --version
docker compose version
```

Or install manually if you prefer:
```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO- https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

**3. Optional Tools (helpful for troubleshooting)**

```bash
# DNS troubleshooting tools
sudo apt install -y dnsutils

# Network troubleshooting
sudo apt install -y net-tools
```

**Verify all prerequisites:**
```bash
# Check if all tools are installed
git --version
curl --version
docker --version
docker compose version

# Check available RAM
free -h

# Check open ports (should NOT show 80, 443, 8080 in use)
sudo netstat -tulpn | grep -E ':80|:443|:8080'
```

### Installation

**Step 1: Clone the repository**
```bash
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack
```

**Step 2: Make the installer executable**
```bash
chmod +x install-homelab.sh
```

**Step 3: Run the installer**
```bash
./install-homelab.sh
```

The installer will:

1. Check prerequisites (Docker, Docker Compose, OpenSSL)
1. Ask for your domain and email configuration
1. **Select resource profile** (detects RAM and offers 4 profiles)
1. Let you choose optional services (Portainer, Uptime Kuma)
1. Generate secure random passwords
1. **Validate DNS records** (with option to continue anyway)
1. Create Docker Compose configuration with media mounts
1. Pull images with automatic retry on failure
1. Start services with verification checks
1. Set up SSL certificates automatically

**Key Features:**
- ✅ **Dynamic resource limits** - Choose profile based on your RAM (16GB to 64GB+)
- ✅ Automatic DNS validation before installation
- ✅ Error recovery with exponential backoff retry
- ✅ Service health verification after startup
- ✅ Jellyfin media directories auto-mounted
- ✅ Hardware acceleration for Jellyfin (GPU support)
- ✅ Cleanup function for failed installations
- ✅ Secure credential handling (not printed to terminal)

Total time: 10-15 minutes

-----

## 🌐 DNS Configuration

CRITICAL: Configure DNS BEFORE running the installer.

### Find Your Server's Public IP

**For VPS/Cloud Servers:**
```bash
curl ifconfig.me
```

**For Home Servers:**
1. Find your public IP: Visit https://whatismyip.com from your browser
2. **Configure port forwarding on your router** (required for home networks):
   - Forward port **80** to your server's local IP (e.g., 192.168.1.100:80)
   - Forward port **443** to your server's local IP (e.g., 192.168.1.100:443)
   - Without port forwarding, Let's Encrypt SSL certificates will fail

### Configure DNS Records

You need A records pointing to your **public IP** (not local/private IPs like 192.168.x.x):

```
n8n.yourdomain.com        →  YOUR_PUBLIC_IP
jellyfin.yourdomain.com   →  YOUR_PUBLIC_IP
portainer.yourdomain.com  →  YOUR_PUBLIC_IP  (if installing)
uptime.yourdomain.com     →  YOUR_PUBLIC_IP  (if installing)
```

**Important for Cloudflare Users:**
- Turn OFF the orange cloud (Proxied status) - must be gray (DNS only)
- Let's Encrypt needs direct access to verify domain ownership
- Traefik handles SSL, not Cloudflare proxy

**Verify DNS propagation:**
```bash
# Install dig if needed
sudo apt install -y dnsutils

# Check DNS resolution
dig n8n.yourdomain.com +short
nslookup n8n.yourdomain.com
```

Wait 1-5 minutes for DNS to propagate before running the installer.

-----

## 🔐 Security Features

- ✅ Auto-generated passwords - 64-character secure keys for every service
- ✅ HTTPS enforced - HTTP automatically redirects to HTTPS
- ✅ Let’s Encrypt SSL - Free, automatic certificates
- ✅ Secure file permissions - `.env` set to 600 (owner read/write only)
- ✅ Resource isolation - Docker networks and proper limits
- ✅ No default passwords - Every installation is unique

All credentials saved in `.env` file (automatically secured).

-----

## 📁 Project Structure

After installation:

```text
homelab-stack/
├── install-homelab.sh          # Installer script
├── docker-compose.yml          # Generated service definitions
├── .env                        # Generated credentials & resource limits (DO NOT COMMIT)
├── INSTALLATION_INFO.txt       # Installation summary with resource profile
├── jellyfin-media/            # Media directories
│   ├── movies/
│   ├── tv/
│   └── music/
└── README.md
```

-----

## 🎬 Adding Media to Jellyfin

The installer automatically creates and mounts media directories. Media is mounted read-only for safety.

### Option 1: Use Included Directories (Recommended)

The installer creates these directories in your homelab-stack folder:
- `jellyfin-media/movies/` → mounted at `/media/movies` in Jellyfin
- `jellyfin-media/tv/` → mounted at `/media/tv` in Jellyfin
- `jellyfin-media/music/` → mounted at `/media/music` in Jellyfin

**Option A: Copy with cp:**

Copy movies:
```bash
cp -r /path/to/your/movies/* jellyfin-media/movies/
```

Copy TV shows:
```bash
cp -r /path/to/your/tv/* jellyfin-media/tv/
```

Copy music:
```bash
cp -r /path/to/your/music/* jellyfin-media/music/
```

**Option B: Use rsync for large transfers:**

Sync movies:
```bash
rsync -avh --progress /path/to/your/movies/ jellyfin-media/movies/
```

Sync TV shows:
```bash
rsync -avh --progress /path/to/your/tv/ jellyfin-media/tv/
```

Sync music:
```bash
rsync -avh --progress /path/to/your/music/ jellyfin-media/music/
```

### Option 2: Mount Your Own Directories

If you have existing media on another drive, edit `docker-compose.yml`:

```yaml
jellyfin:
  volumes:
    - jellyfin_config:/config
    - jellyfin_cache:/cache
    # Replace the default paths with your own:
    - /mnt/storage/movies:/media/movies:ro
    - /mnt/storage/tv:/media/tv:ro
    - /mnt/storage/music:/media/music:ro
```

Then restart: `docker compose restart jellyfin`

### Setting Up Libraries in Jellyfin

After adding media files:
1. Visit `https://jellyfin.yourdomain.com`
2. Go to Dashboard → Libraries → Add Media Library
3. Select library type (Movies, TV Shows, Music)
4. Add folder: `/media/movies`, `/media/tv`, or `/media/music`
5. Configure metadata settings and save

-----

## 🔧 Management Commands

### Service Control

**View all logs:**
```bash
docker compose logs -f
```

**View n8n logs:**
```bash
docker compose logs -f n8n
```

**View Jellyfin logs:**
```bash
docker compose logs -f jellyfin
```

**Restart all services:**
```bash
docker compose restart
```

**Restart specific service:**
```bash
docker compose restart n8n
```

**Stop all services:**
```bash
docker compose down
```

**Start all services:**
```bash
docker compose up -d
```

**Check service status:**
```bash
docker compose ps
```

**View resource usage:**
```bash
docker stats
```

### Updates

**Step 1: Pull latest images**
```bash
docker compose pull
```

**Step 2: Recreate containers with new images**
```bash
docker compose up -d
```

**Step 3: Check logs for any issues**
```bash
docker compose logs -f
```

-----

## 💾 Backup & Restore

### Quick Backup

**Backup configuration files:**
```bash
tar czf backup-config-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env INSTALLATION_INFO.txt
```

**Backup PostgreSQL database:**
```bash
docker compose exec postgres pg_dump -U n8n n8n > backup-n8n-$(date +%Y%m%d).sql
```

**Backup Docker volumes (n8n data):**
```bash
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/n8n-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Automated Backups

Create `/root/homelab-backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
STACK_DIR="/root/homelab-stack"

mkdir -p $BACKUP_DIR

# Backup database
docker compose -f $STACK_DIR/docker-compose.yml \
  exec -T postgres pg_dump -U n8n n8n > $BACKUP_DIR/n8n-$DATE.sql

# Backup configuration
tar czf $BACKUP_DIR/config-$DATE.tar.gz \
  -C $STACK_DIR docker-compose.yml .env

# Backup n8n workflows
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/n8n-data-$DATE.tar.gz -C /data .

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

Make it executable: `chmod +x /root/homelab-backup.sh`

Add to crontab (`crontab -e`):

```bash
# Daily backup at 2 AM
0 2 * * * /root/homelab-backup.sh >> /var/log/homelab-backup.log 2>&1
```

### Restore from Backup

**Restore configuration:**
```bash
tar xzf backup-config-YYYYMMDD.tar.gz
```

**Restore database:**
```bash
cat backup-n8n-YYYYMMDD.sql | docker compose exec -T postgres psql -U n8n n8n
```

**Restore n8n data:**
```bash
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/n8n-data-YYYYMMDD.tar.gz -C /data
```

-----

## 🔥 Troubleshooting

### Services Won't Start

**Check logs for errors:**
```bash
docker compose logs --tail=100
```

**Check if ports are already in use:**
```bash
sudo netstat -tulpn | grep -E ':80|:443'
```

**Restart Docker daemon:**
```bash
sudo systemctl restart docker
```

**Start services:**
```bash
docker compose up -d
```

### SSL Certificates Not Generating

**Check Traefik logs:**
```bash
docker compose logs traefik
```

**Verify DNS is propagated:**
```bash
nslookup n8n.yourdomain.com
```

**Check certificate status:**
```bash
curl -I https://n8n.yourdomain.com
```

**Note:** Wait 5-10 minutes - Let's Encrypt can be slow to issue certificates.

### n8n Database Connection Issues

**Check PostgreSQL is healthy:**
```bash
docker compose ps postgres
```

**Check PostgreSQL logs:**
```bash
docker compose logs postgres
```

**Verify credentials:**
```bash
cat .env | grep POSTGRES_PASSWORD
```

**Test database connection:**
```bash
docker compose exec postgres psql -U n8n -d n8n
```

### Jellyfin Transcoding Issues

The installer automatically configures hardware acceleration (`/dev/dri` device) for Intel/AMD GPUs.

**Check if hardware acceleration is available:**
```bash
docker compose exec jellyfin ls -la /dev/dri
```

**Check available resources:**
```bash
docker stats jellyfin
```

**Increase memory limit if needed:**

Edit `.env` file and adjust the Jellyfin memory limit:
```bash
# Change from current value to higher value
JELLYFIN_MEM=6G
```

Or edit `docker-compose.yml` directly and change: `memory: ${JELLYFIN_MEM}` → `memory: 6G`

**Restart Jellyfin:**
```bash
docker compose restart jellyfin
```

**Enable Hardware Acceleration in Jellyfin:**
1. Go to Dashboard → Playback
2. Select hardware acceleration type:
   - **VA-API** for Intel/AMD on Linux
   - **Video Acceleration API** for Intel Quick Sync
3. Enable hardware decoding for H264, HEVC, etc.
4. Save and test transcoding

**Note:** If `/dev/dri` doesn't exist, your system doesn't have GPU drivers installed or doesn't support hardware transcoding. Jellyfin will fall back to CPU transcoding (slower).

### Adjusting Resource Limits

If you need to change your resource profile after installation:

**Option 1: Edit .env file (Recommended)**

Edit the `.env` file and adjust the limits:
```bash
nano .env
```

Change the resource variables:
```bash
# Example: Increase n8n memory from 2G to 4G
N8N_MEM=4G
N8N_CPU=3.0

# Example: Increase Jellyfin memory from 4G to 6G
JELLYFIN_MEM=6G
JELLYFIN_CPU=4.0
```

**Option 2: Switch to different profile**

You can manually update all variables in `.env` to match a different profile (see Resource Usage section for all profiles).

**Apply changes:**
```bash
docker compose up -d
```

This will recreate containers with new limits without data loss.

### Out of Memory

**Check memory usage:**
```bash
free -h
```

**Monitor Docker container resources:**
```bash
docker stats
```

**Identify memory hog:**
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"
```

**Solution 1: Lower your resource profile**

If containers are hitting limits, you may have selected a profile that's too high for your server. Edit `.env` and reduce the limits.

**Solution 2: Add swap space (4GB):**

Create swap file:
```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
```

Format as swap:
```bash
sudo mkswap /swapfile
```

Enable swap:
```bash
sudo swapon /swapfile
```

-----

## 🚀 Next Steps After Installation

### 1. Configure n8n

- Visit `https://n8n.yourdomain.com`
- Create your owner account
- Build your first workflow
- Test webhook functionality

### 2. Set Up Jellyfin

- Visit `https://jellyfin.yourdomain.com`
- Complete initial setup wizard
- Add media libraries
- Configure transcoding settings
- Create user accounts

### 3. Configure Monitoring (if installed)

- Visit `https://uptime.yourdomain.com`
- Add monitors for all your services
- Set up notification channels (email, Slack, etc.)
- Configure status page

### 4. Secure Traefik Dashboard

The Traefik dashboard runs on port 8080 without authentication.

Options:

1. Firewall it: `sudo ufw allow from YOUR_HOME_IP to any port 8080`
1. Disable it: Remove `--api.dashboard=true` from docker-compose.yml
1. Add basic auth (advanced)

### 5. Optional: Set Up Telegram Health Bot

Monitor your containers remotely from your phone with a separate interactive installer:

**Run the bot installer:**
```bash
cd ~/homelab-stack
./install-telegram-bot.sh
```

The installer will:
- Prompt for your Telegram bot token (from @BotFather)
- Prompt for your Telegram user ID (from @userinfobot)
- Automatically set up and start the bot service

Then you can:
- Check container health with `/health` command from anywhere
- Restart containers with `/restart` command (interactive menu)
- Works without internet exposure (local network only)

See the [Telegram Bot Setup Guide](docs/TELEGRAM_BOT.md) for detailed instructions.

### 6. Set Up Backups

- Configure automated backup script (see Backup section)
- Test restore process
- Store backups off-site (cloud storage, external drive)

-----



## ⚠️ Important Notes

- **SSL certificates take 2-5 minutes to generate** - Be patient on first run
- **DNS must be configured BEFORE installation** - Let's Encrypt verifies ownership
- **Traefik dashboard (port 8080) is insecure** - Restrict access immediately
- **Resource limits are mandatory** - Don't remove them "for performance"
- **Choose the right resource profile** - Conservative for 16GB, Moderate for 32GB, Relaxed for 48GB, Minimal for 64GB+
- **Resource limits can be adjusted** - Edit `.env` file and run `docker compose up -d`
- **Backups are your responsibility** - Set them up on day one

-----

## 📚 Documentation Links

### Official Service Docs

- [n8n Documentation](https://docs.n8n.io)
- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma/wiki)

### Learning Resources

- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Let’s Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [n8n Workflow Templates](https://n8n.io/workflows/)
- [Jellyfin Optimization Guide](https://jellyfin.org/docs/general/administration/configuration/)

-----

## 🙏 Credits

Created for [hameed.tech](https://hameed.tech) - A practical home server setup for self-hosters who value working solutions over complexity.

Inspired by [makhatib/AI-stack](https://github.com/makhatib/AI-stack) but stripped down to essentials and optimized for  hardware constraints.

-----
