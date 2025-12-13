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

print_header "Step 3: Optional Services"

read -p "$(echo -e "${CYAN}Install Portainer? [Y/n]: ${NC}")" INSTALL_PORTAINER
INSTALL_PORTAINER=$([[ ! "$INSTALL_PORTAINER" =~ ^[Nn]$ ]] && echo "true" || echo "false")

read -p "$(echo -e "${CYAN}Install Uptime Kuma? [Y/n]: ${NC}")" INSTALL_UPTIME
INSTALL_UPTIME=$([[ ! "$INSTALL_UPTIME" =~ ^[Nn]$ ]] && echo "true" || echo "false")

print_header "Step 4: Generating Keys"

POSTGRES_PASSWORD=$(generate_secret 32)
print_success "PostgreSQL password generated"

print_header "Step 5: DNS Configuration"

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

print_header "Step 6: Creating Configuration"

DEPLOY_DIR="homelab-stack"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

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
          memory: 256M
          cpus: '0.5'

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
          memory: 512M
          cpus: '1.0'
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
          memory: 2G
          cpus: '2.0'
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
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
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
          memory: 256M
          cpus: '0.5'
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
          memory: 512M
          cpus: '0.5'
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
EOFENV

chmod 600 .env
print_success ".env created"

print_header "Step 7: Creating Directories"
mkdir -p jellyfin-media/{movies,tv,music}
print_success "Media directories created"

print_header "Step 8: Downloading Images"
docker compose pull
print_success "Images downloaded"

print_header "Step 9: Starting Services"
docker compose up -d
print_info "Waiting 30 seconds..."
sleep 30
print_success "Services started"

print_header "Step 10: Verification"
docker compose ps

print_header "🎉 Installation Complete!"

echo ""
echo -e "${GREEN}Your Services:${NC}"
echo -e "  • n8n:      https://n8n.$DOMAIN_NAME"
echo -e "  • Jellyfin: https://jellyfin.$DOMAIN_NAME"
[[ "$INSTALL_PORTAINER" == "true" ]] && echo -e "  • Portainer: https://portainer.$DOMAIN_NAME"
[[ "$INSTALL_UPTIME" == "true" ]] && echo -e "  • Uptime: https://uptime.$DOMAIN_NAME"
echo ""
echo -e "${CYAN}PostgreSQL Credentials (in .env):${NC}"
echo "  User: n8n"
echo "  Password: $POSTGRES_PASSWORD"
echo ""

cat > INSTALLATION_INFO.txt << EOFINST
Installed: $(date)
Domain: $DOMAIN_NAME
Server IP: $SERVER_IP
PostgreSQL Password: $POSTGRES_PASSWORD
EOFINST

print_success "Done!"
exit 0
