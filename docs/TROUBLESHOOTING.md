# Troubleshooting

This guide covers common issues and their solutions, organized by symptom.

## Quick Diagnostic Commands

Before diving into specific issues, run these commands to gather information:

```bash
# Check all container status
docker compose ps
docker ps -a

# Check Docker networks
docker network ls
docker network inspect homelab-shared

# Check auto-connector status
sudo systemctl status cosmos-network-connector
sudo tail -20 /var/log/cosmos-network-connector.log

# Check service logs
docker compose logs --tail=50
docker logs cosmos --tail=50

# Check system resources
free -h
df -h
docker system df
```

## DNS and Domain Issues

### Problem: Cannot access services via domain name (e.g., `jellyfin.hameed.tech`)

**Symptoms:**
- Browser shows "Site can't be reached"
- `ping jellyfin.hameed.tech` fails
- Direct IP access works (`http://192.168.1.69:8096`)

**Diagnosis:**
```bash
# Test DNS resolution
nslookup jellyfin.hameed.tech
nslookup jellyfin.hameed.tech 192.168.1.69  # If Pi-hole is at this IP

# Check if Pi-hole is running
docker ps | grep pihole

# Check Pi-hole DNS settings
docker logs pihole | grep -i dns
```

**Solutions:**

**Solution 1: DNS Cache**
```bash
# Clear browser DNS cache
# Chrome: chrome://net-internals/#dns → Clear host cache
# Firefox: about:networking#dns → Clear DNS Cache

# Clear system DNS cache (Linux)
sudo systemd-resolve --flush-caches

# Clear system DNS cache (macOS)
sudo dscacheutil -flushcache
```

**Solution 2: Browser DNS-over-HTTPS (DoH) Bypass**

Modern browsers use DoH which bypasses Pi-hole/local DNS.

**Disable in Chrome/Brave:**
1. Settings → Privacy and security → Security
2. Scroll to "Use secure DNS"
3. Turn OFF or select "With your current service provider"

**Disable in Firefox:**
1. Settings → Privacy & Security
2. Scroll to "DNS over HTTPS"
3. Select "Off" or "Default Protection"

**Solution 3: /etc/hosts (Alternative to DNS)**

If you don't want to use Pi-hole:

```bash
# Edit hosts file
sudo nano /etc/hosts

# Add entries for each service
192.168.1.69  cosmos.hameed.tech
192.168.1.69  jellyfin.hameed.tech
192.168.1.69  n8n.hameed.tech
192.168.1.69  portainer.hameed.tech
```

**Solution 4: Configure Pi-hole Wildcard DNS**

```bash
# SSH to server
ssh user@192.168.1.69

# Add wildcard DNS entry
echo "address=/hameed.tech/192.168.1.69" | sudo tee /etc/dnsmasq.d/02-homelab.conf

# Restart Pi-hole
docker restart pihole
```

Then configure devices to use Pi-hole as DNS server (192.168.1.69).

### Problem: DNS resolution works inconsistently

**Symptoms:**
- Sometimes resolves, sometimes doesn't
- Works on some devices, not others
- Works in incognito/private mode but not regular browser

**Causes:**
- Mixed DNS sources (some devices using ISP DNS, some using Pi-hole)
- Browser DNS cache vs system DNS cache
- DNS-over-HTTPS randomly enabled

**Solution:**

**Enforce DNS at router level:**
1. Log into router admin panel
2. Set DHCP DNS servers to Pi-hole IP (192.168.1.69)
3. (Advanced) Block outbound port 53 to internet (forces all DNS through Pi-hole)
4. (Advanced) Block DoH domains (1.1.1.1, 8.8.8.8, dns.google, etc.)

## Network Connectivity Issues

### Problem: Services can't communicate with each other

**Symptoms:**
- Notifiarr can't connect to qBittorrent
- Sonarr can't connect to download clients
- Error: "dial tcp: lookup qbittorrent: no such host"
- Error: "connection refused"

**Diagnosis:**
```bash
# Check if both containers are on homelab-shared
docker network inspect homelab-shared

# Test DNS resolution between containers
docker exec notifiarr ping qbittorrent
docker exec notifiarr nslookup qbittorrent

# Check if container is running
docker ps | grep qbittorrent
```

**Solutions:**

**Solution 1: Container Not on Shared Network**

Most common issue - service installed before auto-connector or from docker-compose.

```bash
# Manually connect to shared network
docker network connect homelab-shared qbittorrent
docker network connect homelab-shared sonarr
docker network connect homelab-shared radarr

# Verify
docker network inspect homelab-shared | grep Name
```

**Solution 2: Wrong Hostname/Port**

