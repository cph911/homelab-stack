# Advanced Documentation

These guides are for users who want to understand the internals, customize behavior, or solve complex problems.

**Most users don't need these.** The main installer handles everything automatically.

## Available Guides

### [Architecture](ARCHITECTURE.md)
Deep dive into how the stack works:
- Network topology and traffic flow
- How the auto-connector works
- Resource allocation logic
- What happens during failures

**Read this if:** You want to understand the system design or modify the networking.

### [Security](SECURITY.md)
Threat model and security best practices:
- What this stack protects against (and what it doesn't)
- Authentication strategies
- Remote access security
- Incident response

**Read this if:** You're exposing services to the internet or need to pass a security audit.

### [Troubleshooting](TROUBLESHOOTING.md)
Comprehensive troubleshooting guide:
- Detailed diagnostic commands
- Service-specific issues
- Resource management
- Recovery procedures

**Read this if:** The [Common Issues](../COMMON_ISSUES.md) guide didn't solve your problem.

### [Post-Installation](POST_INSTALL.md)
Detailed post-installation checklist:
- Securing each service
- Configuring backups
- Setting up monitoring
- Security hardening

**Read this if:** You want to squeeze every bit of security and performance from your setup.

## Do I Need These?

**No, if:**
- ✅ The installer worked fine
- ✅ Services are running
- ✅ You can access everything via browser
- ✅ Everything just works

**Yes, if:**
- ❌ You're customizing the stack heavily
- ❌ You're exposing services to the internet
- ❌ You're running this in a business environment
- ❌ You want to understand every detail

## Still Too Complex?

If these guides are overwhelming, you probably don't need them yet. Stick to:
1. Main [README](../../README.md) for installation
2. [Common Issues](../COMMON_ISSUES.md) for quick fixes
3. [GitHub Issues](https://github.com/cph911/homelab-stack/issues) if you're stuck

The advanced docs will be here when you're ready.
