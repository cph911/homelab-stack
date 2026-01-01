#!/bin/bash

################################################################################
# Home Server Stack - Lean Installer
# Core: n8n, Jellyfin, Cosmos, PostgreSQL
# Optional: Portainer, Uptime Kuma, Pi-hole, Tailscale, Cloudflare Tunnel
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

generate_secret() {
    openssl rand -hex $1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_domain() {
    [[ $1 =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

validate_email() {
    [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

cleanup_installation() {
    print_warning "Cleaning up failed installation..."

    if [ -f "docker-compose.yml" ]; then
        docker compose down -v 2>/dev/null || true
        print_info "Stopped and removed containers/volumes"
    fi

    rm -f docker-compose.yml .env INSTALLATION_INFO.txt
    print_info "Removed configuration files"

    print_success "Cleanup complete. You can re-run the installer."
}

retry_command() {
    local max_attempts=4
    local attempt=1
    local delay=2
    local command="$@"

    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_warning "Attempt $attempt failed. Retrying in ${delay}s..."
                sleep $delay
                delay=$((delay * 2))
                attempt=$((attempt + 1))
            else
                print_error "Command failed after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          🏠 Home Server Stack - Lean Installer            ║
║                                                           ║
║  Core Services:                                          ║
║  ✓ Cosmos - Reverse Proxy with SSL                      ║
║  ✓ n8n - Workflow Automation                            ║
║  ✓ Jellyfin - Media Streaming                           ║
║  ✓ PostgreSQL - Database                                ║
║                                                           ║
║  Optional:                                               ║
║  ⭐ Portainer - Container Management                     ║
║  ⭐ Uptime Kuma - Monitoring                             ║
║  ⭐ Pi-hole - DNS Ad Blocking (Advanced)                ║
║  ⭐ Tailscale - VPN Remote Access (Advanced)            ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
print_info "Starting installation..."
sleep 2

print_header "Step 1: Prerequisites Check"

if [[ $EUID -eq 0 ]]; then
   print_warning "Running as root."
   sleep 2
fi

print_info "Checking Docker..."
if command_exists docker; then
    print_success "Docker found"
else
    print_error "Docker not installed!"
    echo "Install: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

print_info "Checking Docker Compose..."
if docker compose version >/dev/null 2>&1; then
    print_success "Docker Compose found"
else
    print_error "Docker Compose not installed!"
    exit 1
fi

print_info "Checking Docker daemon..."
if docker info >/dev/null 2>&1; then
    print_success "Docker daemon running"
else
    print_error "Docker daemon not running!"
    exit 1
fi

print_info "Checking OpenSSL..."
if command_exists openssl; then
    print_success "OpenSSL found"
else
    print_error "OpenSSL not installed!"
    exit 1
fi

SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "Unable to detect")
print_info "Server IP: $SERVER_IP"
sleep 2

print_header "Step 2: Configuration"

while true; do
    read -p "$(echo -e "${CYAN}Enter your domain (e.g., hameed.tech): ${NC}")" DOMAIN_NAME
    if validate_domain "$DOMAIN_NAME"; then
        print_success "Domain: $DOMAIN_NAME"
        break
    else
        print_error "Invalid domain"
    fi
done

echo ""
print_info "Select timezone:"
echo "1) America/New_York"
echo "2) America/Los_Angeles"
echo "3) Europe/London"
echo "4) Asia/Dubai"
echo "5) Asia/Riyadh (default)"
echo "6) Custom"

read -p "$(echo -e "${CYAN}Choice [1-6]: ${NC}")" TZ_CHOICE
case ${TZ_CHOICE:-5} in
    1) GENERIC_TIMEZONE="America/New_York" ;;
    2) GENERIC_TIMEZONE="America/Los_Angeles" ;;
    3) GENERIC_TIMEZONE="Europe/London" ;;
    4) GENERIC_TIMEZONE="Asia/Dubai" ;;
    5) GENERIC_TIMEZONE="Asia/Riyadh" ;;
    6) read -p "$(echo -e "${CYAN}Enter timezone: ${NC}")" GENERIC_TIMEZONE ;;
    *) GENERIC_TIMEZONE="Asia/Riyadh" ;;
esac
print_success "Timezone: $GENERIC_TIMEZONE"

print_header "Step 3: Resource Limit Configuration"

# Detect system RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')