When configuring service-to-service communication:

✅ **Correct:**
```
Host: qbittorrent
Port: 8081
URL: http://qbittorrent:8081
```

❌ **Wrong:**
```
Host: qbittorrent.hameed.tech  # Don't use domain names internally
Port: 443                       # Don't use reverse proxy ports
URL: https://qbittorrent.hameed.tech  # Don't use HTTPS internally
```

**Solution 3: Auto-Connector Not Running**

```bash
# Check auto-connector service
sudo systemctl status cosmos-network-connector

# If not running, start it
sudo systemctl start cosmos-network-connector

# If failed to start, check logs
sudo journalctl -u cosmos-network-connector -n 50

# Check auto-connector logs
sudo tail -50 /var/log/cosmos-network-connector.log
```

**Solution 4: Container Name Mismatch**

```bash
# List actual container names
docker ps --format "{{.Names}}"

# Use the exact name shown
# If it shows "Notifiarr-1" instead of "Notifiarr", use that
```

### Problem: Auto-connector not detecting new containers

**Symptoms:**
- Install app from Cosmos market
- App not automatically added to homelab-shared
- No entry in auto-connector logs

**Diagnosis:**
```bash
# Check if auto-connector is running
sudo systemctl is-active cosmos-network-connector

# Watch logs in real-time
sudo tail -f /var/log/cosmos-network-connector.log

# In another terminal, restart a Cosmos app
docker restart Notifiarr

# You should see log entry
```

**Solutions:**

**Solution 1: Service Not Running**
```bash
sudo systemctl start cosmos-network-connector
sudo systemctl enable cosmos-network-connector
```

**Solution 2: Log Permissions**
```bash
# Check if log file exists and is writable
ls -l /var/log/cosmos-network-connector.log

# Fix permissions
sudo touch /var/log/cosmos-network-connector.log
sudo chmod 666 /var/log/cosmos-network-connector.log

# Restart service
sudo systemctl restart cosmos-network-connector
```

**Solution 3: Not a Cosmos Container**

Auto-connector only detects containers with `cosmos-` in their network names.

```bash
# Check container networks
docker inspect container_name | grep -A 10 Networks

# If it's NOT from Cosmos market, manually connect
docker network connect homelab-shared container_name
```

## Installation Issues

### Problem: Notifiarr installation fails with "bind source path does not exist: /var/run/utmp"

**Symptoms:**
- Cosmos market installation fails
- Error message about `/var/run/utmp`
- Installation rolls back automatically

**Solution:**
```bash
# Create the missing file
sudo touch /var/run/utmp
sudo chmod 644 /var/run/utmp

# Retry installation from Cosmos market
```

**Why this happens:**
Notifiarr needs `/var/run/utmp` to track user logins. Not all systems have this file by default.

**Fix in fresh install:**
The install script now creates this file automatically in Step 12.

### Problem: Installation fails during docker compose up

**Symptoms:**
- Error: "network homelab-shared not found"
- Error: "Error response from daemon: network not found"

**Solution:**
```bash
# Create the network manually
docker network create homelab-shared

# Retry installation
docker compose up -d
```

### Problem: Permission denied errors during installation

**Symptoms:**
- "Permission denied" when creating files
- "sudo: no tty present and no askpass program specified"

**Solution:**
```bash
# Ensure script is run with proper permissions
chmod +x install-homelab.sh

# If sudo issues, ensure user is in sudo group
sudo usermod -aG sudo $USER

# Log out and back in for group changes to take effect
```

## Service-Specific Issues

### Cosmos

**Problem: Cosmos won't start**

```bash
# Check logs
docker logs cosmos

# Common issues:
# 1. Port 80/443 already in use
sudo netstat -tlnp | grep -E ':80|:443'

# Kill conflicting process
sudo systemctl stop apache2  # Example
sudo systemctl stop nginx    # Example

# 2. Config corruption
mv cosmos-config cosmos-config.backup
# Reinstall

# 3. Docker socket permission
ls -l /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock  # Temporary fix
```

**Problem: Cosmos routes not working**

**Symptoms:**
- 502 Bad Gateway
- Service works on direct port but not via domain

**Solution:**
1. Check Cosmos route configuration
2. Ensure target is correct: `http://container-name:port`
3. Ensure container is on homelab-shared network
4. Check container logs for startup errors

### n8n

**Problem: n8n shows database connection error**

**Symptoms:**
- n8n won't start
- Logs show "Error: connect ECONNREFUSED postgres:5432"

