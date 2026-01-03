# Common Issues (Quick Fixes)

## Can't access services via domain name

**Problem:** `https://jellyfin.hameed.tech` doesn't work

**Fix:**
1. Disable DNS-over-HTTPS in your browser
   - Chrome/Brave: Settings → Privacy → Security → Turn off "Use secure DNS"
   - Firefox: Settings → Privacy → DNS over HTTPS → Select "Off"
2. Clear your browser's DNS cache (or restart browser)

## Services can't talk to each other

**Problem:** Notifiarr can't connect to qBittorrent

**Fix:**
```bash
# Connect the service to the shared network
docker network connect homelab-shared qbittorrent
docker network connect homelab-shared notifiarr
```

When configuring, use:
- Host: `qbittorrent` (not `qbittorrent.hameed.tech`)
- Port: `8081` (not `443`)
- URL: `http://qbittorrent:8081` (not https)

## Notifiarr won't install from Cosmos market

**Problem:** Error about `/var/run/utmp`

**Fix:**
```bash
sudo touch /var/run/utmp
sudo chmod 644 /var/run/utmp
```

Then retry installation in Cosmos.

## Services keep crashing

**Problem:** Containers show "Exited (137)"

**Fix:** You're out of memory. Edit `.env` and lower the limits:
```bash
nano .env

# Change something like this:
JELLYFIN_MEM=4G  # Lower to 2G
N8N_MEM=2G       # Lower to 1G
```

Then restart:
```bash
docker compose up -d
```

## Can't access anything

**Check if services are running:**
```bash
docker compose ps
```

**Check if Cosmos is running:**
```bash
docker ps | grep cosmos
```

**Restart everything:**
```bash
docker compose restart
```

## SSL certificate errors

**Problem:** Browser shows "Not secure" warning

**For local access (no internet):** This is normal with self-signed certificates. Just click "Advanced" → "Proceed anyway"

**For public access:** Make sure your domain DNS points to your server's public IP.

## Still stuck?

Check the [Advanced Troubleshooting Guide](advanced/TROUBLESHOOTING.md) for detailed solutions.

Or [open an issue](https://github.com/cph911/homelab-stack/issues) with:
- What you tried to do
- What happened instead
- Output of `docker compose ps`
- Output of `docker compose logs`
