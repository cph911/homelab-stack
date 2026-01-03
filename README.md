# 🏠 Homelab Stack

**Your personal Netflix + automation server. Dead simple setup.**

One script installs everything: media streaming (Jellyfin), workflow automation (n8n), and a slick web interface. No Docker knowledge required.

## What You Get

- **Jellyfin** - Stream your movies and TV shows (like Netflix, but yours)
- **n8n** - Automate anything (400+ app integrations)
- **Cosmos** - Easy web dashboard for everything
- **Automatic HTTPS** - SSL certificates handled for you
- **Smart networking** - Services talk to each other automatically

**Total setup time:** 10 minutes

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/cph911/homelab-stack.git
cd homelab-stack

# 2. Run the installer
chmod +x install-homelab.sh
./install-homelab.sh

# 3. Follow the prompts (it asks simple questions)
```

That's it! The script handles everything.

### What the Installer Does

1. Asks for your domain (e.g., `myserver.local`)
2. Lets you pick optional services (Portainer, Uptime Kuma, Pi-hole)
3. Auto-detects your RAM and sets smart limits
4. Installs everything with one command
5. Sets up SSL automatically
6. Creates folders for your media

## After Installation

Visit your server:
- **Cosmos Dashboard:** `https://cosmos.your-domain.com`
- **Jellyfin (Media):** `https://jellyfin.your-domain.com`
- **n8n (Automation):** `https://n8n.your-domain.com`

**Next:**
1. Add movies/TV to `jellyfin-media/movies/` and `jellyfin-media/tv/`
2. Scan libraries in Jellyfin
3. Start streaming!

## Common Commands

```bash
# View logs
docker compose logs -f

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start everything
docker compose up -d

# Update services
docker compose pull
docker compose up -d
```

## Need Help?

**Quick fixes:** Check [Common Issues](docs/COMMON_ISSUES.md)

**Want to understand how it works?** Check [Advanced Docs](docs/advanced/)

**Found a bug?** [Open an issue](https://github.com/cph911/homelab-stack/issues)

## Requirements

- Ubuntu 20.04+ or Debian 11+
- 16GB+ RAM
- Docker installed ([Get Docker](https://docs.docker.com/get-docker/))

**Don't have Docker?** The installer will guide you.

## What's Different About This?

- ✅ **Beginner friendly** - No Docker experience needed
- ✅ **One command** - No manual configuration
- ✅ **Smart defaults** - Auto-detects your hardware
- ✅ **Actually works** - Tested on real hardware
- ✅ **Apps talk to each other** - Automatic networking (no manual setup)

## Credits

Made by [Hameed](https://hameed.tech) for people who want a home server without the headache.

Based on [makhatib/AI-stack](https://github.com/makhatib/AI-stack) but simplified for regular homelabs.

## License

MIT - Do whatever you want with it.

---

**Want more control?** Check out the [advanced documentation](docs/advanced/) for deep dives into security, architecture, and customization.
