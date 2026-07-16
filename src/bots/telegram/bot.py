#!/usr/bin/env python3
"""AnVPS Telegram Bot — Remote management via Telegram"""
import os, sys, subprocess, asyncio, json, logging
from pathlib import Path

try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
except ImportError:
    print("Install: pip install python-telegram-bot"); sys.exit(1)

ANVPS_DIR = Path.home() / ".anvps"
TOKEN = os.environ.get("ANVPS_TELEGRAM_BOT_TOKEN", "")
CHAT_ID = os.environ.get("ANVPS_TELEGRAM_CHAT_ID", "")
ALLOWED_IDS = [int(x) for x in os.environ.get("ANVPS_TELEGRAM_ALLOWED_IDS", CHAT_ID).split(",") if x]

logging.basicConfig(level=logging.WARN, format="%(asctime)s [%(levelname)s] %(message)s")

def run_cmd(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() or r.stderr.strip()
    except subprocess.TimeoutExpired:
        return "Command timed out"
    except Exception as e:
        return str(e)

def check_auth(update):
    uid = update.effective_user.id
    if ALLOWED_IDS and uid not in ALLOWED_IDS:
        return False
    return True

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    await update.message.reply_text(
        "AnVPS Bot — Android VPS Manager\n\n"
        "/status — System status\n"
        "/services — List services\n"
        "/start <name> — Start a service\n"
        "/stop <name> — Stop a service\n"
        "/logs <name> — View service logs\n"
        "/health — Health check\n"
        "/backup — Create backup\n"
        "/update — Run updates\n"
        "/help — This message"
    )

async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    uptime = run_cmd("uptime -p")
    mem = run_cmd("free -h | grep Mem | awk '{print $3\"/\"$2}'")
    cpu = run_cmd("cat /proc/loadavg | cut -d' ' -f1-3")
    disk = run_cmd(f"df -h {ANVPS_DIR} | tail -1 | awk '{{print $3\"/\"$2\" (\"$5\")\"}}'")
    svc = run_cmd("ls " + str(ANVPS_DIR / "services/*.pid") + " 2>/dev/null | wc -l")
    msg = (
        f"AnVPS Status\n"
        f"Uptime: {uptime}\n"
        f"CPU: {cpu}\n"
        f"Memory: {mem}\n"
        f"Disk: {disk}\n"
        f"Services: {svc} running"
    )
    await update.message.reply_text(msg)

async def cmd_services(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    svc_dir = ANVPS_DIR / "services"
    services = []
    for pidf in svc_dir.glob("*.pid"):
        name = pidf.stem
        pid = pidf.read_text().strip()
        alive = run_cmd(f"kill -0 {pid} 2>/dev/null && echo running || echo stopped")
        services.append(f"{name}: {alive} (PID {pid})")
    if services:
        await update.message.reply_text("Services:\n" + "\n".join(services))
    else:
        await update.message.reply_text("No services registered")

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    if not context.args:
        await update.message.reply_text("Usage: /start <service_name>")
        return
    name = context.args[0]
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core' / f'{name}.sh'} start 2>/dev/null")
    await update.message.reply_text(f"Start {name}: {r[:500]}")

async def cmd_stop(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    if not context.args:
        await update.message.reply_text("Usage: /stop <service_name>")
        return
    name = context.args[0]
    pidf = ANVPS_DIR / "services" / f"{name}.pid"
    if pidf.exists():
        pid = pidf.read_text().strip()
        run_cmd(f"kill {pid} 2>/dev/null")
        pidf.unlink(missing_ok=True)
        await update.message.reply_text(f"Stopped {name}")
    else:
        await update.message.reply_text(f"{name} not running")

async def cmd_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    name = context.args[0] if context.args else "ssh"
    logf = ANVPS_DIR / "logs" / f"{name}.log"
    if not logf.exists():
        await update.message.reply_text(f"No logs for {name}")
        return
    lines = run_cmd(f"tail -n 20 {logf}")
    await update.message.reply_text(f"Logs ({name}):\n{lines[:2000]}")

async def cmd_health(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core/healthcheck.sh'}")
    await update.message.reply_text(f"Health check:\n{r[:1500]}")

async def cmd_backup(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    r = run_cmd(f"bash {ANVPS_DIR / 'src/cli/anvps'} backup create")
    await update.message.reply_text(f"Backup: {r[:500]}")

async def cmd_update(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not check_auth(update): return
    await update.message.reply_text("Running updates...")
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core/autoupdate.sh'}", timeout=120)
    await update.message.reply_text(f"Update complete:\n{r[:1500]}")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logging.error(f"Exception: {context.error}")

def main():
    if not TOKEN:
        print("Set ANVPS_TELEGRAM_BOT_TOKEN environment variable")
        sys.exit(1)
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("services", cmd_services))
    app.add_handler(CommandHandler("start_service", cmd_start))
    app.add_handler(CommandHandler("stop_service", cmd_stop))
    app.add_handler(CommandHandler("logs", cmd_logs))
    app.add_handler(CommandHandler("health", cmd_health))
    app.add_handler(CommandHandler("backup", cmd_backup))
    app.add_handler(CommandHandler("update", cmd_update))
    app.add_handler(CommandHandler("help", start))
    app.add_error_handler(error_handler)
    print("AnVPS Telegram bot started")
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
