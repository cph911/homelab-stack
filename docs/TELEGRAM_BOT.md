# 🤖 Telegram Health Monitoring Bot (Optional)

Monitor and manage your Docker containers remotely via Telegram. Check container health and restart services from anywhere using your phone.

## ✨ Features

- **Container Health Checks**: Get instant status reports for all running containers
- **Remote Container Control**: Restart or stop containers directly from Telegram
- **Automatic Failure Notifications**: Get instant alerts when containers fail (checked every 10 minutes)
- **Smart Notification Throttling**: Prevents spam from crash loops (1-hour cooldown per container)
- **Automatic Log Capture**: Failed container logs are automatically saved for troubleshooting
- **Startup Notifications**: Get notified when your homelab comes online
- **24/7 Monitoring**: Runs as a systemd service in the background
- **Secure**: Restrict access to your Telegram user ID only
- **Local Network**: Works without exposing services to the internet

---

## 📋 Prerequisites

- Working homelab-stack installation
- Telegram account
- Python 3 installed on your server

---

## 🚀 Quick Setup (Automated Installer)

The easiest way to install the bot is using the automated installer script.

### Step 1: Create Telegram Bot

1. Open Telegram and search for [@BotFather](https://t.me/botfather)
2. Send `/newbot` command
3. Follow prompts to set bot name and username
4. **Copy the bot token** (looks like `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Step 2: Get Your Telegram User ID

1. Search for [@userinfobot](https://t.me/userinfobot) in Telegram
2. Send `/start` command
3. **Copy your user ID** (numeric, e.g., `123456789`)

### Step 3: Run the Installer

SSH into your server and run:

```bash
cd ~/homelab-stack
./install-telegram-bot.sh
```

The installer will:
- ✅ Check prerequisites (Docker, Python3, python3-telebot)
- ✅ Install missing dependencies (with your permission)
- ✅ Prompt for your bot token and user ID
- ✅ Validate credentials format
- ✅ Create bot script with your credentials
- ✅ Set up systemd service for 24/7 operation
- ✅ Start the bot automatically
- ✅ Verify everything is working

**That's it!** Just paste your credentials when prompted and the script handles everything else.

---

## 📱 Testing Your Bot

After installation completes:

1. Open Telegram and search for your bot
2. Send `/start` to begin
3. Type `/` to see all available commands
4. Try `/health` to see container status
5. Try `/restart` to see the interactive menu

---

## 🔧 Manual Installation (Advanced)

If you prefer to install manually or want to understand what the installer does, follow these steps:

### Step 1: Install Dependencies

```bash
sudo apt update
sudo apt install -y python3-telebot
```

### Step 2: Create Bot Script

Create the bot directory:

```bash
mkdir -p ~/telegram-bot
cd ~/telegram-bot
```

Create the bot script:

```bash
nano bot.py
```

Paste the following code:

```python
#!/usr/bin/env python3
import telebot
from telebot import types
import subprocess
import sys

# Configuration
BOT_TOKEN = "YOUR_BOT_TOKEN_HERE"
ALLOWED_USER_ID = None

bot = telebot.TeleBot(BOT_TOKEN)

def get_containers():
    """Get list of all running containers"""
    try:
        result = subprocess.run(
            ['docker', 'ps', '--format', '{{.Names}}|{{.State}}|{{.Status}}'],
            capture_output=True, text=True, check=True, timeout=10
        )
        containers = []
        for line in result.stdout.strip().split('\n'):
            if '|' in line:
                parts = line.split('|')
                containers.append({
                    'name': parts[0],
                    'state': parts[1] if len(parts) > 1 else 'unknown',
                    'status': parts[2] if len(parts) > 2 else 'unknown'
                })
        return containers
    except Exception as e:
        return []

@bot.message_handler(commands=['start'])
def send_welcome(message):
    if ALLOWED_USER_ID and message.from_user.id != ALLOWED_USER_ID:
        bot.reply_to(message, "⛔ Unauthorized")
        return

    bot.reply_to(message, """🤖 *Homelab Health Bot*

Welcome! Use the commands below to manage your containers.

Type / to see all available commands.""", parse_mode='Markdown')

@bot.message_handler(commands=['health', 'status'])
def send_health(message):
    if ALLOWED_USER_ID and message.from_user.id != ALLOWED_USER_ID:
        bot.reply_to(message, "⛔ Unauthorized")
        return

    containers = get_containers()
    if not containers:
        bot.reply_to(message, "❌ No containers found or error getting container list")
        return

    report = "🏥 *Container Health Report*\n\n"
    for container in containers:
        emoji = "✅" if container['state'] == 'running' else "❌"
        report += f"{emoji} *{container['name']}*\n   {container['status']}\n\n"

    bot.reply_to(message, report, parse_mode='Markdown')

@bot.message_handler(commands=['restart'])
def restart_container(message):
    if ALLOWED_USER_ID and message.from_user.id != ALLOWED_USER_ID:
        bot.reply_to(message, "⛔ Unauthorized")
        return

    # Check if container name was provided
    args = message.text.split()
    if len(args) >= 2:
        # Direct restart with container name
        container_name = args[1]
        try:
            subprocess.run(['docker', 'restart', container_name], check=True, timeout=30)
            bot.reply_to(message, f"✅ Restarted *{container_name}*", parse_mode='Markdown')
        except subprocess.CalledProcessError as e:
            bot.reply_to(message, f"❌ Failed to restart *{container_name}*\nError: {str(e)}", parse_mode='Markdown')
        except Exception as e:
            bot.reply_to(message, f"❌ Error: {str(e)}")
        return

    # No container name provided - show selection menu
    containers = get_containers()
    if not containers:
        bot.reply_to(message, "❌ No containers found")
        return

    # Create inline keyboard with container buttons
    markup = types.InlineKeyboardMarkup(row_width=2)
    buttons = []

    for container in containers:
        emoji = "✅" if container['state'] == 'running' else "❌"
        button = types.InlineKeyboardButton(
            text=f"{emoji} {container['name']}",
            callback_data=f"restart:{container['name']}"
        )
        buttons.append(button)

    # Add buttons in pairs (2 per row)
    for i in range(0, len(buttons), 2):
        if i + 1 < len(buttons):
            markup.row(buttons[i], buttons[i + 1])
        else:
            markup.row(buttons[i])

    # Add cancel button
    markup.row(types.InlineKeyboardButton("❌ Cancel", callback_data="cancel"))

    bot.reply_to(message, "🔄 *Select container to restart:*", reply_markup=markup, parse_mode='Markdown')

@bot.callback_query_handler(func=lambda call: True)
def handle_callback(call):
    if ALLOWED_USER_ID and call.from_user.id != ALLOWED_USER_ID:
        bot.answer_callback_query(call.id, "⛔ Unauthorized")
        return

    if call.data == "cancel":
        bot.edit_message_text(
            "❌ Restart cancelled",
            call.message.chat.id,
            call.message.message_id
        )
        bot.answer_callback_query(call.id)
        return

    if call.data.startswith("restart:"):
        container_name = call.data.split(":", 1)[1]

        # Update message to show restarting status
        bot.edit_message_text(
            f"🔄 Restarting *{container_name}*...",
            call.message.chat.id,
            call.message.message_id,
            parse_mode='Markdown'
        )

        try:
            # Restart the container
            subprocess.run(['docker', 'restart', container_name], check=True, timeout=30)

            # Update message with success
            bot.edit_message_text(
                f"✅ Successfully restarted *{container_name}*",
                call.message.chat.id,
                call.message.message_id,
                parse_mode='Markdown'
            )
            bot.answer_callback_query(call.id, f"✅ {container_name} restarted")

        except subprocess.CalledProcessError as e:
            bot.edit_message_text(
                f"❌ Failed to restart *{container_name}*\n\nError: Container not found or restart failed",
                call.message.chat.id,
                call.message.message_id,
                parse_mode='Markdown'
            )
            bot.answer_callback_query(call.id, f"❌ Restart failed", show_alert=True)

        except Exception as e:
            bot.edit_message_text(
                f"❌ Error restarting *{container_name}*\n\n{str(e)}",
                call.message.chat.id,
                call.message.message_id,
                parse_mode='Markdown'
            )
            bot.answer_callback_query(call.id, f"❌ Error occurred", show_alert=True)

@bot.message_handler(commands=['help'])
def send_help(message):
    bot.reply_to(message, """🤖 *Homelab Health Bot*

/health - Container status report
/restart - Restart a container (shows menu)
/help - Show this message

Type / to see all commands!""", parse_mode='Markdown')

def setup_commands():
    """Set bot commands for the menu"""
    commands = [
        types.BotCommand("health", "Check container health status"),
        types.BotCommand("restart", "Restart a container"),
        types.BotCommand("help", "Show help message")
    ]
    bot.set_my_commands(commands)
    print("✅ Bot commands configured")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        ALLOWED_USER_ID = int(sys.argv[1])
        print(f"🔒 Restricted to user: {ALLOWED_USER_ID}")

    # Set up command menu
    setup_commands()

    print("🤖 Bot started!")
    bot.infinity_polling()
```

**Replace placeholders:**
- `YOUR_BOT_TOKEN_HERE` → Your bot token from BotFather

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

Make the script executable:

```bash
chmod +x bot.py
```

### Step 3: Test the Bot Manually (Optional)

Before setting up the service, test that it works:

```bash
python3 bot.py YOUR_TELEGRAM_USER_ID
```

Open Telegram, search for your bot, and send `/health`. You should see a container status report.

Press `Ctrl+C` to stop the test.

### Step 4: Create systemd Service

Create the service file:

```bash
sudo nano /etc/systemd/system/telegram-bot.service
```

Paste the following configuration:

```ini
[Unit]
Description=Telegram Homelab Health Bot
After=network.target docker.service

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME/telegram-bot
ExecStart=/usr/bin/python3 /home/YOUR_USERNAME/telegram-bot/bot.py YOUR_TELEGRAM_USER_ID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Replace placeholders:**
- `YOUR_USERNAME` → Your Linux username (e.g., `John1234`)
- `YOUR_TELEGRAM_USER_ID` → Your Telegram user ID from @userinfobot

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

### Step 5: Enable and Start Service

Reload systemd to recognize the new service:

```bash
sudo systemctl daemon-reload
```

Enable the service to start on boot:

```bash
sudo systemctl enable telegram-bot
```

Start the service:

```bash
sudo systemctl start telegram-bot
```

Check service status:

```bash
sudo systemctl status telegram-bot
```

You should see `Active: active (running)` in green.

---

## 📱 Using the Bot

### Interactive Command Menu

When you type `/` in the chat, Telegram will show you all available commands:

- `/health` - Check container health status
- `/restart` - Restart a container
- `/stop` - Stop a container
- `/help` - Show help message

Just tap a command to use it!

### Available Commands

**Health Check:**
- `/health` or `/status` - Get container health report

**Restart Container:**
- `/restart` - Shows interactive menu with all containers
- `/restart <container_name>` - Directly restart a specific container (advanced)

**Stop Container:**
- `/stop` - Shows interactive menu with all running containers
- `/stop <container_name>` - Directly stop a specific container (advanced)

**Help:**
- `/start` or `/help` - Show help message

### Example Usage

**Check health:**
```
/health
```

Response:
```
🏥 Container Health Report

✅ traefik
   Up 2 hours

✅ n8n
   Up 2 hours (healthy)

✅ jellyfin
   Up 2 hours

❌ portainer
   Exited (1) 5 minutes ago
```

**Restart container (Interactive Menu):**
```
/restart
```

Response: Bot shows clickable buttons with all containers:
```
🔄 Select container to restart:

[✅ qbittorrent]  [✅ navidrome]
[✅ jellyfin]     [✅ portainer]
[✅ n8n]          [✅ postgres]
[✅ traefik]      [❌ Cancel]
```

Tap a container button → Bot restarts it and shows:
```
✅ Successfully restarted portainer
```

**Restart container (Direct Command):**
```
/restart portainer
```

Response:
```
✅ Restarted portainer
```

**Stop container (Interactive Menu):**
```
/stop
```

Response: Bot shows clickable buttons with all running containers:
```
🛑 Select container to stop:

[✅ qbittorrent]  [✅ navidrome]
[✅ jellyfin]     [✅ portainer]
[✅ n8n]          [✅ postgres]
[✅ traefik]      [❌ Cancel]
```

Tap a container button → Bot stops it and shows:
```
🛑 Successfully stopped portainer
```

**Stop container (Direct Command):**
```
/stop portainer
```

Response:
```
🛑 Stopped portainer
```

---

## 🚨 Automatic Failure Monitoring

The bot automatically monitors your containers for failures and sends you instant notifications.

### How It Works

- **Periodic Checks**: Every 10 minutes, the bot checks all container states
- **Failure Detection**: If a container transitions from "running" to "exited", "stopped", or "dead", you get notified
- **Crash Loop Protection**: 1-hour cooldown prevents notification spam from repeatedly failing containers
- **Automatic Log Capture**: When a failure is detected, the bot automatically saves the last 500 lines of container logs
- **Historical Record**: Logs are saved with timestamps in `~/telegram-bot-logs/` for later analysis
- **Auto Recovery Detection**: When a failed container recovers, the notification cooldown is cleared

### Example Notification

When a container fails, you'll receive a message like this:

```
🚨 Container Failed!

Container: portainer
Previous State: running
Current State: exited
Status: Exited (1) 3 seconds ago

📝 Logs saved to:
/home/user/telegram-bot-logs/portainer_20260105_143022.log

Detected at 2026-01-05 14:30:22
```

### Viewing Saved Logs

Logs are stored in `~/telegram-bot-logs/` with filenames in the format: `<container-name>_<timestamp>.log`

**List all saved logs:**
```bash
ls -lh ~/telegram-bot-logs/
```

**View a specific log:**
```bash
cat ~/telegram-bot-logs/portainer_20260105_143022.log
```

**Clean up old logs (optional):**
```bash
# Delete logs older than 30 days
find ~/telegram-bot-logs/ -name "*.log" -mtime +30 -delete
```

### Important Notes

- Only failures (running → stopped) trigger notifications, not containers that are already stopped
- The first health check runs 10 minutes after bot startup to avoid false positives
- Logs are captured at the moment of failure, preserving critical debugging information
- Each failure generates a separate notification and log file

### Crash Loop Protection

If a container is in a crash loop (repeatedly failing and restarting):
- You'll get notified on the **first failure**
- Subsequent failures are **silenced for 1 hour** to prevent spam
- Once the container **runs successfully**, the cooldown is cleared
- This prevents notification fatigue while still alerting you to real issues
- Use `/stop <container>` to remotely stop a misbehaving container until you can investigate

---

## 🔧 Management Commands

### Check Service Status

```bash
sudo systemctl status telegram-bot
```

### View Bot Logs

```bash
sudo journalctl -u telegram-bot -f
```

### Restart Bot Service

```bash
sudo systemctl restart telegram-bot
```

### Stop Bot Service

```bash
sudo systemctl stop telegram-bot
```

### Disable Bot Service (Stop Auto-Start)

```bash
sudo systemctl disable telegram-bot
```

---

## 🔥 Troubleshooting

### Bot Doesn't Respond to Commands

**Check service status:**
```bash
sudo systemctl status telegram-bot
```

**Check logs for errors:**
```bash
sudo journalctl -u telegram-bot -n 50
```

**Common issues:**
- Wrong bot token → Edit `bot.py` and fix the token
- Wrong user ID → Edit service file and fix the user ID
- Python library not installed → Run `sudo apt install -y python3-telebot`

### "Could not resolve host: api.telegram.org"

Your server's DNS can't reach Telegram API (common with ISP DNS blocking).

**Fix: Use Google DNS**

```bash
# Override DNS configuration
sudo bash -c 'cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF'

# Make it immutable (prevent NetworkManager from overwriting)
sudo chattr +i /etc/resolv.conf

# Restart bot service
sudo systemctl restart telegram-bot
```

**Verify DNS works:**
```bash
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getMe
```

You should see JSON response with bot information.

### Unauthorized Error

If you get "⛔ Unauthorized" when sending commands:

1. Verify you're using the correct Telegram account
2. Check your user ID: Send `/start` to [@userinfobot](https://t.me/userinfobot)
3. Update the service file with correct user ID:
   ```bash
   sudo nano /etc/systemd/system/telegram-bot.service
   ```
4. Restart the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart telegram-bot
   ```

### Service Fails to Start

**Check for Python errors:**
```bash
sudo journalctl -u telegram-bot -n 50
```

**Test the script manually:**
```bash
cd ~/telegram-bot
python3 bot.py YOUR_USER_ID
```

Look for error messages, then fix the script and restart the service.

### Container Restart Permission Denied

The bot user needs Docker access. Add the user to the Docker group:

```bash
sudo usermod -aG docker YOUR_USERNAME
```

Restart the service:
```bash
sudo systemctl restart telegram-bot
```

---

## 🔐 Security Considerations

### Access Control

- **User ID Restriction**: The bot only accepts commands from your Telegram user ID
- **Local Network**: Bot runs on your server without exposing ports to the internet
- **No Webhooks**: Uses polling (no public URL required)

### Best Practices

1. **Never share your bot token** - Anyone with the token can control your bot
2. **Restrict to your user ID** - Always pass your Telegram user ID when starting the bot
3. **Monitor bot logs** - Check `journalctl -u telegram-bot` regularly for suspicious activity
4. **Limit restart permissions** - Be careful which containers you restart remotely

### Advanced: Using with Tailscale/VPN

If you use Tailscale or another VPN for remote access:

1. The bot works **without** any VPN (Telegram API is public)
2. Your bot communicates with Telegram servers over the internet
3. You send commands from your phone → Telegram servers → Your bot
4. No need to expose your homelab to the internet

This is **safer** than webhooks which require a public URL.

---

## 🎯 Why This Works Better Than Alternatives

### vs n8n Telegram Webhooks

- ❌ n8n webhooks require public internet access
- ❌ n8n polling doesn't have "Get Updates" action
- ❌ Complex offset state management for polling
- ✅ Python bot handles polling automatically
- ✅ Works on local network without port forwarding

### vs Manual SSH

- ❌ SSH requires terminal access
- ❌ Typing commands on phone is slow
- ✅ Telegram bot provides instant status from anywhere
- ✅ Simple commands like `/health` instead of `docker ps`
- ✅ Works on phone, tablet, or any device with Telegram

### vs Portainer API

- ❌ Portainer API requires authentication setup
- ❌ Need to expose Portainer or use VPN
- ✅ Telegram bot is simpler and works immediately
- ✅ No additional authentication needed
- ✅ Familiar Telegram interface

---

## 📚 Additional Resources

- [python-telegram-bot Documentation](https://github.com/eternnoir/pyTelegramBotAPI)
- [Telegram Bot API Reference](https://core.telegram.org/bots/api)
- [systemd Service Management](https://www.freedesktop.org/software/systemd/man/systemctl.html)

---

## 🙏 Credits

Created for simple remote monitoring without exposing your homelab to the internet. Perfect for self-hosters who want quick status checks from their phone.
