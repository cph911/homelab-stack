# Complete Server Setup Guide

**Fresh server to fully working homelab in under 30 minutes.**

This guide assumes you're starting from a fresh Ubuntu/Debian server and want Tailscale for remote access from day one.

---

## Part 1: Pre-Installation (5 minutes)

### Step 1: Connect to Your Server

```bash
# From your laptop
ssh user@your-server-ip
```

### Step 2: Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 3: Install Required Tools

```bash
# Install essential tools
sudo apt install -y git curl wget ca-certificates gnupg

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to docker group (no sudo needed)
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Verify Docker works
docker --version
docker compose version
```

Expected output:
```
Docker version 24.x.x
Docker Compose version v2.x.x
```

---

## Part 2: Tailscale Setup (5 minutes)

**Do this BEFORE installing the homelab stack.**

### Step 1: Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Step 2: Connect to Tailscale

```bash
sudo tailscale up
```

This will print a URL. Open it in your browser and authenticate.

### Step 3: Get Your Tailscale IP

```bash
tailscale ip -4
```

Example output: `100.64.1.5`

**Save this IP - you'll use it to access your services remotely.**

### Step 4: Set Tailscale Hostname (Optional but Recommended)

```bash
# Set a friendly hostname
sudo tailscale set --hostname homelab
```

Now you can access your server as `homelab` instead of the IP.

### Step 5: Install Tailscale on Your Devices

**On your laptop/phone:**
1. Install Tailscale app
2. Sign in with same account
3. You can now access server via `100.64.1.5` or `homelab`

---

## Part 3: Install Homelab Stack (10 minutes)

### Step 1: Clone Repository

```bash
cd ~
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack
```

### Step 2: Run Installer

```bash
chmod +x install-homelab.sh
./install-homelab.sh
```

### Step 3: Answer the Prompts

**Domain Name:**
```
Enter your domain (e.g., hameed.tech): homelab.local
```

Use `homelab.local` or any `.local` domain for local/Tailscale-only access.

**Email (for SSL):**
```
Enter email for SSL certificates: your@email.com
```

**Resource Profile:**
```
Detected: 32GB RAM
Select profile:
1) Conservative (16-32GB)
2) Moderate (32-48GB)    <- Select this
3) Relaxed (48-64GB)
4) Minimal (64GB+)
```

Pick based on your RAM.

**Optional Services:**
```
Install Portainer? (y/n): y
Install Uptime Kuma? (y/n): y
Install Pi-hole? (y/n): y
```

I recommend **yes** to all.

**Remote Access Method:**
```
Select remote access:
1) None (local only)
2) Tailscale
3) Cloudflare Tunnel

Choice: 2    <- Select Tailscale
```

**Timezone:**
```
Enter timezone (default: America/New_York):
```

Press Enter for default or enter yours.

### Step 4: Wait for Installation

The script will:
- Create docker-compose.yml
- Pull all images
- Start services
- Set up auto-connector
- Create media folders

Takes ~10 minutes depending on internet speed.

---

## Part 4: DNS Setup for Tailscale (2 minutes)

Since you're using Tailscale, you need to configure DNS so domains work.

### Option A: Pi-hole (Recommended if you installed it)

**1. Configure Pi-hole DNS in Tailscale:**

```bash
# Get Pi-hole container IP on Tailscale
docker inspect pihole | grep IPAddress
```

**2. Set Tailscale to use Pi-hole:**

Visit https://login.tailscale.com/admin/dns and:
- Add nameserver: `100.64.1.5` (your Tailscale IP)
- Or the Pi-hole container IP

**3. Add wildcard DNS in Pi-hole:**

```bash
# Add wildcard DNS entry
echo "address=/homelab.local/100.64.1.5" | sudo tee -a /etc/dnsmasq.d/02-homelab.conf

# Restart Pi-hole
docker restart pihole
```

Replace `100.64.1.5` with your Tailscale IP.

### Option B: MagicDNS (Easier, no Pi-hole needed)

**1. Enable MagicDNS in Tailscale:**

Visit https://login.tailscale.com/admin/dns and:
- Toggle "MagicDNS" ON
- This lets you use hostnames like `homelab` instead of IPs

