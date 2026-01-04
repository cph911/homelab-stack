# Tailscale Setup Guide

Tailscale provides secure remote access to your homelab without port forwarding, dynamic DNS, or static IP addresses. It creates a private mesh network (VPN) between your devices.

## Why Tailscale?

**Advantages:**
- No port forwarding required - works behind NAT/CGNAT
- No static IP needed - works with dynamic IPs
- Zero-trust security model with WireGuard encryption
- Access both homelab services AND LAN devices (Home Assistant, printers, etc.)
- Works across different networks (home, mobile, work)
- Free tier supports up to 100 devices
- Automatic IP assignment and DNS

**vs Port Forwarding:**
- No exposed ports to the internet
- No DDoS attack surface
- No need to trust ISP security

**vs Cloudflare Tunnel:**
- Can access LAN devices (Home Assistant, IoT, etc.)
- Lower latency (direct peer-to-peer when possible)
- Works for any protocol (not just HTTP/HTTPS)

## Installation

### 1. Install Tailscale on Your Server

```bash
# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt update
sudo apt install tailscale -y

# Start Tailscale and authenticate
sudo tailscale up
```

This will print a URL - open it in your browser to authenticate with your Tailscale account (Google, GitHub, or Microsoft).

### 2. Enable Subnet Routing (Optional but Recommended)

This allows you to access other devices on your home network (like Home Assistant) through Tailscale:

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Advertise your home network subnet (replace with your network)
# Common home networks: 192.168.1.0/24, 192.168.0.0/24, 10.0.0.0/24
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes
```

**Find your subnet:**
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```
Look for something like `192.168.1.x/24` - use that network with `/24` suffix.

### 3. Approve Subnet Routes

1. Go to https://login.tailscale.com/admin/machines
2. Find your server in the list
3. Click the `⋮` menu → **Edit route settings**
4. Enable the subnet route(s) you advertised
5. Click **Save**

### 4. Configure MagicDNS (Optional but Convenient)

MagicDNS lets you access devices by name instead of IP:

1. Go to https://login.tailscale.com/admin/dns
2. Enable **MagicDNS**
3. Your server will be accessible as `servername.tail-scale.ts.net`

## Install Tailscale on Client Devices

### Desktop (Windows/Mac/Linux)
Download from https://tailscale.com/download

### Mobile (iOS/Android)
Install from App Store or Google Play

### All Platforms
After installation, sign in with the same account you used for the server.

## Accessing Your Homelab

Once Tailscale is running on both server and client:

### Option 1: Using Tailscale IP
```bash
# Find your server's Tailscale IP
tailscale ip -4
```

Access services via Tailscale IP:
- `https://100.x.x.x` (Cosmos dashboard)
- `https://cosmos.your-domain.com` still works locally

### Option 2: Using MagicDNS
If you enabled MagicDNS:
- `https://servername.tail-scale.ts.net`
- `https://servername.tail-scale.ts.net:8096` (for Jellyfin if on custom port)

### Option 3: Custom DNS (Advanced)

You can configure Cosmos to respond to a custom domain over Tailscale:

1. In Tailscale admin: **DNS** → **Nameservers** → Add your server's Tailscale IP
2. Configure Cosmos to serve your domain
3. Access via `https://cosmos.yourdomain.com` from anywhere

## Accessing LAN Devices (Home Assistant, etc.)

If you enabled subnet routing, you can access ANY device on your home network:

**From your phone while on mobile data:**
- Home Assistant: `http://192.168.1.50:8123` (use your HA's actual IP)
- Router admin: `http://192.168.1.1`
- Printers, IoT devices, etc.

**No configuration needed on those devices** - Tailscale routes traffic through your server.

## Tailscale + Homelab Stack Integration

### DNS Configuration

Your homelab services work seamlessly with Tailscale:

1. **Local network**: Access via `https://cosmos.your-domain.com`
2. **Remote (Tailscale)**: Access via Tailscale IP or MagicDNS name
3. **Subnet routing**: Access LAN devices through Tailscale

### Cosmos Reverse Proxy

Cosmos continues to handle SSL and routing:
- All services still behind Cosmos reverse proxy
- SSL certificates still work
- Same URLs work both locally and remotely

### n8n Webhooks

n8n webhooks work with Tailscale:
- Use Tailscale IP or MagicDNS name in webhook URLs
- External services (like Telegram) need Cloudflare Tunnel or port forwarding
- Internal automation works perfectly

## Security Best Practices

### 1. Enable Two-Factor Authentication
https://login.tailscale.com/admin/settings/user → **Two-factor authentication**

### 2. Use ACLs (Access Control Lists)
Control which devices can access what:
https://login.tailscale.com/admin/acls

Example ACL (only you can access your homelab):
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["your-email@example.com"],
      "dst": ["tag:homelab:*"]
    }
  ],
  "tagOwners": {
    "tag:homelab": ["your-email@example.com"]
  }
}
```

### 3. Disable Key Expiry (Optional)
By default, Tailscale keys expire after 180 days:
1. Go to https://login.tailscale.com/admin/machines
2. Find your server → `⋮` menu → **Disable key expiry**

### 4. Enable HTTPS
Even over Tailscale, use HTTPS:
- Cosmos already provides SSL
- Tailscale encrypts traffic (WireGuard)
- Double encryption = extra security

## Troubleshooting

### Can't Access Server
```bash
# Check Tailscale status on server
sudo tailscale status

# Check if service is running
sudo systemctl status tailscaled

# Restart Tailscale
sudo systemctl restart tailscaled
```

### Subnet Routes Not Working
```bash
# Verify routes are advertised
tailscale status --peers=false

# Check IP forwarding is enabled
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding

# Verify in Tailscale admin panel that routes are approved
```

### Slow Performance
- Tailscale uses direct peer-to-peer when possible
- If going through relay (DERP), check firewall isn't blocking UDP
- Use `tailscale netcheck` to diagnose connectivity

### DNS Issues
```bash
# Check MagicDNS is enabled in admin panel
# Verify DNS settings on client:
tailscale status --json | grep MagicDNSSuffix
```

## Common Scenarios

### Scenario 1: Access Jellyfin While Traveling
1. Install Tailscale on phone/laptop
2. Connect to Tailscale
3. Open browser → `https://100.x.x.x` or `https://servername.tail-scale.ts.net`
4. Stream your media from anywhere

### Scenario 2: Control Home Assistant Remotely
1. Enable subnet routing on homelab server
2. Approve routes in Tailscale admin
3. Connect to Tailscale from phone
4. Access HA: `http://192.168.1.x:8123`

### Scenario 3: Work on n8n Workflows From Coffee Shop
1. Connect to Tailscale
2. Access n8n: `https://100.x.x.x/n8n` or via MagicDNS
3. Build workflows securely over encrypted VPN

### Scenario 4: Share Jellyfin with Family
1. Invite family members to your Tailscale network (Tailscale admin)
2. They install Tailscale and sign in
3. Share Tailscale IP or MagicDNS name
4. They access Jellyfin securely without exposing to internet

## Tailscale + Wake-on-LAN

Combine Tailscale with WoL for ultimate remote access:

1. **Send WoL packet through Tailscale subnet:**
   ```bash
   # From any device on Tailscale
   wakeonlan -i 192.168.1.255 AA:BB:CC:DD:EE:FF
   ```

2. **Use Telegram bot to wake server**
3. **Server boots, Tailscale auto-connects**
4. **Receive startup notification via Telegram**
5. **Access services through Tailscale**

No port forwarding, no static IP, no hassle.

## Cost

- **Free tier**: Up to 100 devices, 1 user, unlimited traffic
- **Personal Pro** ($48/year): Multiple users, more admins
- **Team** ($15/user/month): Advanced ACLs, SSO

For homelab use, **free tier is usually sufficient**.

## Further Reading

- Official docs: https://tailscale.com/kb/
- How Tailscale works: https://tailscale.com/blog/how-tailscale-works/
- WireGuard whitepaper: https://www.wireguard.com/papers/wireguard.pdf

## Summary

Tailscale is the easiest way to access your homelab remotely:
- ✅ No networking headaches (NAT, port forwarding, DDNS)
- ✅ Secure by default (WireGuard, zero-trust)
- ✅ Access LAN devices (Home Assistant, etc.)
- ✅ Works everywhere (mobile, laptop, etc.)
- ✅ Free for personal use

Set it up once, access your homelab from anywhere, forever.
