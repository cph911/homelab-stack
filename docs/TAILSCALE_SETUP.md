# Tailscale VPN Setup Guide

Access your homelab remotely using Tailscale VPN - ideal for setups without static IP or behind CG-NAT.

## Overview

**What is Tailscale?**
- Private VPN network connecting your devices
- Works without static IP or port forwarding
- No public exposure of services
- Free for personal use (up to 100 devices)

**Architecture:**
```
[Your Phone] ←→ Tailscale Network ←→ [Raspberry Pi / VPS] ←→ [Your Homelab]
```

## Prerequisites

- Tailscale account (free): https://tailscale.com
- Raspberry Pi, VPS, or always-on device on the same network as your homelab
- OR install Tailscale directly on your homelab server

## Option 1: Install Tailscale on Homelab Server (Simplest)

### Install Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Start Tailscale
```bash
sudo tailscale up
```

### Get Authentication Link
Follow the URL shown to authenticate with your Tailscale account.

### Enable Subnet Routing (Optional)
This allows access to your entire local network through Tailscale:
```bash
sudo tailscale up --advertise-routes=192.168.1.0/24
```
(Replace with your actual subnet)

Approve the route in the Tailscale admin panel.

### Access Services
Once connected to Tailscale from any device:
- Use the Tailscale IP: `http://100.x.x.x:5678` (n8n)
- Or enable MagicDNS and use: `http://your-server-name:5678`

## Option 2: Raspberry Pi as Tailscale Gateway (Recommended for Saudi Arabia)

### Why This Approach?
- Keeps homelab server isolated
- Raspberry Pi 400 acts as secure gateway
- Can combine with Pi-hole for DNS ad-blocking
- Lower power consumption (Pi runs 24/7)

### Hardware Needed
- Raspberry Pi 400 (or any Raspberry Pi 3/4)
- MicroSD card (16GB+)
- Power supply
- Network connection to same network as homelab

### Setup Steps

**1. Install Raspberry Pi OS**
- Download Raspberry Pi Imager
- Flash Raspberry Pi OS Lite (64-bit)
- Enable SSH during imaging

**2. Initial Pi Configuration**
```bash
# Connect via SSH
ssh pi@raspberrypi.local

# Update system
sudo apt update && sudo apt upgrade -y

# Set static IP (optional but recommended)
sudo nmtui
```

**3. Install Tailscale on Pi**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes
```

**4. Enable IP Forwarding**
```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**5. Approve Subnet Routes**
- Go to https://login.tailscale.com/admin/machines
- Find your Raspberry Pi
- Click "..." → Edit route settings
- Enable the advertised routes

**6. Install Pi-hole (Optional)**
```bash
curl -sSL https://install.pi-hole.net | bash
```

Configure Pi-hole to listen on Tailscale interface.

### Access from Phone/Laptop

**Install Tailscale on Client Devices:**
- iOS: Download from App Store
- Android: Download from Play Store
- Mac/Windows/Linux: https://tailscale.com/download

**Connect and Access:**
1. Open Tailscale and sign in
2. Connect to your network
3. Access services using local IPs:
   - `http://192.168.1.69:5678` (n8n)
   - `http://192.168.1.69:8096` (Jellyfin)
   - Or use domain names if you set up Pi-hole with local DNS

## Option 3: VPS as Tailscale Exit Node

If you prefer not to keep Raspberry Pi running or want faster remote access:

### Setup
1. Get a cheap VPS (€3-5/month)
2. Install Tailscale on VPS
3. Configure as exit node
4. Route traffic through VPS to your homelab

See Tailscale documentation for exit node setup.

## Tailscale MagicDNS

Enable MagicDNS in Tailscale admin panel to access devices by name:
```
https://n8n.your-server-name.ts.net:5678
```

## Security Considerations

- Tailscale uses WireGuard encryption
- All traffic is end-to-end encrypted
- No public ports exposed
- Access control via Tailscale ACLs
- Can require multi-factor authentication

## Combining with Cosmos

Cosmos will handle routing on your local network. Tailscale provides the secure tunnel to access it remotely.

**Access Flow:**
```
Phone (anywhere) → Tailscale VPN → Local Network → Cosmos → Service
```

## Troubleshooting

### Can't Connect to Tailscale
```bash
sudo tailscale status
sudo tailscale ping 100.x.x.x
```

### Can't Access Local Services
- Verify subnet routes are approved
- Check firewall rules
- Ensure IP forwarding is enabled

### DNS Not Resolving
- Enable MagicDNS in Tailscale admin
- Or use IP addresses directly

## Cost

**Free Tier:**
- Personal use
- Up to 100 devices
- Unlimited data transfer

**Paid Plans:**
- Required for teams/commercial use
- Starts at $6/user/month

## Resources

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Subnet Routing Guide](https://tailscale.com/kb/1019/subnets/)
- [Exit Nodes Guide](https://tailscale.com/kb/1103/exit-nodes/)
- [MagicDNS Setup](https://tailscale.com/kb/1081/magicdns/)

---

**Next Steps:**
1. Set up Tailscale following the option that fits your needs
2. Configure services in Cosmos (see [COSMOS_SETUP.md](COSMOS_SETUP.md))
3. Test remote access from phone/laptop
4. Enjoy secure access to your homelab from anywhere!
