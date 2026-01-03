# Security

This document explains the security model of the homelab stack, what it protects against, and what you're still responsible for.

## Threat Model

This stack is designed for **trusted home networks** with **optional secure remote access**.

### What This Is
- A home server running media and automation services
- Accessed primarily from your LAN
- Optionally accessible remotely via Cloudflare Tunnel or Tailscale VPN
- Run by one person or trusted household members

### What This Is NOT
- A multi-tenant platform (no user isolation)
- An internet-facing public service
- A high-security production environment
- Protected against physical access attacks

## Security Boundaries

### Layer 1: Network Perimeter

**LAN-only mode (default):**
- Services only accessible from local network
- Router firewall blocks ports 80/443 from internet
- DNS resolution via Pi-hole or /etc/hosts (no public DNS)

**Remote access mode (optional):**
- Cloudflare Tunnel: Traffic encrypted from Cloudflare edge → your server
- Tailscale VPN: End-to-end encrypted, peer-to-peer when possible
- **Never** open ports 80/443 directly to internet (no port forwarding)

### Layer 2: Reverse Proxy (Cosmos)

**What Cosmos protects:**
- ✅ SSL/TLS termination (encrypted traffic)
- ✅ Single entry point for all services
- ✅ Centralized access control (can require auth per route)
- ✅ Automatic HTTP → HTTPS redirect
- ✅ Rate limiting (prevents brute force)

**What Cosmos does NOT protect:**
- ❌ Services you misconfigure as "public" without authentication
- ❌ Weak passwords (it enforces nothing by default)
- ❌ Container vulnerabilities (outdated images)
- ❌ Data breaches if someone gains host access

### Layer 3: Container Isolation

**What Docker provides:**
- Process isolation (containers can't see each other's processes)
- Filesystem isolation (separate filesystems per container)
- Resource limits (memory/CPU caps prevent DoS)

**What Docker does NOT provide:**
- Network isolation between containers on same network (by design)
- Protection against malicious images (you must trust image sources)
- Kernel-level security (containers share host kernel)

### Layer 4: Application Security

**This is YOUR responsibility:**
- Strong passwords for each service
- Keeping services updated
- Reviewing what you install from Cosmos market
- Not exposing admin panels to internet
- Regular backups

## Attack Scenarios

### Scenario 1: Attacker on Your LAN

**Risk Level:** High

**Attack Surface:**
- All services accessible without authentication (if misconfigured)
- Docker socket accessible to containers (by design for Cosmos/Portainer)
- Physical access to server possible

**Mitigations:**
- Require authentication on all Cosmos routes
- Use strong Wi-Fi password (WPA3)
- Enable guest network isolation
- Keep untrusted devices off main network
- Physical security (locked server room/closet)

**What the stack won't save you from:**
- Compromised device on your network
- Someone with your Wi-Fi password
- Physical access to the server

### Scenario 2: Internet-Exposed Service

**Risk Level:** Critical (if misconfigured)

**Attack Surface:**
- Any service accessible via Cloudflare Tunnel or port forwarding
- Password brute force attacks
- Unpatched service vulnerabilities
- Zero-day exploits in services

**Mitigations:**
- Use Cloudflare Tunnel or Tailscale (never direct port forwarding)
- Enable Cloudflare Access or Tailscale ACLs
- Use strong, unique passwords per service
- Enable MFA where supported (Portainer, n8n, etc.)
- Keep services updated
- Monitor access logs

**What the stack won't save you from:**
- Services you intentionally expose without auth
- Exploits in the services themselves
- Compromised credentials

### Scenario 3: Malicious Docker Image

**Risk Level:** Medium

**Attack Surface:**
- Images from Cosmos market (trusted but verify)
- Community images from Docker Hub
- Malicious image could access Docker socket

**Mitigations:**
- Only install images from trusted sources
- Review Cosmos market app descriptions
- Check Docker Hub pull counts and user reviews
- Audit images before installing: `docker inspect imagename`
- Don't give containers unnecessary privileges

**What the stack won't save you from:**
- Supply chain attacks on popular images
- Backdoors in trusted images
- Social engineering ("install this cool app!")

### Scenario 4: Compromised Container

**Risk Level:** Medium

**Attack Surface:**
- Container escape to host (rare but possible)
- Lateral movement to other containers via `homelab-shared` network
- Data exfiltration via internet

**Mitigations:**
- Keep host OS updated (security patches)
- Don't run containers as root when possible
- Limit container capabilities
- Monitor outbound network traffic
- Regular security updates for all services