echo -e "Detected System RAM: ${GREEN}${TOTAL_RAM}GB${NC}"
echo ""
echo "How much RAM does your server have?"
echo ""
echo "1) 16-32GB  - Conservative limits (~4.5GB for base stack)"
echo "2) 32-48GB  - Moderate limits (~7.5GB for base stack)"
echo "3) 48-64GB  - Relaxed limits (~13GB for base stack)"
echo "4) 64GB+    - Minimal limits (~22GB for base stack)"
echo ""
read -p "$(echo -e "${CYAN}Select profile [1-4]: ${NC}")" RAM_PROFILE

# Validate input
while [[ ! "$RAM_PROFILE" =~ ^[1-4]$ ]]; do
  echo -e "${RED}Invalid selection. Please choose 1, 2, 3, or 4.${NC}"
  read -p "$(echo -e "${CYAN}Select profile [1-4]: ${NC}")" RAM_PROFILE
done

# Set resource limits based on profile
case $RAM_PROFILE in
  1)
    # Conservative (16-32GB)
    PROFILE_NAME="Conservative"
    COSMOS_MEM="512M"
    COSMOS_CPU="1.0"
    POSTGRES_MEM="512M"
    POSTGRES_CPU="1.0"
    N8N_MEM="1G"
    N8N_CPU="1.0"
    JELLYFIN_MEM="2G"
    JELLYFIN_CPU="2.0"
    PORTAINER_MEM="256M"
    PORTAINER_CPU="0.5"
    UPTIME_MEM="512M"
    UPTIME_CPU="0.5"
    PIHOLE_MEM="512M"
    PIHOLE_CPU="0.5"
    ;;
  2)
    # Moderate (32-48GB)
    PROFILE_NAME="Moderate"
    COSMOS_MEM="1G"
    COSMOS_CPU="1.5"
    POSTGRES_MEM="1G"
    POSTGRES_CPU="1.0"
    N8N_MEM="2G"
    N8N_CPU="2.0"
    JELLYFIN_MEM="4G"
    JELLYFIN_CPU="3.0"
    PORTAINER_MEM="512M"
    PORTAINER_CPU="0.5"
    UPTIME_MEM="512M"
    UPTIME_CPU="0.5"
    PIHOLE_MEM="512M"
    PIHOLE_CPU="0.5"
    ;;
  3)
    # Relaxed (48-64GB)
    PROFILE_NAME="Relaxed"
    COSMOS_MEM="2G"
    COSMOS_CPU="2.0"
    POSTGRES_MEM="2G"
    POSTGRES_CPU="2.0"
    N8N_MEM="4G"
    N8N_CPU="3.0"
    JELLYFIN_MEM="6G"
    JELLYFIN_CPU="4.0"
    PORTAINER_MEM="1G"
    PORTAINER_CPU="0.5"
    UPTIME_MEM="1G"
    UPTIME_CPU="0.5"
    PIHOLE_MEM="1G"
    PIHOLE_CPU="0.5"
    ;;
  4)
    # Minimal (64GB+)
    PROFILE_NAME="Minimal/No Limits"
    COSMOS_MEM="4G"
    COSMOS_CPU="3.0"
    POSTGRES_MEM="4G"
    POSTGRES_CPU="3.0"
    N8N_MEM="8G"
    N8N_CPU="4.0"
    JELLYFIN_MEM="8G"
    JELLYFIN_CPU="6.0"
    PORTAINER_MEM="2G"
    PORTAINER_CPU="1.0"
    UPTIME_MEM="2G"
    UPTIME_CPU="1.0"
    PIHOLE_MEM="2G"
    PIHOLE_CPU="1.0"
    ;;
esac

echo ""
echo -e "${GREEN}Selected profile: $PROFILE_NAME${NC}"
echo "Resource limits will be configured accordingly."
echo ""

print_header "Step 4: Optional Services"

read -p "$(echo -e "${CYAN}Install Portainer? [Y/n]: ${NC}")" INSTALL_PORTAINER
INSTALL_PORTAINER=$([[ ! "$INSTALL_PORTAINER" =~ ^[Nn]$ ]] && echo "true" || echo "false")

read -p "$(echo -e "${CYAN}Install Uptime Kuma? [Y/n]: ${NC}")" INSTALL_UPTIME
INSTALL_UPTIME=$([[ ! "$INSTALL_UPTIME" =~ ^[Nn]$ ]] && echo "true" || echo "false")

