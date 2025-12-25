# 🏠 Homelab Stack

Lean, production-ready home server installer for self-hosters who value simplicity over bloat.

Deploy n8n automation, Jellyfin media streaming, and essential services with automated SSL certificates, resource limits, and proper monitoring. Built for real hardware constraints (16-32GB RAM).


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

### What’s NOT Included (And Why)

- ❌ Supabase - Massive overhead (8+ containers), not needed for most homelabs
- ❌ Qdrant/Vector DBs - Only needed for AI/RAG workflows
- ❌ MinIO - S3 storage overkill, use local volumes
- ❌ Ollama - 8GB+ RAM hog, use API-based LLMs instead
- ❌ Grafana/Prometheus - Complex monitoring, Uptime Kuma is enough

-----

## 📊 Resource Usage

Total RAM: ~7-8GB (leaves headroom on 16GB servers)

|Service    |RAM Limit|CPU Limit|Purpose        |
|-----------|---------|---------|---------------|
|Traefik    |256MB    |0.5 CPU  |SSL & routing  |
|PostgreSQL |512MB    |1.0 CPU  |Database       |
|n8n        |2GB      |2.0 CPU  |Automation     |
|Jellyfin   |4GB      |2.0 CPU  |Media streaming|
|Portainer  |256MB    |0.5 CPU  |Management     |
|Uptime Kuma|512MB    |0.5 CPU  |Monitoring     |

Why resource limits matter: Without them, one runaway process can kill your entire server. This is production-ready configuration, not a demo.

-----

## ⚡ Quick Start

### Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- 16GB+ RAM (32GB recommended for heavy transcoding)
- Docker 20.10+ and Docker Compose v2+
- Domain name with DNS access
- Ports 80, 443, 8080 available

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
1. Let you choose optional services (Portainer, Uptime Kuma)
1. Generate secure random passwords
1. **Validate DNS records** (with option to continue anyway)
1. Create Docker Compose configuration with media mounts
1. Pull images with automatic retry on failure
1. Start services with verification checks
1. Set up SSL certificates automatically

**New Features:**
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

You need A records pointing to your server IP:

```
n8n.yourdomain.com        →  YOUR_SERVER_IP
jellyfin.yourdomain.com   →  YOUR_SERVER_IP
portainer.yourdomain.com  →  YOUR_SERVER_IP  (if installing)
uptime.yourdomain.com     →  YOUR_SERVER_IP  (if installing)
```

Verify with: `nslookup n8n.yourdomain.com`

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
├── .env                        # Generated credentials (DO NOT COMMIT)
├── INSTALLATION_INFO.txt       # Installation summary
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
```bash
cp -r /path/to/your/movies/* jellyfin-media/movies/
cp -r /path/to/your/tv/* jellyfin-media/tv/
cp -r /path/to/your/music/* jellyfin-media/music/
```

**Option B: Use rsync for large transfers:**
```bash
rsync -avh --progress /path/to/your/movies/ jellyfin-media/movies/
rsync -avh --progress /path/to/your/tv/ jellyfin-media/tv/
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

**View specific service logs:**
```bash
docker compose logs -f n8n
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

**Restart Docker daemon and services:**
```bash
sudo systemctl restart docker
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

Edit `docker-compose.yml` and change: `memory: 4G` → `memory: 6G`

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

**Temporary fix: Add swap space (4GB):**
```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo mkswap /swapfile
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

### 5. Set Up Backups

- Configure automated backup script (see Backup section)
- Test restore process
- Store backups off-site (cloud storage, external drive)

-----



## ⚠️ Important Notes

- SSL certificates take 2-5 minutes to generate - Be patient on first run
- DNS must be configured BEFORE installation - Let’s Encrypt verifies ownership
- Traefik dashboard (port 8080) is insecure - Restrict access immediately
- Resource limits are mandatory - Don’t remove them “for performance”
- Backups are your responsibility - Set them up on day one

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
