#!/bin/bash
set -e

# Pi-hole Automated Installer
# This script sets up Pi-hole with all critical configurations

# Configuration - CUSTOMIZE THESE!
SERVER_IP="${SERVER_IP}"  # Required: Set your server's IP
PIHOLE_PASSWORD="${PIHOLE_PASSWORD}"  # Required: Set your Pi-hole admin password
TIMEZONE="${TZ:-America/New_York}"
UPSTREAM_DNS="${PIHOLE_DNS:-8.8.8.8}"
CONTAINER_NAME="pihole"

# Validate required parameters
if [ -z "$SERVER_IP" ]; then
    echo "❌ ERROR: SERVER_IP is required"
    echo "Usage: SERVER_IP=your.server.ip PIHOLE_PASSWORD=yourpassword ./install-pihole.sh"
    exit 1
fi

if [ -z "$PIHOLE_PASSWORD" ]; then
    echo "❌ ERROR: PIHOLE_PASSWORD is required"
    echo "Usage: SERVER_IP=your.server.ip PIHOLE_PASSWORD=yourpassword ./install-pihole.sh"
    exit 1
fi

echo "🔧 Pi-hole Installer"
echo "===================="
echo "Server IP: $SERVER_IP"
echo "Password: $PIHOLE_PASSWORD"
echo "Timezone: $TIMEZONE"
echo ""

# Stop and remove existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🗑️  Removing existing Pi-hole container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

# Pull latest image
echo "📥 Pulling latest Pi-hole image..."
docker pull pihole/pihole:latest

# Start Pi-hole
echo "🚀 Starting Pi-hole container..."
docker run -d \
  --name $CONTAINER_NAME \
  --network homelab-shared \
  --restart unless-stopped \
  -p ${SERVER_IP}:53:53/tcp \
  -p ${SERVER_IP}:53:53/udp \
  -e TZ="$TIMEZONE" \
  -e WEBPASSWORD="$PIHOLE_PASSWORD" \
  -e DNSMASQ_LISTENING='all' \
  -e PIHOLE_DNS_="$UPSTREAM_DNS" \
  -v pihole-data:/etc/pihole \
  -v pihole-dnsmasq:/etc/dnsmasq.d \
  pihole/pihole:latest

# Wait for Pi-hole to be ready
echo "⏳ Waiting for Pi-hole to start..."
sleep 10

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ ERROR: Pi-hole container failed to start"
    docker logs $CONTAINER_NAME
    exit 1
fi

# Wait a bit more for pihole.toml to be created
echo "⏳ Waiting for configuration files to be created..."
sleep 5

# Fix listening mode (CRITICAL!)
echo "🔧 Fixing listening mode to allow external devices..."
docker exec $CONTAINER_NAME sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml

# Restart to apply changes
echo "🔄 Restarting Pi-hole to apply changes..."
docker restart $CONTAINER_NAME
sleep 5

# Verify it's running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ""
    echo "✅ Pi-hole installation complete!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Add Pi-hole to Cosmos:"
    echo "   - Cosmos → URLs → New URL"
    echo "   - Name: /pihole"
    echo "   - Port: 80"
    echo "   - Target: http://pihole:80"
    echo "   - Hostname: pihole.hameed.tech"
    echo "   - SSL: Yes"
    echo ""
    echo "2. Access web interface:"
    echo "   - URL: https://pihole.hameed.tech (after Cosmos setup)"
    echo "   - Password: $PIHOLE_PASSWORD"
    echo ""
    echo "3. Add your adlists via web interface"
    echo ""
    echo "4. Configure devices to use DNS: $SERVER_IP"
    echo ""
else
    echo "❌ ERROR: Pi-hole is not running after restart"
    docker logs $CONTAINER_NAME
    exit 1
fi