**2. Use Tailscale IP for everything:**

Access services via:
- `https://100.64.1.5` (Cosmos)
- Or use /etc/hosts (see Option C)

### Option C: /etc/hosts (Simplest for testing)

**On your laptop (not server):**

```bash
# Edit hosts file
sudo nano /etc/hosts

# Add these lines (replace 100.64.1.5 with your Tailscale IP):
100.64.1.5  cosmos.homelab.local
100.64.1.5  jellyfin.homelab.local
100.64.1.5  n8n.homelab.local
100.64.1.5  portainer.homelab.local
100.64.1.5  uptime.homelab.local
100.64.1.5  pihole.homelab.local
```

**On macOS:** Same file is `/etc/hosts`
**On Windows:** `C:\Windows\System32\drivers\etc\hosts`

---

## Part 5: Access Your Services (2 minutes)

### Step 1: Verify Services Are Running

```bash
docker compose ps
```

All services should show "Up".

### Step 2: Access Cosmos Dashboard

**Via Tailscale IP:**
```
https://100.64.1.5
```

**Via domain (if you set up DNS):**
```
https://cosmos.homelab.local
```

**First time:**
- Browser will show SSL warning (self-signed certificate)
- Click "Advanced" → "Proceed anyway"
- This is normal for local setups

### Step 3: Complete Cosmos Setup

1. Create admin account
2. Set hostname: `cosmos.homelab.local`
3. Configure SSL (self-signed is fine)

### Step 4: Add Cosmos Routes

Add routes for each service:

**n8n:**
- Host: `n8n.homelab.local`
- Target: `http://n8n:5678`
- Enable HTTPS

**Jellyfin:**
- Host: `jellyfin.homelab.local`
- Target: `http://jellyfin:8096`
- Enable HTTPS

**Portainer:**
- Host: `portainer.homelab.local`
- Target: `http://portainer:9000`
- Enable HTTPS

**Uptime Kuma:**
- Host: `uptime.homelab.local`
- Target: `http://uptime-kuma:3001`
- Enable HTTPS

**Pi-hole:**
- Host: `pihole.homelab.local`
- Target: `http://pihole:80/admin`
- Enable HTTPS

---

## Part 6: Test Everything (5 minutes)

### 1. Test Local Access (from server)

```bash
curl -k https://localhost
```

Should return Cosmos HTML.

### 2. Test Tailscale Access (from laptop)

Open browser and visit:
```
https://cosmos.homelab.local
https://jellyfin.homelab.local
https://n8n.homelab.local
```

All should load.

### 3. Test Auto-Connector

```bash
# Check auto-connector is running
sudo systemctl status cosmos-network-connector

# Check logs
sudo tail -20 /var/log/cosmos-network-connector.log
```

Should show "Starting Cosmos network connector..."

### 4. Test Inter-Service Communication

**Install a test app from Cosmos market:**
1. Open Cosmos → Market
2. Install "Heimdall" or any app
3. Check auto-connector logs:

```bash
sudo tail -f /var/log/cosmos-network-connector.log
```

Should see:
```
[2026-01-03 15:30:45] Connecting Heimdall to homelab-shared
[2026-01-03 15:30:45] ✅ Connected Heimdall
```

### 5. Verify Shared Network

```bash
docker network inspect homelab-shared | grep Name
```

Should show all your services.

---

## Part 7: Add Media to Jellyfin (5 minutes)

### Step 1: Add Media Files

```bash
# Copy movies
cp -r /path/to/movies/* ~/homelab-stack/jellyfin-media/movies/

# Copy TV shows
cp -r /path/to/tv/* ~/homelab-stack/jellyfin-media/tv/

# Or use rsync for large transfers
rsync -avh --progress /path/to/movies/ ~/homelab-stack/jellyfin-media/movies/
```

### Step 2: Set Up Jellyfin

1. Visit `https://jellyfin.homelab.local`
2. Create admin account
3. Add media library:
   - Type: Movies
   - Folder: `/media/movies`
4. Add TV library:
   - Type: TV Shows
   - Folder: `/media/tv`
