#!/usr/bin/env python3
"""AnVPS Web Dashboard — Zero-dependency Python backend (stdlib only)
Serves both the API and static frontend files on a single port."""
import os, json, subprocess, platform, re, urllib.parse, mimetypes
from pathlib import Path
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

ANVPS_DIR = Path.home() / ".anvps"
WWW_DIR = ANVPS_DIR / "data" / "sites" / "default"
PORT = int(os.environ.get("ANVPS_WEB_PORT", "7080"))

def run_cmd(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return {"code": r.returncode, "stdout": r.stdout.strip(), "stderr": r.stderr.strip()}
    except subprocess.TimeoutExpired:
        return {"code": -1, "stdout": "", "stderr": "timeout"}
    except Exception as e:
        return {"code": -1, "stdout": "", "stderr": str(e)}

class Handler(BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())

    def _send_file(self, path, status=200):
        ctype, _ = mimetypes.guess_type(str(path))
        if not ctype:
            ctype = "application/octet-stream"
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        with open(path, "rb") as f:
            self.wfile.write(f.read())

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length)) if length else {}

    def _serve_static(self, path):
        safe = Path(path).relative_to("/")
        file = WWW_DIR / safe
        if file.is_file():
            self._send_file(file)
        else:
            index = WWW_DIR / "index.html"
            if index.is_file():
                self._send_file(index)
            else:
                self._send_json({"error": "not found"}, 404)

    def do_OPTIONS(self):
        self._send_json({})

    def _api_route(self, method, path, params, body):
        # Status
        if path == "/api/status" and method == "GET":
            return self._send_json({
                "version": "1.0.0",
                "hostname": platform.node(),
                "uptime": run_cmd("uptime -p")["stdout"],
                "memory": run_cmd("free -h | grep Mem")["stdout"],
                "disk": run_cmd(f"df -h {ANVPS_DIR} | tail -1")["stdout"],
                "cpu": run_cmd("cat /proc/loadavg | cut -d' ' -f1-3")["stdout"],
                "services": self._scan_services(),
                "tunnels": self._scan_tunnels(),
                "timestamp": datetime.now().isoformat()
            })

        # Services list
        if path == "/api/services" and method == "GET":
            return self._send_json({"services": self._scan_services()})

        # Service start/stop
        m = re.match(r"^/api/services/(\w+)/(start|stop)$", path)
        if m:
            name, action = m.group(1), m.group(2)
            if action == "start":
                r = run_cmd(f"bash {ANVPS_DIR}/src/core/{name}.sh start 2>/dev/null")
                ok = r["code"] == 0
                return self._send_json({"status": "ok" if ok else "error", "message": f"{name} started" if ok else r["stderr"] or r["stdout"]})
            pidf = ANVPS_DIR / "services" / f"{name}.pid"
            if pidf.exists():
                pid = pidf.read_text().strip()
                run_cmd(f"kill {pid} 2>/dev/null")
                pidf.unlink(missing_ok=True)
                return self._send_json({"status": "ok", "message": f"{name} stopped"})
            return self._send_json({"status": "error", "message": f"{name} not running"}, 404)

        # Logs
        m = re.match(r"^/api/logs/(\w+)$", path)
        if m and method == "GET":
            service = m.group(1)
            log_file = ANVPS_DIR / "logs" / f"{service}.log"
            if not log_file.exists():
                return self._send_json({"error": f"No logs for {service}"}, 404)
            lines = int(params.get("lines", 50))
            content = run_cmd(f"tail -n {lines} {log_file}")
            return self._send_json({"service": service, "lines": content["stdout"].split("\n")})

        # Health
        if path == "/api/health" and method == "GET":
            r = run_cmd(f"bash {ANVPS_DIR}/src/core/healthcheck.sh")
            return self._send_json({"status": "ok" if "passed" in r["stdout"].lower() else "issues", "output": r["stdout"]})

        # Config
        config_file = ANVPS_DIR / "etc" / "anvps.conf"
        if path == "/api/config":
            if method == "GET":
                config = {}
                if config_file.exists():
                    for line in config_file.read_text().splitlines():
                        if "=" in line and not line.startswith("#"):
                            k, v = line.split("=", 1)
                            config[k.strip()] = v.strip().strip('"')
                return self._send_json(config)
            if method == "POST":
                data = body
                with open(config_file, "w") as f:
                    for k, v in data.items():
                        f.write(f'{k}="{v}"\n')
                return self._send_json({"status": "ok"})

        # Storage
        if path == "/api/storage" and method == "GET":
            usage = run_cmd(f"du -sh {ANVPS_DIR}")
            df_out = run_cmd(f"df -h {ANVPS_DIR} | tail -1")
            return self._send_json({"anvps_usage": usage["stdout"], "disk": df_out["stdout"]})

        # Backups
        if path == "/api/backup":
            if method == "POST":
                r = run_cmd(f"bash {ANVPS_DIR}/src/cli/anvps backup create")
                return self._send_json({"status": "ok" if r["code"] == 0 else "error", "output": r["stdout"]})
            return self._send_json({"error": "use POST"}, 405)

        if path == "/api/backups" and method == "GET":
            backup_dir = ANVPS_DIR / "backup"
            backups = []
            if backup_dir.exists():
                for f in sorted(backup_dir.glob("*.tar.gz"), reverse=True):
                    stat = f.stat()
                    backups.append({"name": f.name, "size": stat.st_size, "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()})
            return self._send_json({"backups": backups})

        return None  # not an API route

    def _scan_services(self):
        services = []
        svc_dir = ANVPS_DIR / "services"
        if svc_dir.exists():
            for pidf in sorted(svc_dir.glob("*.pid")):
                name = pidf.stem
                pid = pidf.read_text().strip()
                alive = run_cmd(f"kill -0 {pid} 2>/dev/null && echo running || echo stopped")
                if alive["stdout"] == "running":
                    mem = run_cmd(f"ps -o rss= -p {pid}")["stdout"]
                    services.append({"name": name, "pid": int(pid), "status": "running", "memory": mem})
                else:
                    services.append({"name": name, "pid": int(pid), "status": "stopped", "memory": "0"})
        return services

    def _scan_tunnels(self):
        tunnels = {}
        for t in ["cloudflared", "ngrok", "bore"]:
            r = run_cmd(f"pgrep -f {t} >/dev/null 2>&1 && echo active || echo inactive")
            tunnels[t] = r["stdout"]
        return tunnels

    def _route(self):
        p = urllib.parse.urlparse(self.path)
        path = p.path.rstrip("/")
        params = {k: v[0] for k, v in urllib.parse.parse_qs(p.query).items()}
        method = self.command
        body = self._read_body() if method == "POST" else {}

        # Try API first
        result = self._api_route(method, path, params, body)
        if result is not None:
            return

        # Serve static files for non-API paths
        if method == "GET":
            self._serve_static(path)
        else:
            self._send_json({"error": "not found"}, 404)

    def do_GET(self):
        self._route()

    def do_POST(self):
        self._route()

class ThreadedServer(ThreadingMixIn, HTTPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    # Create www dir with placeholder if empty
    WWW_DIR.mkdir(parents=True, exist_ok=True)
    index = WWW_DIR / "index.html"
    if not index.exists():
        index.write_text("<html><body><h1>AnVPS</h1><p>Dashboard loading...</p></body></html>")
    server = ThreadedServer(("0.0.0.0", PORT), Handler)
    print(f"AnVPS Web Dashboard running on http://0.0.0.0:{PORT}")
    server.serve_forever()