echo ""
print_info "Advanced Services (DNS ad-blocking)"
read -p "$(echo -e "${CYAN}Install Pi-hole? [y/N]: ${NC}")" INSTALL_PIHOLE
INSTALL_PIHOLE=$([[ "$INSTALL_PIHOLE" =~ ^[Yy]$ ]] && echo "true" || echo "false")

if [[ "$INSTALL_PIHOLE" == "true" ]]; then
    while true; do
        read -s -p "$(echo -e "${CYAN}Set Pi-hole admin password: ${NC}")" PIHOLE_PASSWORD
        echo ""
        read -s -p "$(echo -e "${CYAN}Confirm password: ${NC}")" PIHOLE_PASSWORD_CONFIRM
        echo ""
        if [ "$PIHOLE_PASSWORD" == "$PIHOLE_PASSWORD_CONFIRM" ]; then
            print_success "Pi-hole password set"
            break
        else
            print_error "Passwords do not match. Try again."
        fi
    done
fi

print_header "Step 5: Remote Access Configuration"

echo ""
print_info "Do you need to access your services remotely (outside your local network)?"
echo ""
read -p "$(echo -e "${CYAN}Enable remote access? [y/N]: ${NC}")" ENABLE_REMOTE
ENABLE_REMOTE=$([[ "$ENABLE_REMOTE" =~ ^[Yy]$ ]] && echo "true" || echo "false")

REMOTE_METHOD="none"
if [[ "$ENABLE_REMOTE" == "true" ]]; then
    echo ""
    print_info "Choose remote access method:"
    echo ""
    echo "1) Tailscale VPN (Recommended for CG-NAT/No Static IP)"
    echo "   ✓ No public exposure"
    echo "   ✓ Works without static IP"
    echo "   ✓ Private VPN tunnel"
    echo ""
    echo "2) Cloudflare Tunnel (For public domains)"
    echo "   ✓ Public domain access"
    echo "   ✓ Real SSL certificates"
    echo "   ⚠ Services publicly exposed"
    echo ""
    read -p "$(echo -e "${CYAN}Choice [1-2]: ${NC}")" REMOTE_CHOICE

    case ${REMOTE_CHOICE:-1} in
        1)
            REMOTE_METHOD="tailscale"
            print_info "Tailscale will be configured after installation"
            print_info "See docs/TAILSCALE_SETUP.md for setup guide"
            ;;
        2)
            REMOTE_METHOD="cloudflare"
            print_info "Cloudflare Tunnel will be configured after installation"
            print_info "See docs/CLOUDFLARE_TUNNEL.md for setup guide"
            while true; do
                read -p "$(echo -e "${CYAN}SSL email for Let's Encrypt: ${NC}")" SSL_EMAIL
                if validate_email "$SSL_EMAIL"; then
                    print_success "Email: $SSL_EMAIL"
                    break
                else
                    print_error "Invalid email"
                fi
            done
            ;;
        *)
            REMOTE_METHOD="tailscale"
            print_warning "Invalid choice. Defaulting to Tailscale."
            ;;
    esac
fi

print_header "Step 6: Generating Keys"

POSTGRES_PASSWORD=$(generate_secret 32)
print_success "PostgreSQL password generated"

print_header "Step 7: Creating Configuration"

# We're already in the homelab-stack directory, no need to create subdirectory
print_info "Working directory: $(pwd)"
print_info "Creating docker-compose.yml..."

cat > docker-compose.yml << 'EOFCOMPOSE'
services:
  cosmos:
    image: azukaar/cosmos-server:latest
    container_name: cosmos
    restart: always
    privileged: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./cosmos-config:/var/lib/cosmos
      - /:/mnt/host:rslave
    environment:
      - COSMOS_HOSTNAME=${DOMAIN_NAME}
      - COSMOS_SERVER_HOSTNAME=cosmos.${DOMAIN_NAME}

  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${POSTGRES_MEM}
          cpus: '${POSTGRES_CPU}'
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://n8n.${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
      - n8n_files:/files
    networks:
      - homelab
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: ${N8N_MEM}
          cpus: '${N8N_CPU}'

  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    environment:
      - TZ=${GENERIC_TIMEZONE}
    volumes:
      - jellyfin_config:/config
      - jellyfin_cache:/cache
      - ./jellyfin-media/movies:/media/movies:ro
      - ./jellyfin-media/tv:/media/tv:ro
      - ./jellyfin-media/music:/media/music:ro
    devices:
      - /dev/dri:/dev/dri
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${JELLYFIN_MEM}
          cpus: '${JELLYFIN_CPU}'
