#!/bin/bash

################################################################################
# Home Server Stack - Lean Installer
# Core: n8n, Jellyfin, Traefik, PostgreSQL
# Optional: Portainer, Uptime Kuma
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

check_dns() {
    local subdomain=$1
    local domain=$2
    print_info "Checking DNS for $subdomain.$domain..."

    if command_exists nslookup; then
        if nslookup "$subdomain.$domain" >/dev/null 2>&1; then
            print_success "DNS resolves for $subdomain.$domain"
            return 0
        else
            return 1
        fi
    elif command_exists dig; then
        if dig +short "$subdomain.$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            print_success "DNS resolves for $subdomain.$domain"
            return 0
        else
            return 1
        fi
    elif command_exists host; then
        if host "$subdomain.$domain" >/dev/null 2>&1; then
            print_success "DNS resolves for $subdomain.$domain"
            return 0
        else
            return 1
        fi
    else
        print_warning "No DNS tools available (nslookup/dig/host). Skipping DNS validation."
        return 0
    fi
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
║  ✓ Traefik - Reverse Proxy with SSL                     ║
║  ✓ n8n - Workflow Automation                            ║
║  ✓ Jellyfin - Media Streaming                           ║
║  ✓ PostgreSQL - Database                                ║
║                                                           ║
║  Optional:                                               ║
║  ⭐ Portainer - Container Management                     ║
║  ⭐ Uptime Kuma - Monitoring                             ║
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

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
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

while true; do
    read -p "$(echo -e "${CYAN}SSL email for Let's Encrypt: ${NC}")" SSL_EMAIL
    if validate_email "$SSL_EMAIL"; then
        print_success "Email: $SSL_EMAIL"
        break
    else
        print_error "Invalid email"
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
    TRAEFIK_MEM="256M"
    TRAEFIK_CPU="0.5"
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
    ;;
  2)
    # Moderate (32-48GB)
    PROFILE_NAME="Moderate"
    TRAEFIK_MEM="512M"
    TRAEFIK_CPU="0.5"
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
    ;;
  3)
    # Relaxed (48-64GB)
    PROFILE_NAME="Relaxed"
    TRAEFIK_MEM="1G"
    TRAEFIK_CPU="1.0"
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
    ;;
  4)
    # Minimal (64GB+)
    PROFILE_NAME="Minimal/No Limits"
    TRAEFIK_MEM="2G"
    TRAEFIK_CPU="1.5"
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

print_header "Step 5: Generating Keys"

POSTGRES_PASSWORD=$(generate_secret 32)
print_success "PostgreSQL password generated"

print_header "Step 6: DNS Configuration"

echo ""
print_warning "Configure these DNS records:"
echo ""
echo "  n8n.$DOMAIN_NAME           →  $SERVER_IP"
echo "  jellyfin.$DOMAIN_NAME      →  $SERVER_IP"
[[ "$INSTALL_PORTAINER" == "true" ]] && echo "  portainer.$DOMAIN_NAME     →  $SERVER_IP"
[[ "$INSTALL_UPTIME" == "true" ]] && echo "  uptime.$DOMAIN_NAME        →  $SERVER_IP"
echo ""

read -p "$(echo -e "${YELLOW}DNS configured? [y/N]: ${NC}")" DNS_CONFIRMED
if [[ ! "$DNS_CONFIRMED" =~ ^[Yy]$ ]]; then
    print_warning "Configure DNS first, then re-run."
    exit 0
fi

# Validate DNS
echo ""
print_info "Validating DNS records..."
DNS_FAILED=false

if ! check_dns "n8n" "$DOMAIN_NAME"; then
    print_error "DNS not resolving for n8n.$DOMAIN_NAME"
    DNS_FAILED=true
fi

if ! check_dns "jellyfin" "$DOMAIN_NAME"; then
    print_error "DNS not resolving for jellyfin.$DOMAIN_NAME"
    DNS_FAILED=true
fi

if [[ "$INSTALL_PORTAINER" == "true" ]]; then
    if ! check_dns "portainer" "$DOMAIN_NAME"; then
        print_error "DNS not resolving for portainer.$DOMAIN_NAME"
        DNS_FAILED=true
    fi
fi

if [[ "$INSTALL_UPTIME" == "true" ]]; then
    if ! check_dns "uptime" "$DOMAIN_NAME"; then
        print_error "DNS not resolving for uptime.$DOMAIN_NAME"
        DNS_FAILED=true
    fi
fi

if [[ "$DNS_FAILED" == "true" ]]; then
    echo ""
    print_error "DNS validation failed. Please configure DNS properly and wait for propagation."
    print_info "You can check DNS with: nslookup n8n.$DOMAIN_NAME"
    print_info "DNS propagation can take 5-60 minutes."
    echo ""
    read -p "$(echo -e "${YELLOW}Continue anyway? [y/N]: ${NC}")" FORCE_CONTINUE
    if [[ ! "$FORCE_CONTINUE" =~ ^[Yy]$ ]]; then
        print_warning "Exiting. Please configure DNS and re-run."
        exit 0
    fi
    print_warning "Continuing without DNS validation..."
fi

print_header "Step 7: Creating Configuration"

# We're already in the homelab-stack directory, no need to create subdirectory
print_info "Working directory: $(pwd)"
print_info "Creating docker-compose.yml..."