**What the stack won't save you from:**
- Kernel exploits (containers share kernel)
- Zero-day container escape vulnerabilities
- Compromised containers talking to each other (they're on same network)

## Authentication Strategy

### Password Requirements

**Minimum standards:**
- 16+ characters
- Random (use a password manager)
- Unique per service (don't reuse)

**Services requiring strong passwords:**
- Cosmos admin panel (protects entire stack)
- Portainer (controls Docker)
- n8n (executes arbitrary code)
- Pi-hole (controls DNS)

**Services where it matters less:**
- Jellyfin (media only, no system access)
- Uptime Kuma (read-only monitoring)

### Multi-Factor Authentication (MFA)

**Supported by:**
- Portainer ✅
- n8n ✅ (via LDAP or OAuth)
- Cosmos ✅ (via OAuth or 2FA apps)

**Not supported by:**
- Jellyfin ❌ (use reverse proxy auth instead)
- Pi-hole ❌ (protect with Cosmos auth)

### Single Sign-On (SSO)

Cosmos supports OAuth2 providers:
- Google
- GitHub
- Self-hosted (Keycloak, Authentik)

**Benefit:** One strong password + MFA protects everything

**Setup:** See Cosmos documentation for OAuth configuration

## Secrets Management

### How Secrets Are Stored

**Environment variables in `.env` file:**
```bash
POSTGRES_PASSWORD=your-random-password-here
PIHOLE_PASSWORD=another-random-password
```

**Why this is acceptable for homelabs:**
- File permissions restrict access (readable by docker user only)
- Not committed to git (in `.gitignore`)
- Simple to backup and restore
- No additional infrastructure needed

**Why this is NOT acceptable for production:**
- Secrets visible in `docker inspect`
- No encryption at rest
- No secret rotation
- No audit trail

### Better Secrets Management (Optional)

If you want production-grade secrets:

**Docker Secrets:**
```bash
echo "my-secret" | docker secret create postgres_password -
```

**External secret stores:**
- HashiCorp Vault
- AWS Secrets Manager (via LocalStack)
- Bitwarden (self-hosted)

**Trade-off:** Adds complexity for minimal benefit in a trusted home environment.

## Network Security

### Firewall Rules (Recommended)

**On your router:**
```
DENY all incoming from WAN
ALLOW all outgoing to internet
ALLOW Tailscale/Cloudflare if using remote access
```

**On the server (UFW example):**
```bash
# Default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change 22 to your SSH port)
sudo ufw allow 22/tcp

# Allow from LAN only (adjust subnet)
sudo ufw allow from 192.168.1.0/24

# Enable firewall
sudo ufw enable
```

### Port Exposure

**Ports that MUST be exposed on LAN:**
- 80/443 - Cosmos reverse proxy (HTTP/HTTPS)
- 53 - Pi-hole DNS (if installed)

**Ports you MAY expose on LAN:**
- 8096 - Jellyfin (if you want direct access)
- 5678 - n8n (if you want direct access)
- 9000 - Portainer (if you want direct access)

**Ports that should NEVER be exposed to internet:**
- 2375/2376 - Docker API (full system control)
- 5432 - PostgreSQL (database)
- 6379 - Redis (cache)

**Best practice:** Access everything via Cosmos reverse proxy (ports 80/443 only).

## SSL/TLS

### Certificate Options

**Let's Encrypt (recommended for remote access):**
- Free, automatic renewal
- Requires public DNS or Cloudflare
- 90-day expiry (auto-renews via Cosmos)

**Self-signed (recommended for LAN-only):**
- Works without internet
- Browser warnings (can install CA cert to avoid)
- No external dependencies

**Cloudflare Origin Certificates:**
- Use with Cloudflare Tunnel
- 15-year validity
- Trusted by Cloudflare edge (not browsers directly)

### Certificate Storage

Cosmos stores certificates in:
```
./cosmos-config/certs/
```

**Backup this directory** - losing certs breaks HTTPS access.

## Container Security Best Practices

### Images

- ✅ Use official images when available
- ✅ Pin versions (`jellyfin:10.8.13` not `jellyfin:latest`)
- ✅ Check image age (avoid abandoned projects)
- ❌ Don't use random images from unknown users

### Privileges

- ✅ Run as non-root when possible
- ✅ Drop unnecessary capabilities
- ❌ Don't use `--privileged` unless absolutely required
- ❌ Don't mount Docker socket unless necessary (Cosmos/Portainer need it)

### Updates

**Update strategy:**
```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Remove old images
docker image prune
```

**Update frequency:**
- Security patches: Immediately
- Feature updates: Monthly
- Major versions: When stable (wait 2-4 weeks)

## Data Security

### Backup Strategy

**What to backup:**
- Docker volumes: `/var/lib/docker/volumes/`
- Cosmos config: `./cosmos-config/`
- Environment file: `./.env`
- Media (optional): `./jellyfin-media/`

**Backup methods:**
- rsync to NAS
- Restic to cloud storage
- Borg to external drive

**Frequency:**
- Daily: Databases, configs
- Weekly: Media (if it changes)
- Before updates: Everything

### Encryption at Rest

**Not included by default** because:
- Adds complexity
- Performance overhead
- Physical access is already in threat model

**If you want encryption:**
- Use LUKS for full disk encryption
- Use encrypted Docker volumes
- Use encrypted backup targets

### Data Privacy

**Services that store sensitive data:**
- PostgreSQL (n8n workflow credentials)
- n8n (API keys, database passwords)
- Cosmos (SSL certs, route configs)

**Services that don't:**
- Jellyfin (just media metadata)
- Uptime Kuma (just URLs and status)

## Remote Access Security

### Cloudflare Tunnel (Recommended)

**Pros:**
- No open ports on router
- DDoS protection
- Free tier available
- Can add Cloudflare Access (zero-trust)

**Cons:**
- Traffic goes through Cloudflare (privacy consideration)
- Requires Cloudflare account
- Depends on Cloudflare uptime

**Security features:**
- End-to-end encryption
- IP allowlisting
- Country blocking
- Rate limiting

### Tailscale VPN (Most Secure)

**Pros:**
- End-to-end encrypted
- Peer-to-peer (no relay when possible)
- Zero-trust by default
- No traffic inspection by third party

**Cons:**
- Requires Tailscale client on devices
- Limited free tier (20 devices)
- Slower than Cloudflare for many users

**Security features:**
- WireGuard encryption
- ACLs (who can access what)
- MFA enforcement
- Audit logs

### What NOT to Do

❌ **Direct port forwarding (80/443) to your server**
- Exposes server directly to internet
- No DDoS protection
- Home IP revealed
- Single point of failure

❌ **Running services on default ports without auth**
- Bots scan for open services 24/7
- Credentials will be brute-forced
- Exploits will be attempted

## Incident Response

### If You Suspect a Breach

1. **Isolate immediately**
   ```bash
   # Disconnect from network
   sudo ip link set eth0 down
   ```

2. **Assess damage**
   ```bash
   # Check running containers
   docker ps

   # Check container logs
   docker compose logs

   # Check auth logs
   sudo journalctl -u ssh
   ```

3. **Contain**
   ```bash
   # Stop suspicious containers
   docker stop $(docker ps -q)

   # Disable remote access
   sudo systemctl stop cosmos-network-connector
   ```

4. **Recover**
   - Restore from backup
   - Change all passwords
   - Review all installed apps
   - Update all services
   - Re-enable with increased security

### Security Monitoring

**Logs to monitor:**
```bash
# Cosmos access logs
docker logs cosmos | grep -i error

# Failed SSH attempts
sudo journalctl -u ssh | grep -i failed

# Docker events
docker events

# Auto-connector activity
sudo tail -f /var/log/cosmos-network-connector.log
```

**What to look for:**
- Repeated failed login attempts
- Connections from unknown IPs
- Containers starting unexpectedly
- Unusual network activity

## Security Checklist

### Initial Setup
- [ ] Change all default passwords
- [ ] Enable firewall (UFW/iptables)
- [ ] Configure authentication on all Cosmos routes
- [ ] Set up backups
- [ ] Review Cosmos security settings
- [ ] Disable unused services

### Ongoing Maintenance
- [ ] Update services monthly
- [ ] Review access logs weekly
- [ ] Test backups monthly
- [ ] Rotate passwords annually
- [ ] Audit installed apps quarterly

### Before Internet Exposure
- [ ] Enable MFA on all services that support it
- [ ] Use Cloudflare Access or Tailscale ACLs
- [ ] Review all Cosmos routes (nothing public that shouldn't be)
- [ ] Test from external network
- [ ] Monitor logs for unusual activity

## Responsible Disclosure

If you discover a security issue in this stack:

1. **Do not** open a public GitHub issue
2. **Do** email the maintainer privately (see README)
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if you have one)

We'll work with you to fix the issue and credit you in the release notes.

## Legal Disclaimer

This software is provided "as is" without warranty. You are responsible for:
- Securing your own system
- Complying with local laws
- Protecting your data
- Monitoring for breaches

The maintainers are not liable for security incidents, data loss, or legal issues arising from use of this stack.

## Further Reading

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Tailscale Security Model](https://tailscale.com/security/)
- [Cloudflare Tunnel Security](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