EOFCOMPOSE

if [[ "$INSTALL_PORTAINER" == "true" ]]; then
    cat >> docker-compose.yml << 'EOFPORTAINER'

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${PORTAINER_MEM}
          cpus: '${PORTAINER_CPU}'
EOFPORTAINER
fi

if [[ "$INSTALL_UPTIME" == "true" ]]; then
    cat >> docker-compose.yml << 'EOFUPTIME'

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - uptime_kuma_data:/app/data
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${UPTIME_MEM}
          cpus: '${UPTIME_CPU}'
EOFUPTIME
fi

if [[ "$INSTALL_PIHOLE" == "true" ]]; then
    cat >> docker-compose.yml << EOFPIHOLE

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    environment:
      - TZ=${GENERIC_TIMEZONE}
      - WEBPASSWORD=${PIHOLE_PASSWORD}
      - FTLCONF_LOCAL_IPV4=${SERVER_IP}
      - DNSMASQ_LISTENING=all
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8053:80"
    volumes:
      - pihole_config:/etc/pihole
      - pihole_dnsmasq:/etc/dnsmasq.d
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${PIHOLE_MEM}
          cpus: '${PIHOLE_CPU}'
EOFPIHOLE
fi

cat >> docker-compose.yml << 'EOFVOLUMES'

volumes:
  postgres_data:
  n8n_data:
  n8n_files:
  jellyfin_config:
  jellyfin_cache:
EOFVOLUMES

[[ "$INSTALL_PORTAINER" == "true" ]] && echo "  portainer_data:" >> docker-compose.yml
[[ "$INSTALL_UPTIME" == "true" ]] && echo "  uptime_kuma_data:" >> docker-compose.yml
[[ "$INSTALL_PIHOLE" == "true" ]] && echo "  pihole_config:" >> docker-compose.yml
[[ "$INSTALL_PIHOLE" == "true" ]] && echo "  pihole_dnsmasq:" >> docker-compose.yml

cat >> docker-compose.yml << 'EOFNETWORKS'

networks:
  homelab:
    name: homelab
    driver: bridge
EOFNETWORKS

print_success "docker-compose.yml created"

cat > .env << EOFENV
DOMAIN_NAME=$DOMAIN_NAME
SSL_EMAIL=${SSL_EMAIL:-none}
GENERIC_TIMEZONE=$GENERIC_TIMEZONE
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
PIHOLE_PASSWORD=${PIHOLE_PASSWORD:-none}
SERVER_IP=$SERVER_IP

# Resource Limits
COSMOS_MEM=$COSMOS_MEM
COSMOS_CPU=$COSMOS_CPU
POSTGRES_MEM=$POSTGRES_MEM
POSTGRES_CPU=$POSTGRES_CPU
N8N_MEM=$N8N_MEM
N8N_CPU=$N8N_CPU
JELLYFIN_MEM=$JELLYFIN_MEM
JELLYFIN_CPU=$JELLYFIN_CPU
PORTAINER_MEM=$PORTAINER_MEM
PORTAINER_CPU=$PORTAINER_CPU
UPTIME_MEM=$UPTIME_MEM
UPTIME_CPU=$UPTIME_CPU
PIHOLE_MEM=$PIHOLE_MEM
PIHOLE_CPU=$PIHOLE_CPU
EOFENV

chmod 600 .env
print_success ".env created"

print_header "Step 8: Creating Directories"
mkdir -p jellyfin-media/{movies,tv,music}
mkdir -p cosmos-config
print_success "Media and config directories created"

print_header "Step 9: Downloading Images"
print_info "Downloading Docker images (this may take a few minutes)..."
if ! retry_command "docker compose pull"; then
    print_error "Failed to download images after multiple attempts"
    print_info "Check your internet connection and Docker Hub rate limits"
    cleanup_installation
    exit 1
fi
print_success "Images downloaded"

print_header "Step 10: Starting Services"
print_info "Starting all services..."
if ! docker compose up -d; then
    print_error "Failed to start services"
    print_info "Check logs with: docker compose logs"
    cleanup_installation
    exit 1
fi
print_info "Waiting 30 seconds for services to initialize..."
sleep 30
print_success "Services started"

print_header "Step 11: Verification"
print_info "Checking service status..."
docker compose ps

