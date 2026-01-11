#!/usr/bin/env python3
import telebot
from telebot import types
import subprocess
import sys
import time
import os
import datetime
import threading

# Configuration
BOT_TOKEN = "YOUR_BOT_TOKEN_HERE"
ALLOWED_USER_ID = None
LOG_DIR = os.path.expanduser("~/telegram-bot-logs")
NOTIFICATION_COOLDOWN = 3600  # Don't re-notify for same container within 1 hour

# Global state tracking for container health monitoring
container_states = {}
last_failure_notification = {}  # Track when we last notified for each container

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

def wait_for_containers(max_wait=120, check_interval=5):
    """Wait for containers to be up and return count"""
    print("🔍 Waiting for containers to start...")
    start_time = time.time()

    while (time.time() - start_time) < max_wait:
        containers = get_containers()
        if len(containers) > 0:
            # Wait a bit more to ensure they're stable
            time.sleep(10)
            return containers
        time.sleep(check_interval)

    return []

def ensure_log_directory():
    """Create log directory if it doesn't exist"""
    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)
        print(f"✅ Created log directory: {LOG_DIR}")

def get_all_containers():
    """Get list of ALL containers (including stopped ones)"""
    try:
        result = subprocess.run(
            ['docker', 'ps', '-a', '--format', '{{.Names}}|{{.State}}|{{.Status}}'],
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
        print(f"❌ Error getting all containers: {e}")
        return []

def save_container_logs(container_name):
    """Save container logs to a file"""
    try:
        ensure_log_directory()
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = os.path.join(LOG_DIR, f"{container_name}_{timestamp}.log")

        # Get last 500 lines of logs
        result = subprocess.run(
            ['docker', 'logs', '--tail', '500', container_name],
            capture_output=True, text=True, timeout=30
        )

        with open(log_file, 'w') as f:
            f.write(f"Container: {container_name}\n")
            f.write(f"Timestamp: {datetime.datetime.now()}\n")
            f.write(f"{'='*50}\n\n")
            f.write(result.stdout)
            if result.stderr:
                f.write("\n\n--- STDERR ---\n")
                f.write(result.stderr)

        print(f"✅ Saved logs for {container_name} to {log_file}")
        return log_file
    except Exception as e:
        print(f"❌ Failed to save logs for {container_name}: {e}")
        return None

def check_container_health():
    """Check container health and notify on failures"""
    global container_states, last_failure_notification

    if not ALLOWED_USER_ID:
        return

    containers = get_all_containers()
    if not containers:
        return

    current_states = {c['name']: c['state'] for c in containers}

    # Detect failures (running -> exited/stopped/dead)
    failed_containers = []
    for name, current_state in current_states.items():
        previous_state = container_states.get(name)

        # Only alert if container went from running to not running
        if previous_state == 'running' and current_state in ['exited', 'dead', 'stopped', 'paused']:
            failed_containers.append({
                'name': name,
                'previous_state': previous_state,
                'current_state': current_state,
                'status': next((c['status'] for c in containers if c['name'] == name), 'unknown')
            })

    # Send notifications for failed containers
    for failed in failed_containers:
        try:
            # Check if we're in cooldown period for this container
            current_time = time.time()
            last_notified = last_failure_notification.get(failed['name'], 0)

            if current_time - last_notified < NOTIFICATION_COOLDOWN:
                print(f"⏭️ Skipping notification for {failed['name']} (cooldown: {int((NOTIFICATION_COOLDOWN - (current_time - last_notified)) / 60)} minutes remaining)")
                continue

            # Save logs
            log_file = save_container_logs(failed['name'])

            # Build notification message
            message = f"🚨 *Container Failed!*\n\n"
            message += f"Container: *{failed['name']}*\n"
            message += f"Previous State: {failed['previous_state']}\n"
            message += f"Current State: {failed['current_state']}\n"
            message += f"Status: {failed['status']}\n\n"

            if log_file:
                message += f"📝 Logs saved to:\n`{log_file}`\n\n"

            message += f"_Detected at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_"

            # Send notification
            bot.send_message(ALLOWED_USER_ID, message, parse_mode='Markdown')
            last_failure_notification[failed['name']] = current_time
            print(f"🚨 Sent failure notification for {failed['name']}")

        except Exception as e:
            print(f"❌ Failed to send notification for {failed['name']}: {e}")

    # Clear cooldown for containers that are now running (recovered)
    for name, state in current_states.items():
        if state == 'running' and name in last_failure_notification:
            del last_failure_notification[name]
            print(f"✅ {name} recovered - cooldown cleared")

    # Update state tracking
    container_states = current_states

def periodic_health_check():
    """Run health check every 10 minutes"""
    global container_states

    # Initialize container states on first run
    print("🔍 Initializing container health monitoring...")
    try:
        containers = get_all_containers()
        container_states = {c['name']: c['state'] for c in containers}
        print(f"✅ Initialized monitoring for {len(container_states)} containers")
    except Exception as e:
        print(f"❌ Failed to initialize container states: {e}")

    # Wait 10 minutes before first check (to avoid false positives at startup)
    time.sleep(600)

    while True:
        try:
            print("🔍 Running periodic health check...")
            check_container_health()
        except Exception as e:
            print(f"❌ Error in periodic health check: {e}")

        # Wait 10 minutes
        time.sleep(600)

def send_startup_notification():
    """Send notification when homelab comes online"""
    if not ALLOWED_USER_ID:
        return

    try:
        # Wait for containers to start
        containers = wait_for_containers()

        if not containers:
            print("⚠️ No containers found after waiting")
            return

        # Build startup message
        running_count = sum(1 for c in containers if c['state'] == 'running')
        total_count = len(containers)

        message = f"🚀 *Homelab is Online!*\n\n"
        message += f"✅ {running_count}/{total_count} containers running\n\n"

        # List key services
        key_services = ['cosmos', 'jellyfin', 'n8n', 'postgres', 'portainer', 'uptime-kuma', 'pihole']
        found_services = []

        for container in containers:
            for service in key_services:
                if service in container['name'].lower():
                    emoji = "✅" if container['state'] == 'running' else "❌"
                    found_services.append(f"{emoji} {container['name']}")
                    break

        if found_services:
            message += "*Key Services:*\n"
            message += "\n".join(found_services)

        message += "\n\n_Ready to serve! 🎉_"

        # Send notification
        bot.send_message(ALLOWED_USER_ID, message, parse_mode='Markdown')
        print(f"✅ Startup notification sent to user {ALLOWED_USER_ID}")

    except Exception as e:
        print(f"❌ Failed to send startup notification: {e}")

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

@bot.message_handler(commands=['stop'])
def stop_container(message):
    if ALLOWED_USER_ID and message.from_user.id != ALLOWED_USER_ID:
        bot.reply_to(message, "⛔ Unauthorized")
        return

    # Check if container name was provided
    args = message.text.split()
    if len(args) >= 2:
        # Direct stop with container name
        container_name = args[1]
        try:
            subprocess.run(['docker', 'stop', container_name], check=True, timeout=30)
            bot.reply_to(message, f"🛑 Stopped *{container_name}*", parse_mode='Markdown')
        except subprocess.CalledProcessError as e:
            bot.reply_to(message, f"❌ Failed to stop *{container_name}*\nError: {str(e)}", parse_mode='Markdown')
        except Exception as e:
            bot.reply_to(message, f"❌ Error: {str(e)}")
        return

    # No container name provided - show selection menu
    containers = get_containers()
    if not containers:
        bot.reply_to(message, "❌ No running containers found")
        return

    # Create inline keyboard with container buttons
    markup = types.InlineKeyboardMarkup(row_width=2)
    buttons = []

    for container in containers:
        emoji = "✅" if container['state'] == 'running' else "❌"
        button = types.InlineKeyboardButton(
            text=f"{emoji} {container['name']}",
            callback_data=f"stop:{container['name']}"
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

    bot.reply_to(message, "🛑 *Select container to stop:*", reply_markup=markup, parse_mode='Markdown')

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

    if call.data.startswith("stop:"):
        container_name = call.data.split(":", 1)[1]

        # Update message to show stopping status
        bot.edit_message_text(
            f"🛑 Stopping *{container_name}*...",
            call.message.chat.id,
            call.message.message_id,
            parse_mode='Markdown'
        )

        try:
            # Stop the container
            subprocess.run(['docker', 'stop', container_name], check=True, timeout=30)

            # Update message with success
            bot.edit_message_text(
                f"🛑 Successfully stopped *{container_name}*",
                call.message.chat.id,
                call.message.message_id,
                parse_mode='Markdown'
            )
            bot.answer_callback_query(call.id, f"🛑 {container_name} stopped")

        except subprocess.CalledProcessError as e:
            bot.edit_message_text(
                f"❌ Failed to stop *{container_name}*\n\nError: Container not found or stop failed",
                call.message.chat.id,
                call.message.message_id,
                parse_mode='Markdown'
            )
            bot.answer_callback_query(call.id, f"❌ Stop failed", show_alert=True)

        except Exception as e:
            bot.edit_message_text(
                f"❌ Error stopping *{container_name}*\n\n{str(e)}",
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
/stop - Stop a container (shows menu)
/help - Show this message

Type / to see all commands!""", parse_mode='Markdown')

def setup_commands():
    """Set bot commands for the menu"""
    try:
        commands = [
            types.BotCommand("health", "Check container health status"),
            types.BotCommand("restart", "Restart a container"),
            types.BotCommand("stop", "Stop a container"),
            types.BotCommand("help", "Show help message")
        ]
        bot.set_my_commands(commands)
        print("✅ Bot commands configured")
    except Exception as e:
        print(f"⚠️ Warning: Could not set bot commands (bot will still work): {e}")
        print("   This is usually due to DNS issues. Commands can be set later.")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        ALLOWED_USER_ID = int(sys.argv[1])
        print(f"🔒 Restricted to user: {ALLOWED_USER_ID}")

    # Set up command menu
    setup_commands()

    # Send startup notification (runs in background)
    startup_thread = threading.Thread(target=send_startup_notification)
    startup_thread.daemon = True
    startup_thread.start()

    # Start periodic health monitoring (runs in background)
    health_check_thread = threading.Thread(target=periodic_health_check)
    health_check_thread.daemon = True
    health_check_thread.start()

    print("🤖 Bot started!")
    print("📬 Startup notification will be sent once containers are ready...")
    print("🏥 Health monitoring will check containers every 10 minutes...")

    # Start polling with retry logic for network issues
    while True:
        try:
            bot.infinity_polling(timeout=30, long_polling_timeout=30)
        except Exception as e:
            print(f"❌ Bot polling error: {e}")
            print("🔄 Retrying in 15 seconds...")
            time.sleep(15)