**Solution:**
```bash
# Check if postgres is running
docker ps | grep postgres

# Check if postgres is healthy
docker inspect postgres | grep -A 5 Health

# Check if n8n can reach postgres
docker exec n8n ping postgres

# Restart postgres first, then n8n
docker restart postgres
sleep 10
docker restart n8n
```

**Problem: n8n workflows not executing**

**Symptoms:**
- Workflows save but don't trigger
- No execution logs

**Solution:**
1. Check if n8n is in production mode
2. Verify webhook URLs are accessible
3. Check n8n execution logs in UI
4. Restart n8n: `docker restart n8n`

### Jellyfin

**Problem: Hardware transcoding not working**

**Symptoms:**
- High CPU usage during playback
- Transcoding errors in logs
- "Failed to open VAAPI device"

**Solution:**
```bash
# Check if /dev/dri exists
ls -l /dev/dri

# Check permissions
sudo chmod -R 777 /dev/dri  # Temporary for testing

# Add user to render/video groups
sudo usermod -aG render,video $(whoami)

# Restart Jellyfin
docker restart jellyfin
```

**Enable in Jellyfin:**
1. Dashboard → Playback → Transcoding
2. Hardware acceleration: VAAPI (or appropriate for your GPU)
3. Save

### Pi-hole

**Problem: Pi-hole blocking too much / not blocking enough**

**Solution:**

**To block more:**
```bash
# Add aggressive blocklists via Pi-hole UI
# Settings → Blocklists → Add:

# Recommended lists:
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://v.firebog.net/hosts/AdguardDNS.txt
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt
```

**To block less:**
1. Pi-hole Admin → Whitelist
2. Add domains you want to allow
3. Examples: Netflix ads, YouTube Premium checks

**Problem: Pi-hole not blocking ads**

**Diagnosis:**
```bash
# Check if device is using Pi-hole
nslookup doubleclick.net

# Should return Pi-hole IP (192.168.1.69), not external IP

# Test blocking
nslookup doubleclick.net 192.168.1.69
# Should return 0.0.0.0 or Pi-hole IP
```

**Solutions:**
1. Ensure device DNS is set to Pi-hole IP
2. Disable browser DNS-over-HTTPS
3. Update Pi-hole gravity: `docker exec pihole pihole -g`
4. Check if domains are whitelisted by mistake

### Portainer

**Problem: Portainer shows "Cannot connect to Docker"**

**Solution:**
```bash
# Check if Docker socket is mounted
docker inspect portainer | grep docker.sock

# Should show:
# /var/run/docker.sock:/var/run/docker.sock:ro

# If missing, recreate container with correct mount
```

## Resource Issues

### Problem: Services crashing with "OOMKilled" (Out of Memory)

**Symptoms:**
- Container exits unexpectedly
- `docker ps -a` shows "Exited (137)"
- System slows down significantly

**Diagnosis:**
```bash
# Check system memory
free -h

# Check Docker memory usage
docker stats --no-stream

# Check container exit reason
docker inspect container_name | grep -A 5 State
```

**Solutions:**

**Solution 1: Increase Memory Limits**

Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 1G  # Increase from 512M
```

**Solution 2: Upgrade System RAM**

If services legitimately need more RAM than you have.

**Solution 3: Reduce Service Load**
- Disable unused services
- Reduce concurrent workflows (n8n)
- Reduce transcoding quality (Jellyfin)

### Problem: Disk full

**Symptoms:**
- Containers fail to start
- Logs show "no space left on device"
- Website uploads fail

**Diagnosis:**
```bash
# Check disk usage
df -h

# Check Docker usage
docker system df