# Check if critical services are running
CRITICAL_SERVICES="cosmos postgres n8n jellyfin"
FAILED_SERVICES=""

for service in $CRITICAL_SERVICES; do
    if ! docker compose ps | grep -q "$service.*running\|$service.*Up"; then
        FAILED_SERVICES="$FAILED_SERVICES $service"
    fi
done

if [ -n "$FAILED_SERVICES" ]; then
    print_error "Critical services not running:$FAILED_SERVICES"
    print_info "Check logs with: docker compose logs <service-name>"
    print_warning "Installation may be incomplete"
else
    print_success "All critical services are running"
fi

print_header "🎉 Installation Complete!"

cat > INSTALLATION_INFO.txt << EOFINST
Installation Summary
===================
Installed: $(date)
Domain: $DOMAIN_NAME
Server IP: $SERVER_IP
Resource Profile: $PROFILE_NAME
Remote Access: $REMOTE_METHOD

Access URLs (via local network or /etc/hosts):
- Cosmos:    https://cosmos.$DOMAIN_NAME
- n8n:       https://n8n.$DOMAIN_NAME
- Jellyfin:  https://jellyfin.$DOMAIN_NAME
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "- Portainer: https://portainer.$DOMAIN_NAME" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "- Uptime:    https://uptime.$DOMAIN_NAME" )
$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "- Pi-hole:   https://pihole.$DOMAIN_NAME/admin" )

Direct IP Access (temporary):
- Cosmos:    http://$SERVER_IP (or https if configured)
- n8n:       http://$SERVER_IP:5678
- Jellyfin:  http://$SERVER_IP:8096
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "- Portainer: http://$SERVER_IP:9000" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "- Uptime:    http://$SERVER_IP:3001" )
$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "- Pi-hole:   http://$SERVER_IP:8053/admin" )

PostgreSQL Credentials:
  User: n8n
  Password: $POSTGRES_PASSWORD

$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "Pi-hole Admin Password: $PIHOLE_PASSWORD" )

Resource Limits ($PROFILE_NAME):
  Cosmos:     Memory: $COSMOS_MEM, CPU: $COSMOS_CPU
  PostgreSQL: Memory: $POSTGRES_MEM, CPU: $POSTGRES_CPU
  n8n:        Memory: $N8N_MEM, CPU: $N8N_CPU
  Jellyfin:   Memory: $JELLYFIN_MEM, CPU: $JELLYFIN_CPU
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "  Portainer:  Memory: $PORTAINER_MEM, CPU: $PORTAINER_CPU" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "  Uptime:     Memory: $UPTIME_MEM, CPU: $UPTIME_CPU" )
$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "  Pi-hole:    Memory: $PIHOLE_MEM, CPU: $PIHOLE_CPU" )

