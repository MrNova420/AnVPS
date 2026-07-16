#!/usr/bin/env python3
"""AnVPS Web Dashboard — FastAPI Backend"""
import os, json, subprocess, time, platform
from pathlib import Path
from datetime import datetime
from typing import Optional

try:
    from fastapi import FastAPI, HTTPException, BackgroundTasks
    from fastapi.responses import JSONResponse, FileResponse
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn
except ImportError:
    import sys; print("Install fastapi: pip install fastapi uvicorn"); sys.exit(1)

ANVPS_DIR = Path.home() / ".anvps"
app = FastAPI(title="AnVPS Dashboard", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

def run_cmd(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return {"code": r.returncode, "stdout": r.stdout.strip(), "stderr": r.stderr.strip()}
    except subprocess.TimeoutExpired:
        return {"code": -1, "stdout": "", "stderr": "timeout"}
    except Exception as e:
        return {"code": -1, "stdout": "", "stderr": str(e)}

@app.get("/api/status")
def get_status():
    uptime = run_cmd("uptime -p")
    memory = run_cmd("free -h | grep Mem")
    disk = run_cmd(f"df -h {ANVPS_DIR} | tail -1")
    cpu = run_cmd("cat /proc/loadavg | cut -d' ' -f1-3")
    hostname = platform.node()

    services = []
    for pidf in (ANVPS_DIR / "services").glob("*.pid"):
        name = pidf.stem
        pid = pidf.read_text().strip()
        alive = run_cmd(f"kill -0 {pid} 2>/dev/null && echo running || echo stopped")
        if alive["stdout"] == "running":
            mem = run_cmd(f"ps -o rss= -p {pid}")
            services.append({"name": name, "pid": int(pid), "status": "running", "memory": mem["stdout"]})
        else:
            services.append({"name": name, "pid": int(pid), "status": "stopped", "memory": "0"})

    tunnels = {}
    for t in ["cloudflared", "ngrok", "bore"]:
        r = run_cmd(f"pgrep -f {t} >/dev/null 2>&1 && echo active || echo inactive")
        tunnels[t] = r["stdout"]

    return {
        "version": "1.0.0",
        "hostname": hostname,
        "uptime": uptime["stdout"],
        "memory": memory["stdout"],
        "disk": disk["stdout"],
        "cpu": cpu["stdout"],
        "services": services,
        "tunnels": tunnels,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/services")
def list_services():
    services = []
    for pidf in (ANVPS_DIR / "services").glob("*.pid"):
        name = pidf.stem
        pid = pidf.read_text().strip()
        alive = run_cmd(f"kill -0 {pid} 2>/dev/null && echo running || echo stopped")
        services.append({"name": name, "pid": int(pid), "status": alive["stdout"]})
    return {"services": services}

@app.post("/api/services/{name}/start")
def start_service(name: str):
    r = run_cmd(f"bash {ANVPS_DIR}/src/core/{name}.sh start 2>/dev/null")
    if r["code"] == 0:
        return {"status": "ok", "message": f"{name} started"}
    return {"status": "error", "message": r["stderr"] or r["stdout"]}

@app.post("/api/services/{name}/stop")
def stop_service(name: str):
    pidf = ANVPS_DIR / "services" / f"{name}.pid"
    if pidf.exists():
        pid = pidf.read_text().strip()
        run_cmd(f"kill {pid} 2>/dev/null")
        pidf.unlink(missing_ok=True)
        return {"status": "ok", "message": f"{name} stopped"}
    return {"status": "error", "message": f"{name} not running"}

@app.get("/api/logs/{service}")
def get_logs(service: str, lines: int = 50):
    log_file = ANVPS_DIR / "logs" / f"{service}.log"
    if not log_file.exists():
        raise HTTPException(404, f"No logs for {service}")
    content = run_cmd(f"tail -n {lines} {log_file}")
    return {"service": service, "lines": content["stdout"].split("\n")}

@app.get("/api/health")
def health_check():
    r = run_cmd(f"bash {ANVPS_DIR}/src/core/healthcheck.sh")
    return {"status": "ok" if "passed" in r["stdout"].lower() else "issues", "output": r["stdout"]}

@app.get("/api/config")
def get_config():
    config_file = ANVPS_DIR / "etc" / "anvps.conf"
    if config_file.exists():
        config = {}
        for line in config_file.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                config[k.strip()] = v.strip().strip('"')
        return config
    return {}

@app.post("/api/config")
def save_config(data: dict):
    config_file = ANVPS_DIR / "etc" / "anvps.conf"
    with open(config_file, "w") as f:
        for k, v in data.items():
            f.write(f'{k}="{v}"\n')
    run_cmd(":", shell=True)  # noop — config persisted to disk
    return {"status": "ok"}

@app.get("/api/storage")
def storage_info():
    usage = run_cmd(f"du -sh {ANVPS_DIR}")
    df_out = run_cmd(f"df -h {ANVPS_DIR} | tail -1")
    return {"anvps_usage": usage["stdout"], "disk": df_out["stdout"]}

@app.post("/api/backup")
def create_backup():
    r = run_cmd(f"bash {ANVPS_DIR}/src/cli/anvps backup create")
    return {"status": "ok" if r["code"] == 0 else "error", "output": r["stdout"]}

@app.get("/api/backups")
def list_backups():
    backup_dir = ANVPS_DIR / "backup"
    backups = []
    for f in sorted(backup_dir.glob("*.tar.gz"), reverse=True):
        stat = f.stat()
        backups.append({"name": f.name, "size": stat.st_size, "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()})
    return {"backups": backups}

if __name__ == "__main__":
    port = int(os.environ.get("ANVPS_WEB_PORT", "7080"))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
