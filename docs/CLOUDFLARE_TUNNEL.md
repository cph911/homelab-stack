# Cloudflare Tunnel Setup Guide

Access your homelab via public domain using Cloudflare Tunnel (formerly Argo Tunnel).

## Overview

**What is Cloudflare Tunnel?**
- Secure tunnel from Cloudflare to your homelab
- No port forwarding or public IP required
- Free tier available
- Real SSL certificates from Cloudflare

**Architecture:**
```
Internet → Cloudflare → Cloudflared (Tunnel) → Your Homelab Services
```

## Prerequisites

- Cloudflare account (free): https://dash.cloudflare.com
- Domain name added to Cloudflare
- Cloudflare nameservers configured for your domain

## When to Use Cloudflare Tunnel

**Good for:**
- ✅ Want public HTTPS access
- ✅ Need to share services with friends/family
- ✅ Want real SSL certificates
- ✅ Behind CG-NAT (no static IP)

**Not ideal for:**
- ❌ Privacy-focused setups (traffic goes through Cloudflare)
- ❌ High bandwidth services (Cloudflare may rate limit)
- ❌ Local-only access (use Tailscale instead)

## Setup Steps

### Step 1: Install Cloudflared

On your homelab server:

```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Install
sudo dpkg -i cloudflared-linux-amd64.deb

# Verify installation
cloudflared --version
```

### Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This will:
1. Open browser for authentication
2. Ask you to select your domain
3. Create cert.pem file in `~/.cloudflared/`

### Step 3: Create a Tunnel

```bash
# Create tunnel named "homelab"
cloudflared tunnel create homelab

# Note the Tunnel ID shown (you'll need it later)
```

### Step 4: Configure DNS

Create DNS records in Cloudflare dashboard:

```
CNAME  n8n         <TUNNEL-ID>.cfargotunnel.com
CNAME  jellyfin    <TUNNEL-ID>.cfargotunnel.com
CNAME  portainer   <TUNNEL-ID>.cfargotunnel.com
CNAME  uptime      <TUNNEL-ID>.cfargotunnel.com
```

Or use CLI:
```bash
cloudflared tunnel route dns homelab n8n.yourdomain.com
cloudflared tunnel route dns homelab jellyfin.yourdomain.com
cloudflared tunnel route dns homelab portainer.yourdomain.com
```

### Step 5: Create Config File

```bash
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

Add configuration:
```yaml
tunnel: <YOUR-TUNNEL-ID>
credentials-file: /home/YOUR_USER/.cloudflared/<YOUR-TUNNEL-ID>.json

ingress:
  # n8n
  - hostname: n8n.yourdomain.com
    service: http://localhost:5678

  # Jellyfin
  - hostname: jellyfin.yourdomain.com
    service: http://localhost:8096

  # Portainer
  - hostname: portainer.yourdomain.com
    service: http://localhost:9000

  # Uptime Kuma
  - hostname: uptime.yourdomain.com
    service: http://localhost:3001

  # Catch-all (required)
  - service: http_status:404
```

### Step 6: Test the Tunnel

```bash
cloudflared tunnel run homelab
```

Visit your services at:
- `https://n8n.yourdomain.com`
- `https://jellyfin.yourdomain.com`

If working, proceed to Step 7.

### Step 7: Install as System Service

```bash
# Install service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared

# Enable on boot
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

## Using with Cosmos

Since Cloudflare Tunnel connects directly to service ports, you have two options:

### Option A: Bypass Cosmos (Direct Connection)

Point Cloudflare Tunnel directly to service ports:
```yaml
ingress:
  - hostname: n8n.yourdomain.com
    service: http://localhost:5678  # Direct to n8n
```

### Option B: Through Cosmos (Recommended)

Point Cloudflare Tunnel to Cosmos, which routes to services:
```yaml
ingress:
  - hostname: n8n.yourdomain.com
    service: http://localhost:80  # Cosmos handles routing
    originRequest:
      httpHostHeader: n8n.yourdomain.com
```

This requires Cosmos to be properly configured with routes.

## Security Considerations

### Enable Access Control

In Cloudflare dashboard:
1. Go to Zero Trust → Access → Applications
2. Create application for each service
3. Add authentication rules
4. Require email, Google, or other auth

### IP Restriction

Restrict access to specific countries or IPs:
1. Firewall → Firewall Rules
2. Create rule: Block if Country not in [Your Country]

### Rate Limiting

Add rate limiting to prevent abuse:
1. Security → WAF → Rate limiting rules
2. Set limits per service

## Monitoring

### Check Tunnel Status

```bash
# View tunnel status
cloudflared tunnel info homelab

# View tunnel logs
sudo journalctl -u cloudflared -f
```

### Cloudflare Dashboard

Monitor traffic and errors:
- Analytics → Traffic
- Analytics → Security

## Troubleshooting

### Tunnel Not Connecting

```bash
# Check service status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -n 50

# Test connectivity
cloudflared tunnel run homelab
```

### 502 Bad Gateway

- Verify service is running on specified port
- Check firewall rules
- Verify originRequest settings

### DNS Not Resolving

- Wait for DNS propagation (up to 24 hours)
- Verify CNAME records in Cloudflare
- Check nameservers are set to Cloudflare

## Cost

**Free Tier:**
- Unlimited tunnels
- Unlimited bandwidth (fair use)
- Basic DDoS protection

**Paid Plans (Zero Trust):**
- Required for Access features
- Starts at $7/user/month
- Advanced security features

## Alternative: Cloudflare Pages

For static sites, consider Cloudflare Pages instead of tunnels.

## Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Zero Trust Dashboard](https://one.dash.cloudflare.com/)
- [Community Forum](https://community.cloudflare.com/)

## Comparison: Tailscale vs Cloudflare Tunnel

| Feature | Tailscale | Cloudflare Tunnel |
|---------|-----------|-------------------|
| Privacy | ✅ End-to-end encrypted | ⚠️ Traffic through Cloudflare |
| Setup Complexity | Easy | Moderate |
| Public Access | ❌ No | ✅ Yes |
| Mobile Access | ✅ VPN app | ✅ Any browser |
| Cost | Free for personal | Free (paid for features) |
| Speed | Fast (direct) | Depends on Cloudflare edge |

**Recommendation:**
- **Tailscale**: For private, secure access
- **Cloudflare Tunnel**: For public sharing or when VPN not feasible

---

**Next Steps:**
1. Set up Cloudflare Tunnel following this guide
2. Configure services in Cosmos (see [COSMOS_SETUP.md](COSMOS_SETUP.md))
3. Test public access from different networks
4. Configure security (authentication, rate limiting)
