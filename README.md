# homelab-stack
Self-hosted home server automation stack with n8n workflows, Jellyfin media server, automatic SSL certificates via Traefik, and Docker Compose. Optimized for 16GB RAM servers.
🏠 Homelab Stack
Lean, production-ready home server installer for self-hosters who value simplicity over bloat.
Deploy n8n automation, Jellyfin media streaming, and essential services with automated SSL certificates, resource limits, and proper monitoring. Built for real hardware constraints (16-32GB RAM), not fantasy cloud specs.

🎯 What You Get
Core Services (Always Installed)
* n8n - Workflow automation platform (400+ integrations)
* Jellyfin - Media streaming server (your personal Netflix)
* Traefik - Reverse proxy with automatic SSL certificates
* PostgreSQL - Database backend for n8n
Optional Services (You Choose)
* Portainer - Visual Docker container management
* Uptime Kuma - Service monitoring with alerts
What's NOT Included (And Why)
* ❌ Supabase - Massive overhead (8+ containers), not needed for most homelabs
* ❌ Qdrant/Vector DBs - Only needed for AI/RAG workflows
* ❌ MinIO - S3 storage overkill, use local volumes
* ❌ Ollama - 8GB+ RAM hog, use API-based LLMs instead
* ❌ Grafana/Prometheus - Complex monitoring, Uptime Kuma is enough

📊 Resource Usage
Total RAM: ~7-8GB (leaves headroom on 16GB servers)
Service	RAM Limit	CPU Limit	Purpose
Traefik	256MB	0.5 CPU	SSL & routing
PostgreSQL	512MB	1.0 CPU	Database
n8n	2GB	2.0 CPU	Automation
Jellyfin	4GB	2.0 CPU	Media streaming
Portainer	256MB	0.5 CPU	Management
Uptime Kuma	512MB	0.5 CPU	Monitoring
Why resource limits matter: Without them, one runaway process can kill your entire server. This is production-ready configuration, not a demo.

⚡ Quick Start
Prerequisites
* Ubuntu 20.04+ or Debian 11+ server
* 16GB+ RAM (32GB recommended for heavy transcoding)
* Docker 20.10+ and Docker Compose v2+
* Domain name with DNS access
* Ports 80, 443, 8080 available
Installation
# Clone the repository
```
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack
```
# Make the installer executable
```
chmod +x install-homelab.sh
```
# Run the installer
./install-homelab.sh
The installer will:
1. Check prerequisites (Docker, DNS, etc.)
2. Ask for your domain and configuration
3. Generate secure random passwords
4. Create Docker Compose configuration
5. Pull images and start services
6. Set up SSL certificates automatically
Total time: 10-15 minutes

🌐 DNS Configuration
CRITICAL: Configure DNS BEFORE running the installer.
You need A records pointing to your server IP:
n8n.yourdomain.com        →  YOUR_SERVER_IP
jellyfin.yourdomain.com   →  YOUR_SERVER_IP
portainer.yourdomain.com  →  YOUR_SERVER_IP  (if installing)
uptime.yourdomain.com     →  YOUR_SERVER_IP  (if installing)
Verify with: nslookup n8n.yourdomain.com

🔐 Security Features
* ✅ Auto-generated passwords - 64-character secure keys for every service
* ✅ HTTPS enforced - HTTP automatically redirects to HTTPS
* ✅ Let's Encrypt SSL - Free, automatic certificates
* ✅ Secure file permissions - .env set to 600 (owner read/write only)
* ✅ Resource isolation - Docker networks and proper limits
* ✅ No default passwords - Every installation is unique
All credentials saved in .env file (automatically secured).

📁 Project Structure
After installation:
homelab-stack/
├── install-homelab.sh          # Installer script
├── docker-compose.yml          # Generated service definitions
├── .env                        # Generated credentials (DO NOT COMMIT)
├── INSTALLATION_INFO.txt       # Installation summary
├── jellyfin-media/            # Media directories
│   ├── movies/
│   ├── tv/
│   └── music/
└── README.md

🎬 Adding Media to Jellyfin
Option 1: Use Included Directories
# Copy media to the included directories
cp -r /path/to/your/movies/ jellyfin-media/movies/
cp -r /path/to/your/tv/ jellyfin-media/tv/
Option 2: Mount Your Own Directories
Edit docker-compose.yml and uncomment/modify the volume mounts:
jellyfin:
  volumes:
    - jellyfin_config:/config
    - jellyfin_cache:/cache
    # Add your media paths:
    - /mnt/storage/movies:/media/movies:ro
    - /mnt/storage/tv:/media/tv:ro
    - /mnt/storage/music:/media/music:ro
Then restart: docker compose restart jellyfin

🔧 Management Commands
Service Control
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f jellyfin

# Restart all services
docker compose restart

# Restart specific service
docker compose restart n8n

# Stop all services
docker compose down

# Start all services
docker compose up -d

# Check service status
docker compose ps

# View resource usage
docker stats
Updates
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Check logs for any issues
docker compose logs -f

💾 Backup & Restore
Quick Backup
# Backup configuration files
tar czf backup-config-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env INSTALLATION_INFO.txt

# Backup PostgreSQL database
docker compose exec postgres pg_dump -U n8n n8n > backup-n8n-$(date +%Y%m%d).sql

# Backup Docker volumes (n8n data)
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/n8n-data-$(date +%Y%m%d).tar.gz -C /data .
Automated Backups
Create /root/homelab-backup.sh:
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
STACK_DIR="/root/homelab-stack"

