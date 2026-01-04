# Pi-hole Quick Setup Guide

## 1. Install Pi-hole

```bash
docker run -d \
  --name pihole \
  --network homelab-shared \
  --restart unless-stopped \
  -p 192.168.1.69:53:53/tcp \
  -p 192.168.1.69:53:53/udp \
  -e TZ='America/New_York' \
  -e WEBPASSWORD='admin' \
  -e DNSMASQ_LISTENING='all' \
  -e PIHOLE_DNS_='8.8.8.8' \
  -v pihole-data:/etc/pihole \
  -v pihole-dnsmasq:/etc/dnsmasq.d \
  pihole/pihole:latest
```

## 2. Fix Listening Mode (CRITICAL!)

```bash
# Change LOCAL to ALL mode
docker exec pihole sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml
docker restart pihole
```

## 3. Add to Cosmos

- Cosmos → URLs → New URL
- Name: `/pihole`
- Port: `80`
- Target: `http://pihole:80`
- Hostname: `pihole.hameed.tech`
- SSL: Yes

## 4. Restore Adlists

- Login: https://pihole.hameed.tech (password: admin)
- Lists → Paste all URLs from backup → Add → Update Gravity

## 5. Phone DNS Setup

- Settings → WiFi → (i) → Configure DNS → Manual
- Add: `192.168.1.69` ONLY
- Remove all other DNS servers