cat > docker-compose.yml << 'EOFCOMPOSE'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${SSL_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - traefik_certs:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${TRAEFIK_MEM}
          cpus: '${TRAEFIK_CPU}'

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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`n8n.${DOMAIN_NAME}`)"
      - "traefik.http.routers.n8n.tls=true"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"

  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${DOMAIN_NAME}`)"
      - "traefik.http.routers.jellyfin.tls=true"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls.certresolver=letsencrypt"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
EOFCOMPOSE

if [[ "$INSTALL_PORTAINER" == "true" ]]; then
    cat >> docker-compose.yml << 'EOFPORTAINER'

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN_NAME}`)"
      - "traefik.http.routers.portainer.tls=true"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
EOFPORTAINER
fi

if [[ "$INSTALL_UPTIME" == "true" ]]; then
    cat >> docker-compose.yml << 'EOFUPTIME'

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime_kuma_data:/app/data
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: ${UPTIME_MEM}
          cpus: '${UPTIME_CPU}'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime.rule=Host(`uptime.${DOMAIN_NAME}`)"
      - "traefik.http.routers.uptime.tls=true"
      - "traefik.http.routers.uptime.entrypoints=websecure"
      - "traefik.http.routers.uptime.tls.certresolver=letsencrypt"
      - "traefik.http.services.uptime.loadbalancer.server.port=3001"
EOFUPTIME
fi

cat >> docker-compose.yml << 'EOFVOLUMES'

volumes:
  traefik_certs:
  postgres_data:
  n8n_data:
  n8n_files:
  jellyfin_config:
  jellyfin_cache:
EOFVOLUMES

[[ "$INSTALL_PORTAINER" == "true" ]] && echo "  portainer_data:" >> docker-compose.yml
[[ "$INSTALL_UPTIME" == "true" ]] && echo "  uptime_kuma_data:" >> docker-compose.yml

cat >> docker-compose.yml << 'EOFNETWORKS'

networks:
  homelab:
    name: homelab
    driver: bridge
EOFNETWORKS

print_success "docker-compose.yml created"

cat > .env << EOFENV
DOMAIN_NAME=$DOMAIN_NAME
SSL_EMAIL=$SSL_EMAIL
GENERIC_TIMEZONE=$GENERIC_TIMEZONE
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Resource Limits
TRAEFIK_MEM=$TRAEFIK_MEM
TRAEFIK_CPU=$TRAEFIK_CPU
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
EOFENV

chmod 600 .env
print_success ".env created"

print_header "Step 8: Creating Directories"
mkdir -p jellyfin-media/{movies,tv,music}
print_success "Media directories created"

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
CRITICAL_SERVICES="traefik postgres n8n jellyfin"
FAILED_SERVICES=""

for service in $CRITICAL_SERVICES; do
    if ! docker compose ps | grep -q "$service.*running"; then
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

Services:
- n8n:       https://n8n.$DOMAIN_NAME
- Jellyfin:  https://jellyfin.$DOMAIN_NAME
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "- Portainer: https://portainer.$DOMAIN_NAME" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "- Uptime:    https://uptime.$DOMAIN_NAME" )

PostgreSQL Credentials:
  User: n8n
  Password: $POSTGRES_PASSWORD

Resource Limits ($PROFILE_NAME):
  Traefik:   Memory: $TRAEFIK_MEM, CPU: $TRAEFIK_CPU
  PostgreSQL: Memory: $POSTGRES_MEM, CPU: $POSTGRES_CPU
  n8n:       Memory: $N8N_MEM, CPU: $N8N_CPU
  Jellyfin:  Memory: $JELLYFIN_MEM, CPU: $JELLYFIN_CPU
$( [[ "$INSTALL_PORTAINER" == "true" ]] && echo "  Portainer: Memory: $PORTAINER_MEM, CPU: $PORTAINER_CPU" )
$( [[ "$INSTALL_UPTIME" == "true" ]] && echo "  Uptime:    Memory: $UPTIME_MEM, CPU: $UPTIME_CPU" )

Important:
1. All credentials are in the .env file (keep it secure!)
2. Traefik dashboard: http://$SERVER_IP:8080 (INSECURE - restrict access!)
3. SSL certificates may take 2-5 minutes to generate
4. Media files go in: jellyfin-media/movies, jellyfin-media/tv, jellyfin-media/music

Backup your .env file immediately!
EOFINST

chmod 600 INSTALLATION_INFO.txt

echo ""
echo -e "${GREEN}Your Services:${NC}"
echo -e "  • n8n:      https://n8n.$DOMAIN_NAME"
echo -e "  • Jellyfin: https://jellyfin.$DOMAIN_NAME"
[[ "$INSTALL_PORTAINER" == "true" ]] && echo -e "  • Portainer: https://portainer.$DOMAIN_NAME"
[[ "$INSTALL_UPTIME" == "true" ]] && echo -e "  • Uptime: https://uptime.$DOMAIN_NAME"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo -e "  • All credentials saved in: ${BOLD}INSTALLATION_INFO.txt${NC}"
echo -e "  • PostgreSQL password also in: ${BOLD}.env${NC}"
echo -e "  • Traefik dashboard at: ${BOLD}http://$SERVER_IP:8080${NC} (INSECURE!)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. View credentials: cat INSTALLATION_INFO.txt"
echo "2. Add media files to: jellyfin-media/movies, jellyfin-media/tv, jellyfin-media/music"
echo "3. Secure Traefik dashboard: sudo ufw allow from YOUR_IP to any port 8080"
echo "4. Set up backups (see README.md)"
echo "5. Wait 2-5 minutes for SSL certificates to generate"
echo ""
print_success "Installation complete! Check logs with: docker compose logs -f"
exit 0
