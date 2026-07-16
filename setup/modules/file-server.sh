#!/usr/bin/env bash
install_file_server() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local FILE_PORT="${3:-7444}"

    log "Installing file server..."

    local SHARE_DIR="${ANVPS_DIR}/data/files"
    mkdir -p "$SHARE_DIR"
    mkdir -p "${SHARE_DIR}/shared"
    mkdir -p "${SHARE_DIR}/torrents"
    mkdir -p "${SHARE_DIR}/backups"

    case "$ENV_TYPE" in
        termux)
            pkg install -y python 2>/dev/null || true
            pip install aiohttp aiofiles 2>/dev/null || true
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y python3-aiohttp 2>/dev/null || pip3 install aiohttp 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add py3-aiohttp 2>/dev/null || pip3 install aiohttp 2>/dev/null || true
            fi
            ;;
    esac

    cat > "${ANVPS_DIR}/src/core/file-server.py" << 'PY'
#!/usr/bin/env python3
import os, json, hashlib, mimetypes, shutil
from pathlib import Path
from datetime import datetime
try:
    from aiohttp import web
except ImportError:
    import http.server
    import socketserver
    PORT = int(os.environ.get("FILE_PORT", "7444"))
    DIRECTORY = os.environ.get("SHARE_DIR", os.path.expanduser("~/.anvps/data/files/shared"))
    os.chdir(DIRECTORY)
    Handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"File server on http://0.0.0.0:{PORT}")
        httpd.serve_forever()

CHUNK_SIZE = 64 * 1024

async def handle_list(request):
    base = Path(os.environ.get("SHARE_DIR", str(Path.home() / ".anvps/data/files/shared")))
    items = []
    for p in base.iterdir():
        items.append({
            "name": p.name,
            "is_dir": p.is_dir(),
            "size": p.stat().st_size if p.is_file() else 0,
            "mtime": p.stat().st_mtime
        })
    return web.json_response(sorted(items, key=lambda x: x["name"]))

async def handle_download(request):
    name = request.match_info["name"]
    base = Path(os.environ.get("SHARE_DIR", str(Path.home() / ".anvps/data/files/shared")))
    filepath = base / name
    if not filepath.exists() or filepath.is_dir():
        return web.json_response({"error": "not found"}, status=404)
    return web.FileResponse(filepath)

async def handle_upload(request):
    reader = await request.multipart()
    field = await reader.next()
    if not field:
        return web.json_response({"error": "no file"}, status=400)
    filename = field.filename
    base = Path(os.environ.get("SHARE_DIR", str(Path.home() / ".anvps/data/files/shared")))
    filepath = base / filename
    with open(filepath, "wb") as f:
        while True:
            chunk = await field.read_chunk(CHUNK_SIZE)
            if not chunk:
                break
            f.write(chunk)
    return web.json_response({"status": "ok", "file": filename})

async def handle_delete(request):
    data = await request.json()
    name = data.get("name")
    base = Path(os.environ.get("SHARE_DIR", str(Path.home() / ".anvps/data/files/shared")))
    filepath = base / name
    if filepath.exists():
        if filepath.is_dir():
            shutil.rmtree(filepath)
        else:
            filepath.unlink()
        return web.json_response({"status": "deleted"})
    return web.json_response({"error": "not found"}, status=404)

app = web.Application()
app.router.add_get("/api/list", handle_list)
app.router.add_get("/api/download/{name}", handle_download)
app.router.add_post("/api/upload", handle_upload)
app.router.add_delete("/api/delete", handle_delete)
app.router.add_static("/", Path(os.environ.get("SHARE_DIR", str(Path.home() / ".anvps/data/files/shared"))))

if __name__ == "__main__":
    PORT = int(os.environ.get("FILE_PORT", "7444"))
    web.run_app(app, host="0.0.0.0", port=PORT)
PY
    chmod +x "${ANVPS_DIR}/src/core/file-server.py"
    log "File server script installed (port: $FILE_PORT)"
}
