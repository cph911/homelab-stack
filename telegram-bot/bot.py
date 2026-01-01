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
