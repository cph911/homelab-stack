# Architecture

This document explains how the homelab stack is designed and how its components work together.

## Design Philosophy

This stack is built on three principles:

1. **Production habits without enterprise bloat** - Real infrastructure patterns, personal scale
2. **Docker-native networking** - Containers communicate directly, no unnecessary proxies
3. **Flexible entry points** - GUI (Cosmos market) or code (docker-compose), your choice

## Network Topology

The stack uses **two Docker networks** for different purposes:

### `homelab` Network
- **Purpose:** Internal communication for docker-compose stack services
- **Scope:** postgres ↔ n8n, jellyfin ↔ internal services
- **Type:** Bridge network, isolated from Cosmos market apps

### `homelab-shared` Network
- **Purpose:** Shared communication layer for ALL services (docker-compose + Cosmos market)
- **Scope:** Enables apps from different sources to communicate
- **Type:** Bridge network, automatically managed
- **Why it exists:** Cosmos market creates isolated networks per app (`cosmos-app-xyz`), preventing communication. The shared network solves this.

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Host                             │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              homelab-shared Network                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │  │
│  │  │ postgres │  │   n8n    │  │ Notifiarr (Cosmos│   │  │
│  │  └──────────┘  └──────────┘  └──────────────────┘   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │  │
│  │  │ jellyfin │  │ portainer│  │ Heimdall (Cosmos)│   │  │
│  │  └──────────┘  └──────────┘  └──────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Cosmos Server (network_mode: host)            │  │
│  │  - Reverse proxy on ports 80/443                      │  │
│  │  - Routes traffic to containers via Docker socket     │  │
│  │  - Manages SSL certificates                           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### External → Service (via browser)

1. User browses to `https://jellyfin.hameed.tech`
2. DNS resolves to server IP (via Pi-hole wildcard or /etc/hosts)
3. Request hits Cosmos on port 443 (host network mode)
4. Cosmos terminates SSL, checks route config
5. Cosmos proxies to container via Docker network
6. Container responds through Cosmos
7. Cosmos returns response to user with SSL

### Service → Service (internal)

1. Notifiarr needs to connect to qBittorrent
2. Uses container name: `http://qbittorrent:8081`
3. Docker DNS resolves container name → IP on `homelab-shared`
4. Direct container-to-container communication
5. No proxy overhead, no SSL (internal traffic)

## Auto-Connector System

**Problem:** Cosmos market apps are isolated in `cosmos-app-xyz` networks by default.

**Solution:** Auto-connector service watches Docker events and connects new Cosmos apps to `homelab-shared`.

### How It Works

```bash
# Systemd service runs this script
docker events --filter 'event=start' | while read container_name
do
    # Check if container is from Cosmos market
    if docker inspect "$container_name" | grep -q "cosmos-"
    then
        # Connect to shared network if not already connected
        docker network connect homelab-shared "$container_name"
    fi
done
```

### What Gets Connected Automatically

- ✅ Apps installed from Cosmos market (Notifiarr, Heimdall, Uptime Kuma, etc.)
- ✅ docker-compose services (defined in `docker-compose.yml` with `homelab-shared` network)
- ❌ Cosmos server itself (uses host network mode, doesn't need it)

## Service Roles

### Cosmos Server
- **Role:** Reverse proxy, SSL termination, app marketplace
- **Network Mode:** `host` (direct access to all host ports)
- **Why:** Needs to bind ports 80/443, manage all container routing
- **Access:** `https://cosmos.your-domain.com`

### PostgreSQL
- **Role:** Database for n8n workflows
- **Network:** `homelab` + `homelab-shared`
- **Why both networks:** n8n needs it (homelab), other apps might need it (shared)
- **Access:** Internal only, not exposed via Cosmos

### n8n
- **Role:** Workflow automation (IFTTT alternative)
- **Network:** `homelab` + `homelab-shared`
- **Dependencies:** Requires PostgreSQL
- **Access:** `https://n8n.your-domain.com`

### Jellyfin
- **Role:** Media server (Plex alternative)
- **Network:** `homelab` + `homelab-shared`
- **Hardware Acceleration:** Uses `/dev/dri` for GPU transcoding
- **Access:** `https://jellyfin.your-domain.com`

### Portainer (Optional)
- **Role:** Docker GUI management
- **Network:** `homelab` + `homelab-shared`
- **Access:** `https://portainer.your-domain.com`

### Uptime Kuma (Optional)
- **Role:** Service monitoring
- **Network:** `homelab` + `homelab-shared`
- **Access:** `https://uptime.your-domain.com`

### Pi-hole (Optional)
- **Role:** Network-wide DNS and ad blocking
- **Network:** `homelab` + `homelab-shared`
- **Ports:** 53 (DNS), 8053 (Web UI)
- **Access:** `https://pihole.your-domain.com/admin`

## Resource Allocation

The installer auto-scales resources based on available RAM:

### Detection
```bash
total_ram=$(free -g | awk '/^Mem:/{print $2}')
```

### Profiles

**Low (< 8 GB RAM)**
- Minimal allocations
- Single-core CPU limits
- Good for: Testing, light usage

**Medium (8-15 GB RAM)**
- Balanced allocations
- Multi-core CPU access
- Good for: Personal homelab, small household

**High (16+ GB RAM)**
- Generous allocations
- No CPU constraints
- Good for: Power users, heavy automation

### Per-Service Limits

Services have memory limits to prevent one service from consuming all RAM:

```yaml
deploy:
  resources:
    limits:
      memory: 512M    # Example: n8n on low profile
      cpus: '0.5'     # Can use 50% of one CPU core
```

**Why this matters:**
- Prevents OOM (Out of Memory) kills
- Ensures stack stays responsive under load
- Makes resource issues visible (service restarts rather than silent slowdown)

## What Happens When...

### Container Restarts
1. Docker recreates container with same config
2. If it's a Cosmos market app, auto-connector detects the start event
3. Auto-connector reconnects it to `homelab-shared`
4. Service resumes with existing volumes (data persists)

### Docker Daemon Restarts
1. All containers with `restart: unless-stopped` start automatically
2. Auto-connector systemd service starts (depends on docker.service)
3. Networks are recreated if needed
4. Containers reconnect to networks
5. Stack recovers automatically

### Server Reboots
1. Systemd starts docker.service
2. Docker starts all containers
3. Auto-connector service starts
4. Stack fully operational within ~60 seconds

### Network Failures
- Container-to-container communication unaffected (local network)
- External access lost (reverse proxy needs internet for SSL)
- Stack continues running, services remain accessible via IP

### Disk Full
- New containers fail to create
- Existing containers may crash if they can't write logs
- **Prevention:** Monitor disk usage, especially Docker volumes

### SSL Certificate Renewal Fails
- Cosmos handles Let's Encrypt renewals automatically
- If renewal fails, old cert continues working until expiry
- **Check:** Cosmos logs will show renewal errors
- **Fix:** Usually DNS or firewall issues preventing ACME challenge

## Volume Persistence

Data persists in Docker volumes:

```
/var/lib/docker/volumes/
├── homelab-stack_postgres_data/     # n8n workflows
├── homelab-stack_n8n_data/          # n8n user data
├── homelab-stack_jellyfin_config/   # Jellyfin settings
└── ...
```

**Key point:** Removing containers does NOT remove volumes. Your data survives reinstalls.

## Security Boundaries

See [SECURITY.md](SECURITY.md) for detailed security architecture.

**Quick summary:**
- All external traffic goes through Cosmos (single point for SSL, auth, rate limiting)
- Container-to-container traffic is unencrypted (trusted internal network)
- Secrets in environment variables (acceptable for homelab, not for production)
- No services exposed directly to internet (everything behind reverse proxy)

## Extending the Stack

### Adding a Cosmos Market App
1. Install from Cosmos market UI
2. Auto-connector automatically adds it to `homelab-shared`
3. App can communicate with all other services
4. Configure reverse proxy route in Cosmos if needed

### Adding a Docker Compose Service
1. Edit `docker-compose.yml`
2. Add to `networks: [homelab, homelab-shared]`
3. `docker compose up -d`
4. Service joins both networks automatically

### Adding a Standalone Container
```bash
docker run -d \
  --name myapp \
  --network homelab-shared \
  myapp:latest
```

Auto-connector does NOT handle standalone containers. You must manually connect them.

## Performance Characteristics

**Cold start (from powered off):**
- 30-60 seconds to full operation
- Cosmos and n8n are slowest to start

**RAM usage (typical):**
- Idle: 2-4 GB
- Active with media streaming: 4-8 GB
- Heavy automation workloads: 8-12 GB

**CPU usage:**
- Idle: < 5%
- Media transcoding: 80-100% (GPU-accelerated)
- Workflow execution: 20-40%

## Debugging the Stack

### Check service status
```bash
docker compose ps
docker ps | grep cosmos
```

### View service logs
```bash
docker compose logs n8n
docker logs cosmos
```

### Check network connectivity
```bash
# Is container on shared network?
docker network inspect homelab-shared

# Can container resolve other containers?
docker exec n8n ping postgres
docker exec notifiarr ping qbittorrent
```

### Check auto-connector
```bash
sudo systemctl status cosmos-network-connector
sudo tail -f /var/log/cosmos-network-connector.log
```

## Common Misconceptions

**"I need to use Cosmos routes for all services"**
- No. Services can communicate directly via container names on `homelab-shared`.
- Cosmos routes are for external browser access only.

**"I should create more networks for isolation"**
- Not necessary. Docker containers are already isolated at the process level.
- Network isolation adds complexity without meaningful security benefit in a homelab.

**"Host networking is insecure"**
- Cosmos uses host networking for practical reasons (port 80/443 binding).
- It's not less secure than bridge mode + port forwarding.
- The reverse proxy handles all external traffic regardless of network mode.

**"I need to restart everything when I add a service"**
- No. Docker compose only restarts changed services.
- Auto-connector handles new Cosmos apps without restarts.

## Further Reading

- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Security Model](SECURITY.md)
- [Post-Installation Guide](POST_INSTALL.md)
