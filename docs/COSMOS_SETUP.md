# Cosmos Server Setup Guide

This guide walks you through configuring Cosmos as your reverse proxy after running the installer.

## Initial Setup

After installation, Cosmos will be running but needs initial configuration.

### Step 1: Access Cosmos

**Option A: Via IP (First Time)**
```
http://YOUR_SERVER_IP
```

**Option B: Via Domain (After /etc/hosts setup)**
```
https://cosmos.yourdomain.com
```

### Step 2: Complete Setup Wizard

1. **Create Admin Account**
   - Set admin username and password
   - Keep these credentials secure!

2. **Configure Hostname**
   - Enter your domain: `cosmos.yourdomain.com`
   - Or use IP for local-only access

3. **SSL Configuration**
   - **For local access**: Choose "Locally self-sign certificates"
   - **For public domain**: Choose appropriate SSL method
   - Check "Use Wildcard Certificate" for `*.yourdomain.com`
   - Check "Allow insecure access via local IP" (for phone/mobile access)

## Adding Service Routes

After setup, you need to add routes for each service.

### Navigate to URLs Section

1. Click the **☰ menu** (top left)
2. Go to **"URLs"** or **"ServApps"**
3. Click **"+ Create"** or **"+ New Route"**

### Add Routes for Each Service

For each service, fill in:

#### n8n
- **Name**: `n8n`
- **Description**: `Workflow Automation`
- **Mode**: `ServApp - Docker Container`
- **Container Name**: `n8n`
- **Container Port**: `5678`
- **Container Protocol**: `http`
- **Source → Use Host**: ✅ Checked
- **Host**: `n8n.yourdomain.com`

#### Jellyfin
- **Name**: `Jellyfin`
- **Description**: `Media Server`
- **Mode**: `ServApp - Docker Container`
- **Container Name**: `jellyfin`
- **Container Port**: `8096`
- **Container Protocol**: `http`
- **Source → Use Host**: ✅ Checked
- **Host**: `jellyfin.yourdomain.com`

#### Portainer (if installed)
- **Name**: `Portainer`
- **Description**: `Docker Management`
- **Mode**: `ServApp - Docker Container`
- **Container Name**: `portainer`
- **Container Port**: `9000`
- **Container Protocol**: `http`
- **Source → Use Host**: ✅ Checked
- **Host**: `portainer.yourdomain.com`

#### Uptime Kuma (if installed)
- **Name**: `Uptime Kuma`
- **Description**: `Monitoring`
- **Mode**: `ServApp - Docker Container`
- **Container Name**: `uptime-kuma`
- **Container Port**: `3001`
- **Container Protocol**: `http`
- **Source → Use Host**: ✅ Checked
- **Host**: `uptime.yourdomain.com`

#### Pi-hole (if installed)
- **Name**: `Pi-hole`
- **Description**: `DNS Ad Blocker`
- **Mode**: `ServApp - Docker Container`
- **Container Name**: `pihole`
- **Container Port**: `80`
- **Container Protocol**: `http`
- **Source → Use Host**: ✅ Checked
- **Host**: `pihole.yourdomain.com`
- **Source → Use Path Prefix**: ✅ Checked
- **Path**: `/admin`

### DNS Warning

When adding routes, you may see a DNS check error:
```
DNS Check error: lookup jellyfin.yourdomain.com: no such host
```

**This is normal!** Ignore this warning if you're using:
- Local /etc/hosts file
- Tailscale VPN
- Any local-only setup

The routing will still work perfectly fine.

## Local Access Setup

### On Your Computer (Mac/Linux)

Add entries to `/etc/hosts`:
```bash
sudo nano /etc/hosts
```

Add these lines:
```
YOUR_SERVER_IP cosmos.yourdomain.com
YOUR_SERVER_IP n8n.yourdomain.com
YOUR_SERVER_IP jellyfin.yourdomain.com
YOUR_SERVER_IP portainer.yourdomain.com
YOUR_SERVER_IP uptime.yourdomain.com
YOUR_SERVER_IP pihole.yourdomain.com
```

Save: `Ctrl+X`, `Y`, `Enter`

### On Your Computer (Windows)

Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator:
```
YOUR_SERVER_IP cosmos.yourdomain.com
YOUR_SERVER_IP n8n.yourdomain.com
YOUR_SERVER_IP jellyfin.yourdomain.com
YOUR_SERVER_IP portainer.yourdomain.com
YOUR_SERVER_IP uptime.yourdomain.com
YOUR_SERVER_IP pihole.yourdomain.com
```

### On Your Phone/Mobile

**Phones can't use /etc/hosts**, so use IP:port format:

- n8n: `http://YOUR_SERVER_IP:5678`
- Jellyfin: `http://YOUR_SERVER_IP:8096`
- Portainer: `http://YOUR_SERVER_IP:9000`
- Uptime Kuma: `http://YOUR_SERVER_IP:3001`
- Pi-hole: `http://YOUR_SERVER_IP:8053/admin`
- Cosmos: `http://YOUR_SERVER_IP`

## Security Settings

### Smart Shield Protection

Cosmos has built-in security features:
- **Smart Shield Protection**: Enabled by default (DDoS protection, rate limiting)
- **Authentication Required**: Optional (add login to specific services)
- **VPN Restriction**: Optional (restrict to Constellation VPN only)

For homelab use, the defaults are fine.

## Troubleshooting

### Service Not Accessible

1. **Check if route is enabled** in Cosmos URLs section
2. **Verify container is running**: `docker ps`
3. **Check Cosmos logs**: `docker logs cosmos`
4. **Verify /etc/hosts** entries are correct

### SSL Certificate Warnings

If using self-signed certificates, your browser will show warnings:
- Click "Advanced"
- Click "Proceed to site"
- This is normal for local self-signed certs

### Can't Access from Phone

Remember: Phones can't use domain names with /etc/hosts.
- Use IP:port format instead
- Or set up Tailscale for VPN access

## Remote Access

### Tailscale VPN (Recommended)

See [TAILSCALE_SETUP.md](TAILSCALE_SETUP.md) for setting up remote access via Tailscale.

### Cloudflare Tunnel (Alternative)

See [CLOUDFLARE_TUNNEL.md](CLOUDFLARE_TUNNEL.md) for public domain access.

## Monitoring

### Check Cosmos Status

```bash
# Check if running
docker ps | grep cosmos

# View logs
docker logs cosmos

# Restart if needed
docker restart cosmos
```

### Cosmos Dashboard

The Cosmos dashboard shows:
- CPU, RAM, Network usage
- All configured routes
- Service health status
- Recent requests and errors

## Advanced Configuration

### Update Cosmos

```bash
cd ~/homelab-stack
docker compose pull cosmos
docker compose up -d cosmos
```

### Backup Cosmos Config

Cosmos config is stored in:
```
~/homelab-stack/cosmos-config/
```

Backup this directory regularly:
```bash
tar -czf cosmos-backup-$(date +%Y%m%d).tar.gz ~/homelab-stack/cosmos-config/
```

## Resources

- [Official Cosmos Documentation](https://cosmos-cloud.io/doc)
- [Cosmos GitHub](https://github.com/azukaar/Cosmos-Server)
- [Community Discord](https://discord.gg/cosmos)

---

**Need help?** Check the [main README](../README.md) or open an issue.
