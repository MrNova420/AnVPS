#!/usr/bin/env python3
"""AnVPS Discord Bot — Remote management via Discord"""
import os, sys, subprocess, asyncio
from pathlib import Path

try:
    import discord
    from discord.ext import commands
except ImportError:
    print("Install: pip install discord.py"); sys.exit(1)

ANVPS_DIR = Path.home() / ".anvps"
TOKEN = os.environ.get("ANVPS_DISCORD_BOT_TOKEN", "")

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="an!", intents=intents, help_command=None)

def run_cmd(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() or r.stderr.strip()
    except subprocess.TimeoutExpired:
        return "Command timed out"
    except Exception as e:
        return str(e)

@bot.event
async def on_ready():
    print(f"AnVPS Discord bot logged in as {bot.user}")

@bot.command(name="status")
async def cmd_status(ctx):
    uptime = run_cmd("uptime -p")
    mem = run_cmd("free -h | grep Mem | awk '{print $3\"/\"$2}'")
    cpu = run_cmd("cat /proc/loadavg | cut -d' ' -f1-3")
    disk = run_cmd(f"df -h {ANVPS_DIR} | tail -1 | awk '{{print $3\"/\"$2\" (\"$5\")\"}}'")
    embed = discord.Embed(title="AnVPS Status", color=0x2ea043)
    embed.add_field(name="Uptime", value=uptime, inline=True)
    embed.add_field(name="CPU", value=cpu, inline=True)
    embed.add_field(name="Memory", value=mem, inline=True)
    embed.add_field(name="Disk", value=disk, inline=False)
    await ctx.send(embed=embed)

@bot.command(name="services")
async def cmd_services(ctx):
    svc_dir = ANVPS_DIR / "services"
    lines = []
    for pidf in svc_dir.glob("*.pid"):
        name = pidf.stem
        pid = pidf.read_text().strip()
        alive = run_cmd(f"kill -0 {pid} 2>/dev/null && echo running || echo stopped")
        lines.append(f"**{name}**: {alive} (PID {pid})")
    msg = "\n".join(lines) if lines else "No services registered"
    await ctx.send(embed=discord.Embed(title="Services", description=msg, color=0x58a6ff))

@bot.command(name="start")
async def cmd_start(ctx, name: str):
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core' / f'{name}.sh'} start 2>/dev/null")
    await ctx.send(f"Starting **{name}**: {r[:500]}")

@bot.command(name="stop")
async def cmd_stop(ctx, name: str):
    pidf = ANVPS_DIR / "services" / f"{name}.pid"
    if pidf.exists():
        pid = pidf.read_text().strip()
        run_cmd(f"kill {pid} 2>/dev/null")
        pidf.unlink(missing_ok=True)
        await ctx.send(f"Stopped **{name}**")
    else:
        await ctx.send(f"**{name}** is not running")

@bot.command(name="logs")
async def cmd_logs(ctx, name: str = "ssh", lines: int = 15):
    logf = ANVPS_DIR / "logs" / f"{name}.log"
    if not logf.exists():
        await ctx.send(f"No logs for **{name}**")
        return
    output = run_cmd(f"tail -n {lines} {logf}")
    await ctx.send(f"Logs (**{name}**):\n```\n{output[:1800]}\n```")

@bot.command(name="health")
async def cmd_health(ctx):
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core/healthcheck.sh'}")
    await ctx.send(f"Health check:\n```\n{r[:1800]}\n```")

@bot.command(name="backup")
async def cmd_backup(ctx):
    await ctx.send("Creating backup...")
    r = run_cmd(f"bash {ANVPS_DIR / 'src/cli/anvps'} backup create", timeout=60)
    await ctx.send(f"Backup result:\n```\n{r[:1800]}\n```")

@bot.command(name="update")
async def cmd_update(ctx):
    await ctx.send("Running updates...")
    r = run_cmd(f"bash {ANVPS_DIR / 'src/core/autoupdate.sh'}", timeout=120)
    await ctx.send(f"Update complete:\n```\n{r[:1800]}\n```")

@bot.command(name="help")
async def cmd_help(ctx):
    embed = discord.Embed(title="AnVPS Bot Commands", color=0x2ea043)
    embed.add_field(name="an!status", value="System status", inline=False)
    embed.add_field(name="an!services", value="List services", inline=False)
    embed.add_field(name="an!start <name>", value="Start a service", inline=False)
    embed.add_field(name="an!stop <name>", value="Stop a service", inline=False)
    embed.add_field(name="an!logs [name]", value="View service logs", inline=False)
    embed.add_field(name="an!health", value="Run health check", inline=False)
    embed.add_field(name="an!backup", value="Create backup", inline=False)
    embed.add_field(name="an!update", value="Run system update", inline=False)
    await ctx.send(embed=embed)

def main():
    if not TOKEN:
        print("Set ANVPS_DISCORD_BOT_TOKEN environment variable")
        sys.exit(1)
    bot.run(TOKEN)

if __name__ == "__main__":
    main()