Remote Access Setup:
$( [[ "$REMOTE_METHOD" == "tailscale" ]] && echo "  Method: Tailscale VPN
  Setup Guide: docs/TAILSCALE_SETUP.md
  After setup, access services via Tailscale network" )
$( [[ "$REMOTE_METHOD" == "cloudflare" ]] && echo "  Method: Cloudflare Tunnel
  Setup Guide: docs/CLOUDFLARE_TUNNEL.md
  Configure Cloudflare dashboard for public access" )
$( [[ "$REMOTE_METHOD" == "none" ]] && echo "  No remote access configured
  Services accessible only on local network" )

Important:
1. All credentials are in the .env file (keep it secure!)
2. Configure services in Cosmos:
   - Access Cosmos at http://$SERVER_IP
   - Complete initial setup wizard
   - Add routes for each service (n8n, jellyfin, etc.)
3. For LOCAL ACCESS using domain names:
   Add to /etc/hosts (Mac/Linux) or C:\Windows\System32\drivers\etc\hosts (Windows):
   $SERVER_IP cosmos.$DOMAIN_NAME
   $SERVER_IP n8n.$DOMAIN_NAME
   $SERVER_IP jellyfin.$DOMAIN_NAME
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "   $SERVER_IP portainer.$DOMAIN_NAME" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "   $SERVER_IP uptime.$DOMAIN_NAME" )
$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "   $SERVER_IP pihole.$DOMAIN_NAME" )
4. For PHONE/MOBILE ACCESS (can't use domain names):
   Use IP:port format directly:
   - n8n:       http://$SERVER_IP:5678
   - Jellyfin:  http://$SERVER_IP:8096
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "   - Portainer: http://$SERVER_IP:9000" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "   - Uptime:    http://$SERVER_IP:3001" )
$( [[ "$INSTALL_PIHOLE" == "true" ]] && echo "   - Pi-hole:   http://$SERVER_IP:8053/admin" )
5. SSL certificates are self-signed (browser warnings are normal)
6. Media files go in: jellyfin-media/movies, jellyfin-media/tv, jellyfin-media/music

Backup your .env file immediately!
EOFINST

chmod 600 INSTALLATION_INFO.txt

echo ""
echo -e "${GREEN}✨ Installation Complete!${NC}"
echo ""
echo -e "${CYAN}Your Services:${NC}"
echo -e "  • Cosmos:   http://$SERVER_IP (complete setup wizard first)"
echo -e "  • n8n:      http://$SERVER_IP:5678"
echo -e "  • Jellyfin: http://$SERVER_IP:8096"
[[ "$INSTALL_PORTAINER" == "true" ]] && echo -e "  • Portainer: http://$SERVER_IP:9000"
[[ "$INSTALL_UPTIME" == "true" ]] && echo -e "  • Uptime: http://$SERVER_IP:3001"
[[ "$INSTALL_PIHOLE" == "true" ]] && echo -e "  • Pi-hole: http://$SERVER_IP:8053/admin"
echo ""
echo -e "${YELLOW}⚠️  Important Next Steps:${NC}"
echo ""
echo "1. ${BOLD}Configure Cosmos:${NC}"
echo "   • Visit http://$SERVER_IP"
echo "   • Complete the initial setup wizard"
echo "   • Set hostname to: cosmos.$DOMAIN_NAME"
echo "   • Configure SSL (use self-signed for local access)"
echo "   • Add service routes for n8n, jellyfin, etc."
echo ""
echo "2. ${BOLD}Set up local DNS (for domain access on computer):${NC}"
echo "   Add these to your computer's /etc/hosts:"
echo "   $SERVER_IP cosmos.$DOMAIN_NAME"
echo "   $SERVER_IP n8n.$DOMAIN_NAME"
echo "   $SERVER_IP jellyfin.$DOMAIN_NAME"
[[ "$INSTALL_PORTAINER" == "true" ]] && echo "   $SERVER_IP portainer.$DOMAIN_NAME"
[[ "$INSTALL_UPTIME" == "true" ]] && echo "   $SERVER_IP uptime.$DOMAIN_NAME"
[[ "$INSTALL_PIHOLE" == "true" ]] && echo "   $SERVER_IP pihole.$DOMAIN_NAME"
echo ""
echo "   ${BOLD}For phone/mobile access (can't edit /etc/hosts):${NC}"
echo "   Use IP:port format: http://$SERVER_IP:5678, http://$SERVER_IP:8096, etc."
echo ""

if [[ "$REMOTE_METHOD" == "tailscale" ]]; then
    echo "3. ${BOLD}Set up Tailscale (for remote access):${NC}"
    echo "   • See docs/TAILSCALE_SETUP.md for complete guide"
    echo "   • Install Tailscale on a Raspberry Pi or VPS"
    echo "   • Connect your devices to the Tailscale network"
    echo ""
elif [[ "$REMOTE_METHOD" == "cloudflare" ]]; then
    echo "3. ${BOLD}Set up Cloudflare Tunnel (for remote access):${NC}"
    echo "   • See docs/CLOUDFLARE_TUNNEL.md for complete guide"
    echo "   • Configure Cloudflare dashboard"
    echo "   • Add DNS records for your services"
    echo ""
fi

echo "4. ${BOLD}View credentials:${NC} cat INSTALLATION_INFO.txt"
echo "5. ${BOLD}Add media files:${NC} jellyfin-media/movies, jellyfin-media/tv, jellyfin-media/music"
echo "6. ${BOLD}Set up backups${NC} (see README.md)"
echo ""
echo -e "${CYAN}Documentation:${NC}"
echo "  • README.md - General information"
echo "  • docs/COSMOS_SETUP.md - Cosmos configuration guide"
[[ "$REMOTE_METHOD" == "tailscale" ]] && echo "  • docs/TAILSCALE_SETUP.md - Remote access via Tailscale"
[[ "$REMOTE_METHOD" == "cloudflare" ]] && echo "  • docs/CLOUDFLARE_TUNNEL.md - Public access via Cloudflare"
echo ""
print_success "Installation complete! Check logs with: docker compose logs -f"
exit 0