5. Scan libraries

### Step 3: Enable Hardware Transcoding

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **VAAPI**
3. Enable for H264, HEVC
4. Save

---

## Part 8: Secure Everything (5 minutes)

### 1. Change All Default Passwords

- Cosmos admin password
- Jellyfin admin password
- n8n owner password
- Portainer admin password
- Pi-hole admin password

**Get Pi-hole password:**
```bash
cat .env | grep PIHOLE_PASSWORD
```

### 2. Configure Cosmos Authentication

For each route in Cosmos:
1. Edit route
2. Security → Enable authentication
3. Select users who can access

### 3. Set Up Tailscale ACLs (Optional)

Restrict who can access what:
https://login.tailscale.com/admin/acls

Example ACL:
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["homelab:*"]
    }
  ]
}
```

---

## Part 9: Set Up Backups (5 minutes)

### Create Backup Script

```bash
sudo nano /usr/local/bin/backup-homelab.sh
```

Paste:
```bash
#!/bin/bash
BACKUP_DIR="/mnt/backup/homelab"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR/$DATE"

# Backup volumes
sudo cp -r /var/lib/docker/volumes/homelab-stack_* "$BACKUP_DIR/$DATE/"

# Backup configs
cp -r ~/homelab-stack/cosmos-config ~/homelab-stack/.env ~/homelab-stack/docker-compose.yml "$BACKUP_DIR/$DATE/"

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

Make executable:
```bash
sudo chmod +x /usr/local/bin/backup-homelab.sh
```

### Schedule Daily Backups

```bash
crontab -e
```

Add:
```
0 3 * * * /usr/local/bin/backup-homelab.sh
```

---

## Troubleshooting

### Can't access services via domain

**1. Check Tailscale is connected:**
```bash
tailscale status
```

**2. Ping your Tailscale IP:**
```bash
ping 100.64.1.5
```

**3. Check DNS:**
```bash
nslookup cosmos.homelab.local
```

**Fix:** Use /etc/hosts method (see Part 4, Option C)

### Services can't talk to each other

**Check shared network:**
```bash
docker network inspect homelab-shared | grep Name
```

**Fix:** Manually connect:
```bash
docker network connect homelab-shared service_name
```

### Auto-connector not working

**Check service:**
```bash
sudo systemctl status cosmos-network-connector
```

**Restart it:**
```bash
sudo systemctl restart cosmos-network-connector
```

### Out of memory

**Lower resource limits:**
```bash
nano .env
```

Change values like `JELLYFIN_MEM=4G` to `JELLYFIN_MEM=2G`

Then:
```bash
docker compose up -d
```

---

## Quick Reference

### Common Commands

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start everything
docker compose up -d

# Update services
docker compose pull && docker compose up -d

# Check auto-connector
sudo systemctl status cosmos-network-connector
sudo tail -f /var/log/cosmos-network-connector.log

# Check Tailscale
tailscale status
tailscale ip
```

### Access URLs (via Tailscale)

Replace `100.64.1.5` with your Tailscale IP or use domains if configured:

- Cosmos: `https://100.64.1.5` or `https://cosmos.homelab.local`
- Jellyfin: `https://jellyfin.homelab.local`
- n8n: `https://n8n.homelab.local`
- Portainer: `https://portainer.homelab.local`
- Uptime Kuma: `https://uptime.homelab.local`
- Pi-hole: `https://pihole.homelab.local/admin`

---

## Next Steps

1. **Add more apps from Cosmos market** - All auto-connect to shared network
2. **Set up n8n workflows** - Automate your homelab
3. **Configure monitoring** - Use Uptime Kuma for alerts
4. **Optimize Pi-hole** - Add more blocklists
5. **Share media** - Create Jellyfin user accounts for family

---

## Getting Help

**Quick fixes:** Check [Common Issues](docs/COMMON_ISSUES.md)

**Advanced help:** Check [Advanced Docs](docs/advanced/)

**Still stuck:** [Open an issue](https://github.com/cph911/homelab-stack/issues)

---

**That's it! You now have a fully working homelab accessible anywhere via Tailscale.** 🚀
