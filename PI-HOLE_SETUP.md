# Pi-hole Quick Setup Guide

## Automated Installation (Recommended)

```bash
# Required: Set your server's IP address
SERVER_IP=YOUR_SERVER_IP ./install-pihole.sh

# With custom password:
SERVER_IP=YOUR_SERVER_IP PIHOLE_PASSWORD=yourpassword ./install-pihole.sh
```

This script automatically:
- Removes old Pi-hole container
- Installs Pi-hole with correct network settings
- Fixes the listening mode to allow external devices
- Restarts and verifies the installation

## Manual Installation

### 1. Install Pi-hole

```bash
docker run -d \
  --name pihole \
  --network homelab-shared \
  --restart unless-stopped \
  -p YOUR_SERVER_IP:53:53/tcp \
  -p YOUR_SERVER_IP:53:53/udp \
  -e TZ='America/New_York' \
  -e WEBPASSWORD='admin' \
  -e DNSMASQ_LISTENING='all' \
  -e PIHOLE_DNS_='8.8.8.8' \
  -v pihole-data:/etc/pihole \
  -v pihole-dnsmasq:/etc/dnsmasq.d \
  pihole/pihole:latest
```

### 2. Fix Listening Mode (CRITICAL!)

```bash
# Change LOCAL to ALL mode
docker exec pihole sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml
docker restart pihole
```

## Next Steps After Installation

### 1. Add to Cosmos

- Cosmos → URLs → New URL
- Name: `/pihole`
- Port: `80`
- Target: `http://pihole:80`
- Hostname: `YOUR_DOMAIN.com`
- SSL: Yes

### 2. Restore Adlists

- Login: https://YOUR_DOMAIN.com (password: admin)
- Lists → Paste all URLs from backup → Add → Update Gravity

### 3. Device DNS Setup

- Settings → WiFi → (i) → Configure DNS → Manual
- Add: `YOUR_SERVER_IP` ONLY
- Remove all other DNS servers
