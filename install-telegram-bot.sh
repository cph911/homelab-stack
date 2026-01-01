#!/bin/bash

# Telegram Health Bot Installer
# Interactive setup script for homelab container monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root or with sudo"
    log_info "Run it as a normal user: ./install-telegram-bot.sh"
    exit 1
fi

print_header "🤖 Telegram Health Bot Installer"

log_info "This script will install and configure the Telegram Health Bot"
log_info "for monitoring your Docker containers remotely.\n"

# Step 1: Check Prerequisites
print_header "Step 1: Checking Prerequisites"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    log_info "Please install Docker first and add your user to the docker group"
    exit 1
fi
log_success "Docker installed"

# Check if user is in docker group
if ! groups | grep -q docker; then
    log_error "Current user is not in the docker group"
    log_info "Run: sudo usermod -aG docker $USER"
    log_info "Then logout and login again"
    exit 1
fi
log_success "User is in docker group"

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    log_error "Python3 is not installed"
    log_info "Run: sudo apt install -y python3"
    exit 1
fi
log_success "Python3 installed"

# Check if python3-telebot is installed
if ! python3 -c "import telebot" &> /dev/null; then
    log_warning "python3-telebot is not installed"
    read -p "Install python3-telebot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installing python3-telebot..."
        sudo apt update
        sudo apt install -y python3-telebot
        log_success "python3-telebot installed"
    else
        log_error "python3-telebot is required. Exiting."
        exit 1
    fi
else
    log_success "python3-telebot installed"
fi

# Step 2: Get Bot Credentials
print_header "Step 2: Bot Configuration"

log_info "You need to create a bot with @BotFather first."
log_info "Instructions:"
log_info "  1. Open Telegram and search for @BotFather"
log_info "  2. Send /newbot command"
log_info "  3. Follow prompts to create your bot"
log_info "  4. Copy the bot token (looks like: 1234567890:ABCdefGHI...)"
echo

read -p "Enter your Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    log_error "Bot token cannot be empty"
    exit 1
fi

# Validate bot token format (basic check)
if [[ ! $BOT_TOKEN =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    log_error "Invalid bot token format"
    log_info "Token should look like: 1234567890:ABCdefGHIjklMNO..."
    exit 1
fi

log_success "Bot token received"
echo

log_info "Now you need your Telegram user ID."
log_info "Instructions:"
log_info "  1. Open Telegram and search for @userinfobot"
log_info "  2. Send /start command"
log_info "  3. Copy your user ID (numeric only)"
echo

read -p "Enter your Telegram User ID: " USER_ID

if [ -z "$USER_ID" ]; then
    log_error "User ID cannot be empty"
    exit 1
fi

# Validate user ID is numeric
if ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; then
    log_error "User ID must be numeric"
    log_info "Example: 123456789"
    exit 1
fi

log_success "User ID received"

# Step 3: Create Bot Directory and Script
print_header "Step 3: Creating Bot Files"

BOT_DIR="$HOME/telegram-bot"
mkdir -p "$BOT_DIR"
log_success "Created directory: $BOT_DIR"

# Create bot.py with credentials
cat > "$BOT_DIR/bot.py" << 'BOTSCRIPT'
#!/usr/bin/env python3
import telebot
from telebot import types
import subprocess
import sys

# Configuration
BOT_TOKEN = "BOT_TOKEN_PLACEHOLDER"
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
BOTSCRIPT

# Replace placeholders with actual credentials
sed -i "s/BOT_TOKEN_PLACEHOLDER/$BOT_TOKEN/g" "$BOT_DIR/bot.py"

chmod +x "$BOT_DIR/bot.py"
log_success "Created bot script with your credentials"

# Step 4: Create systemd Service
print_header "Step 4: Setting Up Systemd Service"

CURRENT_USER=$(whoami)
SERVICE_FILE="/etc/systemd/system/telegram-bot.service"

log_info "Creating systemd service file..."

sudo bash -c "cat > $SERVICE_FILE" << SERVICEFILE
[Unit]
Description=Telegram Homelab Health Bot
After=network.target docker.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$BOT_DIR
ExecStart=/usr/bin/python3 $BOT_DIR/bot.py $USER_ID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEFILE

log_success "Created systemd service file"

# Step 5: Enable and Start Service
print_header "Step 5: Starting Bot Service"

log_info "Reloading systemd daemon..."
sudo systemctl daemon-reload
log_success "Daemon reloaded"

log_info "Enabling service to start on boot..."
sudo systemctl enable telegram-bot
log_success "Service enabled"

log_info "Starting bot service..."
sudo systemctl start telegram-bot
sleep 2
log_success "Service started"

# Step 6: Verify Installation
print_header "Step 6: Verification"

if sudo systemctl is-active --quiet telegram-bot; then
    log_success "Bot service is running!"

    echo
    log_info "Service status:"
    sudo systemctl status telegram-bot --no-pager -l

    echo
    log_success "✅ Installation complete!"
    echo
    log_info "Next steps:"
    log_info "  1. Open Telegram and search for your bot"
    log_info "  2. Send /start to begin"
    log_info "  3. Type / to see available commands"
    log_info "  4. Try /health to see container status"
    log_info "  5. Try /restart to see interactive menu"
    echo
    log_info "Useful commands:"
    log_info "  - View logs: sudo journalctl -u telegram-bot -f"
    log_info "  - Restart bot: sudo systemctl restart telegram-bot"
    log_info "  - Stop bot: sudo systemctl stop telegram-bot"
    log_info "  - Check status: sudo systemctl status telegram-bot"
    echo
else
    log_error "Bot service failed to start"
    log_info "Check logs with: sudo journalctl -u telegram-bot -n 50"
    exit 1
fi