# Find largest directories
sudo du -sh /var/lib/docker/volumes/*
sudo du -sh ./jellyfin-media/*
```

**Solutions:**

**Solution 1: Clean Docker**
```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes (CAREFUL - this deletes data)
docker volume prune

# Clean build cache
docker builder prune
```

**Solution 2: Clean Logs**
```bash
# Limit Docker log size
# Edit /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

# Restart Docker
sudo systemctl restart docker
```

**Solution 3: Move Media**
- Move Jellyfin media to external drive
- Update docker-compose.yml volume mounts
- Restart Jellyfin

## SSL/HTTPS Issues

### Problem: Browser shows "Your connection is not private"

**Symptoms:**
- SSL certificate warning
- NET::ERR_CERT_AUTHORITY_INVALID

**Causes:**
- Using self-signed certificates (expected for LAN-only)
- Let's Encrypt validation failed
- Certificate expired

**Solutions:**

**For self-signed certs (LAN-only):**
1. Click "Advanced"
2. Click "Proceed to site (unsafe)"
3. (Optional) Export Cosmos CA cert and install on devices

**For Let's Encrypt:**
```bash
# Check Cosmos logs for cert renewal issues
docker logs cosmos | grep -i cert

# Common issues:
# - DNS not pointing to your server (if using public DNS)
# - Port 80 not accessible from internet (if using HTTP challenge)
# - Cloudflare proxy enabled (disable for validation)
```

### Problem: Mixed content warnings (HTTP content on HTTPS page)

**Symptoms:**
- Page loads but images/styles missing
- Console shows "Mixed Content" errors

**Solution:**
1. Check service configuration (ensure HTTPS URLs)
2. Enable "Force HTTPS" in Cosmos route settings
3. Check service base URL settings (n8n, Jellyfin, etc.)

## Performance Issues

### Problem: Services responding slowly

**Diagnosis:**
```bash
# Check CPU usage
top
htop  # If installed

# Check container resource usage
docker stats

# Check I/O wait
iostat -x 1
```

**Solutions:**

**High CPU:**
- Check if media is transcoding (Jellyfin)
- Check if workflows are running (n8n)
- Check if backups are running
- Increase CPU limits in docker-compose.yml

**High disk I/O:**
- Move database to SSD
- Reduce logging verbosity
- Stop unnecessary services

**High RAM:**
- Increase swap space
- Reduce memory limits (forces swapping instead of OOM kills)

### Problem: Web UI extremely slow

**Symptoms:**
- Pages take 10+ seconds to load
- Services work via direct IP but slow via domain

**Diagnosis:**
```bash
# Test reverse proxy performance
time curl -k https://jellyfin.hameed.tech

# Test direct access
time curl http://192.168.1.69:8096

# If direct is fast but proxied is slow, issue is Cosmos
```

**Solutions:**
1. Check Cosmos CPU/memory usage: `docker stats cosmos`
2. Reduce Cosmos logging level
3. Check if Cosmos is doing certificate validation on every request
4. Restart Cosmos: `docker restart cosmos`

## Recovery Procedures

### Complete Stack Reset (Nuclear Option)

**When to use:**
- Stack is completely broken
- You want to start fresh
- Testing configuration changes

**WARNING:** This deletes all data except media files.

```bash
# Stop all services
docker compose down

# Remove all containers
docker rm -f $(docker ps -aq)

# Remove all volumes (DESTRUCTIVE)
docker volume rm $(docker volume ls -q | grep homelab-stack)

# Remove networks
docker network rm homelab homelab-shared

# Clean slate
docker system prune -a --volumes

# Reinstall
./install-homelab.sh
```

### Restore from Backup

**Assuming you have backups of:**
- Docker volumes
- Cosmos config directory
- `.env` file

```bash
# Stop services
docker compose down

# Restore volumes
sudo cp -r /backup/docker-volumes/* /var/lib/docker/volumes/

# Restore Cosmos config
cp -r /backup/cosmos-config ./

# Restore environment
cp /backup/.env ./

# Start services
docker compose up -d
```

## Getting Help

### Before Asking for Help

Collect this information:

```bash
# System info
uname -a
docker --version
docker compose version

# Service status
docker compose ps

# Resource usage
free -h && df -h

# Recent logs
docker compose logs --tail=100 > logs.txt

# Network status
docker network ls
docker network inspect homelab-shared > network.txt
```

### Where to Get Help

1. Check this troubleshooting guide
2. Check [GitHub Issues](https://github.com/cph911/homelab-stack/issues)
3. Check service-specific documentation
4. Open a GitHub issue with collected info above

### Useful Debugging Tools

```bash
# Install useful tools
sudo apt install -y htop iotop nethogs ncdu

# Monitor real-time resource usage
htop           # CPU/RAM
iotop          # Disk I/O
nethogs        # Network usage
ncdu           # Disk space usage

# Network debugging
docker exec container_name ping other_container
docker exec container_name curl http://other_container:port
docker exec container_name nslookup other_container

# Check DNS from host
nslookup service.domain.com
dig service.domain.com

# Check ports from host
nc -zv localhost 80
nc -zv localhost 443
```

## Preventive Maintenance

### Weekly Checks
- [ ] Check disk space: `df -h`
- [ ] Check Docker disk usage: `docker system df`
- [ ] Review Cosmos access logs for errors
- [ ] Test backups restoration

### Monthly Checks
- [ ] Update services: `docker compose pull && docker compose up -d`
- [ ] Clean unused images: `docker image prune`
- [ ] Review auto-connector logs for issues
- [ ] Test all critical services

### Quarterly Checks
- [ ] Full system backup
- [ ] Security audit (check exposed services)
- [ ] Review and update documentation
- [ ] Test disaster recovery procedure
