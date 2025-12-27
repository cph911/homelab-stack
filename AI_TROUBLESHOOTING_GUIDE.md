# AI Assistant Troubleshooting Guide for Homelab Stack Installation

This guide is designed to help AI assistants troubleshoot common issues during homelab stack installation when they cannot modify the installer script directly. Use this as a reference when helping users resolve installation problems.

---

## Table of Contents

1. [Prerequisites Issues](#prerequisites-issues)
2. [Docker Installation & Configuration](#docker-installation--configuration)
3. [Traefik Version Compatibility](#traefik-version-compatibility)
4. [Network & DNS Configuration](#network--dns-configuration)
5. [SSL Certificate Issues](#ssl-certificate-issues)
6. [Service Access Problems](#service-access-problems)
7. [VMware/VirtualBox Network Configuration](#vmwarevirtualbox-network-configuration)
8. [Remote Access Setup](#remote-access-setup)

---

## Prerequisites Issues

### Missing curl, git, or wget

**Symptoms:**
- `bash: curl: command not found`
- `bash: git: command not found`

**Solution:**
```bash
# Install all essential tools at once
sudo apt update
sudo apt install -y git curl wget ca-certificates gnupg

# Verify installation
git --version
curl --version
wget --version
```

**Why this happens:** Minimal Debian/Ubuntu installations don't include these tools by default.

---

### Missing Docker

**Symptoms:**
- Installer fails with "Docker not installed"
- `docker: command not found`

**Solution - Option 1 (Quick):**
```bash
# Install Docker using official script
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify
docker --version
docker compose version
```

**Solution - Option 2 (Manual, if curl fails):**
```bash
# Update package index
sudo apt update

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates gnupg

# Add Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO- https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
```

---

### Docker Daemon Not Running

**Symptoms:**
- "Docker daemon not running!"
- `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Verify Docker is running
sudo systemctl status docker

# If still issues, check logs
sudo journalctl -u docker -n 50
```

---

### Docker Permission Denied

**Symptoms:**
- `permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes (choose one):
# Option 1: Use newgrp in current session
newgrp docker

# Option 2: Log out and log back in

# Option 3: Use sudo for Docker commands temporarily
sudo docker compose ps
```

**Important:** After adding user to docker group, the user MUST either logout/login OR use `newgrp docker` in each terminal session.

---

## Docker Installation & Configuration

### Services Fail to Start Initially

**Symptoms:**
- "Critical services not running: traefik postgres n8n jellyfin"
- Services show as "unhealthy" or "restarting"

**Diagnostic Steps:**
```bash
cd ~/homelab-stack

# Check container status
sudo docker compose ps

# Check logs for specific service
sudo docker compose logs traefik --tail=50
sudo docker compose logs postgres --tail=50
sudo docker compose logs n8n --tail=50

# Check resource usage
sudo docker stats --no-stream
```

**Common Solutions:**

1. **Wait for services to initialize:**
   - PostgreSQL needs 10-15 seconds to initialize
   - n8n waits for PostgreSQL to be healthy
   - Give it 30-60 seconds, then check again

2. **Restart services:**
   ```bash
   sudo docker compose restart
   # Or full restart:
   sudo docker compose down
   sudo docker compose up -d
   ```

3. **Check resource limits:**
   - Ensure server has enough RAM for the selected profile
   - Check: `free -h`
   - Containers may be OOM-killed if limits are too high

---

## Traefik Version Compatibility

### CRITICAL ISSUE: Traefik v3.x Docker API Incompatibility

**Symptoms:**
- Traefik logs show: `ERR Failed to retrieve information of the docker client and server host error="Error response from daemon: client version 1.24 is too old. Minimum supported API version is 1.44"`
- 404 errors when accessing services
- Services work locally but not through Traefik

**Root Cause:**
Traefik v3.0 and v3.2 have a Docker API version compatibility bug where they default to API version 1.24, but modern Docker requires 1.44+.

**Solution: Downgrade to Traefik v2.11**

**Step 1: Check Docker API version**
```bash
docker version --format '{{.Server.APIVersion}}'
# Should show 1.44 or higher
```

**Step 2: Edit docker-compose.yml**
```bash
cd ~/homelab-stack
nano docker-compose.yml
```

Find the traefik service and make these changes:

**Change FROM:**
```yaml
  traefik:
    image: traefik:v3.0  # or v3.2
```

**Change TO:**
```yaml
  traefik:
    image: traefik:v2.11
```

**Also add this command (if not present):**
```yaml
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=homelab"  # ADD THIS LINE
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${SSL_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--log.level=INFO"
```

**Optionally add environment variable:**
```yaml
    environment:
      - DOCKER_API_VERSION=1.44
```

**Step 3: Apply changes**
```bash
sudo docker compose down
sudo docker compose pull traefik
sudo docker compose up -d
```

**Step 4: Verify**
```bash
# Check Traefik logs - should NOT see API version errors
sudo docker compose logs traefik --tail=30

# Should see successful Docker provider startup
# Should NOT see "client version 1.24 is too old" errors
```

**Why Traefik v2.11 instead of v3.x:**
- Traefik v2.11 is the last stable v2 release
- Better Docker API version negotiation
- Well-tested and production-ready
- All features needed for this stack are available

---

## Network & DNS Configuration

### Finding Server IP Address

**For VPS/Cloud Servers:**
```bash
# Find public IP
curl ifconfig.me

# Alternative methods
curl icanhazip.com
wget -qO- ifconfig.me
```

**For Home/Local Servers:**
```bash
# Find local IP
ip addr show | grep 'inet '
# Look for IP like 192.168.x.x or 10.x.x.x

# Find public IP (for DNS records)
curl ifconfig.me
# Or visit https://whatismyip.com in browser
```

**Important distinction:**
- **Local/Private IP** (192.168.x.x, 10.x.x.x): For accessing within local network
- **Public IP**: For DNS records and internet access

---

### DNS Configuration Requirements

**CRITICAL for SSL Certificates:**

DNS records MUST point to your **public IP**, NOT local IPs.

**Required A Records:**
```
n8n.yourdomain.com        →  YOUR_PUBLIC_IP
jellyfin.yourdomain.com   →  YOUR_PUBLIC_IP
portainer.yourdomain.com  →  YOUR_PUBLIC_IP (if installing)
uptime.yourdomain.com     →  YOUR_PUBLIC_IP (if installing)
```

**For Cloudflare Users - CRITICAL:**
- **Turn OFF the orange cloud** (Proxied status)
- Must be **gray cloud** (DNS only)
- Let's Encrypt requires direct access to verify domain ownership
- Traefik handles SSL, not Cloudflare proxy

**Verify DNS Propagation:**
```bash
# Install dig if needed
sudo apt install -y dnsutils

# Check DNS resolution
dig n8n.yourdomain.com +short
nslookup n8n.yourdomain.com

# Should return YOUR_PUBLIC_IP, not local IP
```

---

### Port Forwarding for Home Networks

**REQUIRED for home servers to work with SSL:**

If your server is behind a router (home network), you MUST configure port forwarding:

**Router Configuration:**
1. Log into router admin panel (usually 192.168.1.1 or 192.168.0.1)
2. Find "Port Forwarding" or "Virtual Server" section
3. Add these rules:

| Service | External Port | Internal IP | Internal Port | Protocol |
|---------|---------------|-------------|---------------|----------|
| HTTP | 80 | [SERVER_LOCAL_IP] | 80 | TCP |
| HTTPS | 443 | [SERVER_LOCAL_IP] | 443 | TCP |

**Example:**
- External Port: 80 → Internal IP: 192.168.1.100, Port: 80
- External Port: 443 → Internal IP: 192.168.1.100, Port: 443

**Without port forwarding:**
- Let's Encrypt cannot verify domain ownership
- SSL certificates will fail
- Services only accessible locally

**Test port forwarding:**
```bash
# From an external network (mobile data, different location)
curl http://yourdomain.com
curl https://yourdomain.com
```

---

### Geolocation Accuracy (NOT an Issue)

**User concern:** "The IP lookup shows wrong city (Riyadh instead of Jeddah)"

**Important:** IP geolocation is **approximate** and does NOT affect networking, DNS, or services.

**Why this happens:**
- IP geolocation is based on ISP registration data
- ISP headquarters might be in different city
- Normal and expected behavior

**This does NOT affect:**
- Network connectivity ✅
- DNS resolution ✅
- Port forwarding ✅
- Service functionality ✅

**Action:** Ignore geolocation discrepancies - they are normal and harmless.

---

## SSL Certificate Issues

### SSL Certificates Fail to Generate

**Symptoms:**
- Services accessible via HTTP but not HTTPS
- Browser shows "connection refused" on HTTPS
- Traefik logs show Let's Encrypt errors

**Diagnostic:**
```bash
# Check Traefik logs for ACME errors
sudo docker compose logs traefik | grep -i acme
sudo docker compose logs traefik | grep -i letsencrypt
```

**Common Causes & Solutions:**

**1. Port forwarding not configured (most common)**
- Solution: Configure router port forwarding for ports 80 and 443
- See "Port Forwarding for Home Networks" section above

**2. DNS not configured correctly**
```bash
# Verify DNS points to public IP
dig n8n.yourdomain.com +short
# Should return your PUBLIC IP, not 192.168.x.x
```

**3. Cloudflare proxy enabled (orange cloud)**
- Solution: Disable Cloudflare proxy (turn orange cloud to gray)
- Let's Encrypt needs direct access

**4. Rate limiting from Let's Encrypt**
- Let's Encrypt has rate limits: 5 failures per hour, 50 certs per week
- Solution: Wait 1 hour before retrying
- Check: https://letsencrypt.org/docs/rate-limits/

---

### Local Testing Without SSL (Workaround)

**If port forwarding cannot be configured immediately:**

**Option 1: Edit hosts file for local access**

**On Linux/Mac:**
```bash
sudo nano /etc/hosts

# Add these lines (replace with your server's LOCAL IP):
192.168.1.100  n8n.yourdomain.com
192.168.1.100  jellyfin.yourdomain.com
192.168.1.100  portainer.yourdomain.com
```

**On Windows:**
1. Open Notepad as Administrator
2. Open: `C:\Windows\System32\drivers\etc\hosts`
3. Add the same lines as above

**Then access via browser:**
- `http://n8n.yourdomain.com` (redirects to HTTPS)
- Accept SSL certificate warnings in browser
- Click "Advanced" → "Proceed anyway"

**Option 2: Access directly via IP**
```
http://YOUR_LOCAL_IP
```
- Will show 404 (expected - Traefik routes by hostname)
- Not useful for accessing services

**Option 3: Temporarily disable HTTPS redirect**
- Edit docker-compose.yml
- Comment out these lines in Traefik command:
  ```yaml
  # - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
  # - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
  ```
- Restart: `sudo docker compose restart traefik`
- Access via `http://n8n.yourdomain.com` (no SSL)

**Important:** Options 2 and 3 are NOT recommended for production.

---

### SSL Certificate Warnings on Local Access

**Symptoms:**
- Browser shows "Your connection is not private"
- `ERR_CERT_AUTHORITY_INVALID`
- Services load but SSL warning appears

**Why this happens:**
- Using hosts file to point domain to local IP
- SSL certificate was issued for public domain
- Certificate doesn't match local IP access

**Solution:**
This is **expected and safe** for local testing.

**To proceed:**
1. Click "Advanced" or "Show Details"
2. Click "Proceed to [domain] (unsafe)" or "Accept the Risk"
3. Service will load normally

**For permanent fix:**
- Configure proper port forwarding
- Let Let's Encrypt issue valid certificates for public access

---

## Service Access Problems

### 404 Page Not Found

**Symptoms:**
- Browser shows "404 page not found"
- Accessing `http://n8n.yourdomain.com` shows 404
- Accessing `http://192.168.x.x` shows 404

**Diagnostic:**
```bash
# Check if containers are running
sudo docker compose ps

# Check Traefik routing
sudo docker compose logs traefik --tail=50

# Look for router registration messages
sudo docker compose logs traefik | grep -i router
```

**Common Causes:**

**1. Traefik cannot discover Docker containers**
- Usually due to Docker API version issue
- See "Traefik Version Compatibility" section
- Solution: Downgrade to Traefik v2.11

**2. Wrong domain name in .env file**
```bash
# Check DOMAIN_NAME
grep DOMAIN_NAME .env
# Should match your actual domain (e.g., hameed.tech)

# If wrong, edit .env:
nano .env
# Change DOMAIN_NAME=yourdomain.com
# Save and restart:
sudo docker compose restart
```

**3. Accessing via IP instead of domain**
- Traefik routes based on hostnames, not IPs
- Accessing `http://192.168.1.100` → 404 (expected)
- Must access via domain: `http://n8n.yourdomain.com`

**4. DNS not resolving correctly**
```bash
# Test DNS resolution
ping n8n.yourdomain.com
# Should resolve to correct IP

# If not, check hosts file or DNS records
```

---

### n8n Shows "Can't connect" or "Problem setting up owner"

**Symptoms:**
- n8n frontend loads
- Shows "Can't connect to n8n" error
- Cannot create owner account
- Browser console shows API errors

**Diagnostic:**
```bash
# Check n8n logs
sudo docker compose logs n8n --tail=50

# Check n8n status
sudo docker compose ps n8n

# Test n8n backend from server
curl -H "Host: n8n.yourdomain.com" http://localhost
# Should get "Moved Permanently" (redirect to HTTPS)
```

**Common Causes:**

**1. SSL certificate issues blocking API calls**
- Browser blocks HTTPS connections due to invalid cert
- See "SSL Certificate Issues" section
- Solution: Accept certificate in browser

**2. Browser cache/DNS cache**
```bash
# On Mac:
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# On Windows (as Administrator):
ipconfig /flushdns
```

- Clear browser cache or use incognito mode

**3. Traefik routing not working**
- Check Traefik logs for errors
- Ensure Traefik v2.11 is being used

---

### Portainer Timeout Error

**Symptoms:**
- Portainer shows: "Your Portainer instance timed out for security purposes"
- "Unable to create administrator user"

**Cause:**
Portainer has a 5-minute security timeout after initial installation.

**Solution:**
```bash
# Restart Portainer
sudo docker compose restart portainer

# Then IMMEDIATELY (within 5 minutes):
# Access https://portainer.yourdomain.com
# Create admin account with 12+ character password
```

**Password Requirements:**
- Minimum 12 characters
- Mix of upper/lowercase, numbers, symbols
- Example: `MySecure2025!Pass`

**If creating admin fails:**
```bash
# Check Portainer logs
sudo docker compose logs portainer --tail=30

# If no errors in logs, issue is likely:
# - Password too short (< 12 chars)
# - SSL certificate blocking submission
# - Browser JavaScript errors (check Console)
```

---

### Cannot Access Traefik Dashboard

**Symptoms:**
- `http://SERVER_IP:8080` shows "connection refused"
- ERR_CONNECTION_REFUSED

**Common Causes:**

**1. Traefik API not in insecure mode**

The dashboard on port 8080 requires insecure mode for direct access.

**Solution:**
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Find traefik command section, add:
- "--api.insecure=true"

# Restart Traefik
sudo docker compose restart traefik
```

**2. Port 8080 blocked by firewall**
```bash
# Check if port is listening
sudo ss -tulpn | grep 8080

# If using ufw, allow port:
sudo ufw allow 8080/tcp

# If using iptables:
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

**3. Network connectivity issue**
- See "VMware/VirtualBox Network Configuration" section

---

## VMware/VirtualBox Network Configuration

### CRITICAL: NAT vs Bridged Networking

This is one of the **most common issues** for VM-based installations.

**Problem Scenario:**
- User running homelab stack in VMware/VirtualBox on Machine A (e.g., Windows PC)
- User trying to access from Machine B (e.g., Mac laptop)
- Connection fails: "Request timeout", "Cannot reach"

**Root Cause:**
VM is in **NAT mode**, giving it a VM-only IP (like 192.168.154.128) that's only accessible from the host machine.

**Solution: Change to Bridged Networking**

### VMware Workstation/Fusion:

**Step 1: Shut down VM**
```bash
# In VM terminal:
sudo shutdown -h now
```

**Step 2: Change network mode**
1. In VMware, right-click VM → **Settings**
2. Click **"Network Adapter"**
3. Change from **"NAT"** to **"Bridged"**
4. ✅ Check **"Replicate physical network connection state"**
5. Click **OK**

**Step 3: Start VM and get new IP**
```bash
# Start VM, then check new IP:
ip addr show | grep 'inet '

# Look for an IP like 192.168.1.x or 192.168.0.x
# Example: 192.168.1.39
```

**Step 4: Update hosts files on all client machines**

On **each machine** that needs to access the services:

**Mac/Linux:**
```bash
sudo nano /etc/hosts

# Update IP (example):
192.168.1.39  n8n.yourdomain.com
192.168.1.39  jellyfin.yourdomain.com
192.168.1.39  portainer.yourdomain.com

# Save and flush DNS:
sudo dscacheutil -flushcache  # Mac
sudo systemctl restart systemd-resolved  # Linux
```

**Windows:**
```
# Open Notepad as Administrator
# Open: C:\Windows\System32\drivers\etc\hosts
# Update IPs as above
# Save

# Flush DNS (Command Prompt as Admin):
ipconfig /flushdns
```

**Step 5: Test connectivity**
```bash
# From client machine:
ping 192.168.1.39
# Should get responses

# Test services:
curl -I http://192.168.1.39
# Should get HTTP redirect response
```

### VirtualBox:

**Step 1-2: Change network mode**
1. Select VM → **Settings** → **Network**
2. Change **"Attached to"** from **NAT** to **Bridged Adapter**
3. Select your physical network adapter
4. Click **OK**

**Step 3-5:** Same as VMware above

---

### Understanding VM Network Modes

**NAT Mode:**
- VM IP: 192.168.122.x, 192.168.154.x (hypervisor-specific)
- ✅ VM can access internet
- ✅ VM accessible from host machine
- ❌ VM NOT accessible from other machines
- **Use case:** Testing, isolated development

**Bridged Mode:**
- VM IP: Same network as physical machine (192.168.1.x, 192.168.0.x)
- ✅ VM can access internet
- ✅ VM accessible from host machine
- ✅ VM accessible from ANY machine on network
- **Use case:** Homelab, servers, multi-device access

**For homelab stack:** **Always use Bridged Mode** if accessing from multiple devices.

---

## Remote Access Setup

### SSH Access

**From Mac/Linux:**
```bash
ssh username@SERVER_IP

# Example:
ssh h1234@192.168.1.39
```

**From Windows:**
- Use PowerShell: `ssh username@SERVER_IP`
- Or use PuTTY

**If SSH connection refused:**
```bash
# On server, check if SSH is running:
sudo systemctl status ssh

# If not running, start it:
sudo systemctl start ssh
sudo systemctl enable ssh

# Check if port 22 is open:
sudo ss -tulpn | grep :22
```

---

### Remote Desktop (RDP) Access to GUI

**Installing Desktop Environment:**

If you want GUI access to the Debian server:

**Step 1: Install desktop environment**
```bash
# SSH into server first
ssh username@SERVER_IP

# Install XFCE desktop (lightweight)
sudo apt update
sudo apt install -y xfce4 xfce4-goodies

# During installation, select 'lightdm' as display manager
```

**Step 2: Install xrdp**
```bash
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Verify it's running:
sudo systemctl status xrdp
```

**Step 3: Connect from client**

**Mac:**
1. Install "Microsoft Remote Desktop" from App Store
2. Add PC → Enter server IP
3. Add credentials (username/password)
4. Connect

**Windows:**
1. Open "Remote Desktop Connection"
2. Enter server IP
3. Enter credentials
4. Connect

**Linux:**
```bash
# Install Remmina
sudo apt install remmina

# Or use rdesktop:
rdesktop SERVER_IP
```

**Common RDP Issues:**

**1. Connection refused (most common with VMs)**
- See "VMware/VirtualBox Network Configuration"
- Change from NAT to Bridged mode

**2. Authentication failed**
- Ensure username and password are correct
- xrdp uses system user credentials

**3. Black screen after connecting**
```bash
# On server, edit xrdp config:
sudo nano /etc/xrdp/startwm.sh

# Add these lines before the last line:
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

# Restart xrdp:
sudo systemctl restart xrdp
```

---

## Comprehensive Diagnostic Commands

When troubleshooting, run these commands to gather information:

### System Information
```bash
# OS version
cat /etc/os-release

# Kernel version
uname -a

# Available RAM
free -h

# Disk space
df -h

# CPU info
lscpu | grep -E 'Model name|CPU\(s\)'
```

### Docker Status
```bash
# Docker version
docker --version
docker compose version

# Docker API version
docker version --format '{{.Server.APIVersion}}'

# All containers
sudo docker compose ps

# Container resource usage
sudo docker stats --no-stream

# All Docker networks
docker network ls

# Inspect homelab network
docker network inspect homelab-stack_homelab
```

### Service Logs
```bash
# All service logs (last 50 lines)
sudo docker compose logs --tail=50

# Specific service logs
sudo docker compose logs traefik --tail=100
sudo docker compose logs postgres --tail=50
sudo docker compose logs n8n --tail=50
sudo docker compose logs jellyfin --tail=50
sudo docker compose logs portainer --tail=50

# Follow logs in real-time
sudo docker compose logs -f traefik
```

### Network Diagnostics
```bash
# Server IP address
ip addr show

# Check listening ports
sudo ss -tulpn | grep -E ':80|:443|:3389|:5432|:8080'

# Check if Traefik is listening
sudo ss -tulpn | grep :443

# Test localhost connectivity
curl -I http://localhost
curl -k -I https://localhost

# Test with hostname header
curl -H "Host: n8n.yourdomain.com" http://localhost

# DNS resolution (if dnsutils installed)
nslookup n8n.yourdomain.com
dig n8n.yourdomain.com +short
```

### Configuration Files
```bash
# Check domain configuration
cat .env | grep DOMAIN_NAME

# Check Docker Compose config
cat docker-compose.yml | grep -A 5 "image: traefik"

# Verify Traefik version
sudo docker compose config | grep "image: traefik"

# Check environment variables
sudo docker compose config | grep -A 10 "environment:"
```

---

## Common Error Messages & Solutions

### "Critical services not running: traefik postgres n8n jellyfin"

**Cause:** Services failed to start on initial installation

**Solution:**
```bash
# Wait 60 seconds for initialization
sleep 60

# Check again
sudo docker compose ps

# If still failing, check logs:
sudo docker compose logs --tail=100

# Restart services:
sudo docker compose restart

# Or full restart:
sudo docker compose down
sudo docker compose up -d
```

---

### "ERR client version 1.24 is too old. Minimum supported API version is 1.44"

**Cause:** Traefik v3.x Docker API incompatibility

**Solution:** See "Traefik Version Compatibility" section - downgrade to v2.11

---

### "Unable to connect - Error code: 0x204" (RDP)

**Cause:** Network connectivity issue, usually NAT vs Bridged

**Solution:** See "VMware/VirtualBox Network Configuration" section

---

### "This site can't be reached" / "ERR_CONNECTION_REFUSED"

**Cause:** Network connectivity or DNS resolution issue

**Diagnostic:**
```bash
# Test from client machine:
ping SERVER_IP
# If fails: network connectivity issue

ping n8n.yourdomain.com
# If fails: DNS/hosts file issue

# Test port:
telnet SERVER_IP 443
# or
nc -zv SERVER_IP 443
```

**Solutions:**
1. Check VM network mode (NAT vs Bridged)
2. Check firewall rules
3. Verify DNS/hosts file configuration
4. Check if services are actually running

---

### "Request timeout for icmp_seq"

**Cause:** Cannot reach server IP (network issue)

**For VMs:** See "VMware/VirtualBox Network Configuration"

**For physical servers:**
```bash
# Check if firewall is blocking:
# On server:
sudo ufw status
# If active, allow from client IP:
sudo ufw allow from CLIENT_IP

# Or disable temporarily for testing:
sudo ufw disable
```

---

## Final Checklist for Working Installation

Use this checklist to verify everything is working:

### ✅ Prerequisites
- [ ] Docker installed and running
- [ ] Docker Compose v2+ installed
- [ ] User added to docker group
- [ ] Can run `docker ps` without sudo

### ✅ Services Running
- [ ] All containers show "Up" status: `sudo docker compose ps`
- [ ] Traefik shows "Up" and no API version errors
- [ ] PostgreSQL shows "healthy"
- [ ] n8n shows "Up"
- [ ] Jellyfin shows "healthy"
- [ ] Portainer shows "Up"

### ✅ Traefik Configuration
- [ ] Using Traefik v2.11 (not v3.x)
- [ ] No "client version 1.24" errors in logs
- [ ] Traefik logs show successful Docker provider connection
- [ ] Traefik logs show router registrations

### ✅ Network Configuration
- [ ] Server has correct IP (bridged for VMs)
- [ ] Can ping server from client machines
- [ ] Ports 80, 443 are open and listening
- [ ] For home networks: Port forwarding configured

### ✅ DNS Configuration
- [ ] DNS A records created (or hosts file edited)
- [ ] DNS resolves to correct IP
- [ ] For Cloudflare: Orange cloud disabled (gray cloud)

### ✅ Service Access
- [ ] Can access `http://n8n.yourdomain.com` (redirects to HTTPS)
- [ ] Can access `https://n8n.yourdomain.com` (may need to accept cert)
- [ ] n8n owner account created successfully
- [ ] Can access `https://portainer.yourdomain.com`
- [ ] Portainer admin account created
- [ ] Can access `https://jellyfin.yourdomain.com`

### ✅ Remote Access (if needed)
- [ ] Can SSH to server: `ssh username@SERVER_IP`
- [ ] Can RDP to server (if desktop installed)
- [ ] Can access services from multiple devices

---

## When to Give Up and Start Fresh

Sometimes it's better to start with a clean installation:

**Indicators:**
- Multiple failed troubleshooting attempts
- Corrupted Docker volumes
- Conflicting configurations
- User is confused and overwhelmed

**Clean restart procedure:**
```bash
# Navigate to directory
cd ~/homelab-stack

# Stop and remove everything
sudo docker compose down -v
# -v flag removes volumes (destroys all data!)

# Remove the directory
cd ~
sudo rm -rf homelab-stack

# Start fresh:
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack
chmod +x install-homelab.sh
./install-homelab.sh
```

**What this preserves:**
- Nothing - complete fresh start

**What this destroys:**
- All n8n workflows
- All Portainer configurations
- All Jellyfin libraries
- All PostgreSQL data

**Before doing this:**
- Backup `.env` file if user wants to keep passwords
- Backup any important n8n workflows
- Warn user about data loss

---

## AI Assistant Best Practices

When helping users troubleshoot:

1. **Start with basics:**
   - Check if containers are running
   - Check logs for obvious errors
   - Verify prerequisites are installed

2. **One issue at a time:**
   - Don't overwhelm user with multiple solutions
   - Fix most critical issue first (usually Traefik/Docker)
   - Test after each change

3. **Gather diagnostic information:**
   - Always ask for logs when debugging
   - Use the comprehensive diagnostic commands
   - Understand the user's network setup (VM vs physical, home vs VPS)

4. **Be explicit with commands:**
   - Provide complete commands, not fragments
   - Explain what each command does
   - Warn before destructive operations

5. **Document changes:**
   - Keep track of what was modified
   - Help user understand why changes were needed
   - Suggest documenting in notes for future reference

6. **Know when to escalate:**
   - Some issues are beyond AI assistance
   - Suggest GitHub issues for bugs
   - Recommend fresh install when appropriate

7. **Explain, don't just fix:**
   - Help user understand the root cause
   - Explain the "why" behind solutions
   - Build user's knowledge for future troubleshooting

---

## Additional Resources

**Official Documentation:**
- Docker: https://docs.docker.com/
- Traefik v2.11: https://doc.traefik.io/traefik/v2.11/
- n8n: https://docs.n8n.io/
- Jellyfin: https://jellyfin.org/docs/
- Portainer: https://docs.portainer.io/

**Troubleshooting Tools:**
- Traefik API: `http://SERVER_IP:8080` (if insecure mode enabled)
- Portainer: `https://portainer.yourdomain.com` (visual container management)
- Docker logs: `sudo docker compose logs [service]`

**Network Testing:**
- Can I use ping: https://caniuse.ping.eu/
- Port checker: https://www.yougetsignal.com/tools/open-ports/
- DNS checker: https://dnschecker.org/

---

## Version History

**v1.0 - 2025-12-27**
- Initial comprehensive troubleshooting guide
- Covers common installation issues
- Includes Traefik v3.x compatibility solution
- VMware/VirtualBox networking guide
- Remote access setup instructions

---

## Contributing

This guide is based on real-world troubleshooting sessions. If you encounter issues not covered here:

1. Document the issue thoroughly
2. Include diagnostic commands and their output
3. Document the solution that worked
4. Submit a PR or issue to add it to this guide

---

**End of AI Troubleshooting Guide**