mkdir -p $BACKUP_DIR

# Backup database
docker compose -f $STACK_DIR/docker-compose.yml \
  exec -T postgres pg_dump -U n8n n8n > $BACKUP_DIR/n8n-$DATE.sql

# Backup configuration
tar czf $BACKUP_DIR/config-$DATE.tar.gz \
  -C $STACK_DIR docker-compose.yml .env

# Backup n8n workflows
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/n8n-data-$DATE.tar.gz -C /data .

# Keep only last 7 days
find $BACKUP_DIR -name ".sql" -mtime +7 -delete
find $BACKUP_DIR -name ".tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
Make it executable: chmod +x /root/homelab-backup.sh
Add to crontab (crontab -e):
# Daily backup at 2 AM
0 2    /root/homelab-backup.sh >> /var/log/homelab-backup.log 2>&1
Restore from Backup
# Restore configuration
tar xzf backup-config-YYYYMMDD.tar.gz

# Restore database
cat backup-n8n-YYYYMMDD.sql | docker compose exec -T postgres psql -U n8n n8n

# Restore n8n data
docker run --rm \
  -v homelab-stack_n8n_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/n8n-data-YYYYMMDD.tar.gz -C /data

🔥 Troubleshooting
Services Won't Start
# Check logs for errors
docker compose logs --tail=100

# Check if ports are already in use
sudo netstat -tulpn | grep -E ':80|:443'

# Restart Docker daemon
sudo systemctl restart docker
docker compose up -d
SSL Certificates Not Generating
# Check Traefik logs
docker compose logs traefik

# Verify DNS is propagated
nslookup n8n.yourdomain.com

# Check certificate status
curl -I https://n8n.yourdomain.com

# Wait 5-10 minutes - Let's Encrypt can be slow
n8n Database Connection Issues
# Check PostgreSQL is healthy
docker compose ps postgres

# Check PostgreSQL logs
docker compose logs postgres

# Verify credentials match
cat .env | grep POSTGRES_PASSWORD
docker compose exec postgres psql -U n8n -d n8n
Jellyfin Transcoding Issues
# Check available resources
docker stats jellyfin

# Increase Jellyfin memory limit in docker-compose.yml
# Change: memory: 4G  →  memory: 6G

# Restart Jellyfin
docker compose restart jellyfin
Out of Memory
# Check memory usage
free -h
docker stats

# Identify memory hog
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# Temporary: Add swap space
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo mkswap /swapfile
sudo swapon /swapfile

🚀 Next Steps After Installation
1. Configure n8n
* Visit https://n8n.yourdomain.com
* Create your owner account
* Build your first workflow
* Test webhook functionality
2. Set Up Jellyfin
* Visit https://jellyfin.yourdomain.com
* Complete initial setup wizard
* Add media libraries
* Configure transcoding settings
* Create user accounts
3. Configure Monitoring (if installed)
* Visit https://uptime.yourdomain.com
* Add monitors for all your services
* Set up notification channels (email, Slack, etc.)
* Configure status page
4. Secure Traefik Dashboard
The Traefik dashboard runs on port 8080 without authentication.
Options:
1. Firewall it: sudo ufw allow from YOUR_HOME_IP to any port 8080
2. Disable it: Remove --api.dashboard=true from docker-compose.yml
3. Add basic auth (advanced)
5. Set Up Backups
* Configure automated backup script (see Backup section)
* Test restore process
* Store backups off-site (cloud storage, external drive)

🤝 Contributing
Found a bug? Want to add a feature? PRs welcome!
Before contributing:
* Keep the "lean" philosophy (no bloat)
* Add resource limits for new services
* Test on actual hardware (not just local dev)
* Update documentation

📝 Comparison to Other Stacks
vs. Original AI-Stack
Feature	This Stack	AI-Stack
RAM Usage	~7-8GB	12-15GB+
Services	4-6	10+
Resource Limits	✅ Every service	❌ None
Media Streaming	✅ Jellyfin	❌ None
Shared Database	❌ Isolated	⚠️ Shared PostgreSQL
Target Audience	Home servers	AI workloads
vs. Manual Docker Setup
Feature	This Stack	Manual
Setup Time	10-15 min	2-4 hours
SSL Automation	✅ Automatic	⚠️ Manual
Resource Limits	✅ Configured	⚠️ Often forgotten
Security	✅ Auto-generated	⚠️ Manual config
Updates	Simple	Complex
⚠️ Important Notes
* SSL certificates take 2-5 minutes to generate - Be patient on first run
* DNS must be configured BEFORE installation - Let's Encrypt verifies ownership
* Traefik dashboard (port 8080) is insecure - Restrict access immediately
* Resource limits are mandatory - Don't remove them "for performance"
* Backups are your responsibility - Set them up on day one

📚 Documentation Links
Official Service Docs
* n8n Documentation
* Jellyfin Documentation
* Traefik Documentation
* Portainer Documentation
* Uptime Kuma Documentation
Learning Resources
* Docker Compose Best Practices
* Let's Encrypt Rate Limits
* n8n Workflow Templates
* Jellyfin Optimization Guide

📄 License
MIT License - Do whatever you want with it.

🙏 Credits
Created for hameed.tech - A practical home server setup for self-hosters who value working solutions over complexity.
Inspired by *makhatib/AI-stack* but stripped down to essentials and optimized for real hardware constraints.

💬 Support
* Issues: GitHub Issues
* Discussions: GitHub Discussions

Built with ☕ for self-hosters who prefer working systems over demo setups.
