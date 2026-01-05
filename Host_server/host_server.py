from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import time
import json
import os

app = Flask(__name__)
CORS(app)

TTL = 20
REGISTRY_FILE = "registry.json"
REGISTRY = {}

# ---------- Persistence ----------

def load_registry():
    global REGISTRY
    if os.path.exists(REGISTRY_FILE):
        with open(REGISTRY_FILE, "r") as f:
            REGISTRY = json.load(f)

def save_registry():
    with open(REGISTRY_FILE, "w") as f:
        json.dump(REGISTRY, f, indent=2)

def cleanup_expired():
    now = time.time()
    expired = [
        name for name, s in REGISTRY.items()
        if now - s["ts"] > TTL
    ]
    for name in expired:
        REGISTRY.pop(name)
    if expired:
        save_registry()

# ---------- API ----------

@app.route("/register", methods=["POST"])
def register():
    data = request.json

    if not data or not all(k in data for k in ("name", "ip", "port")):
        return {"error": "invalid payload"}, 400

    REGISTRY[data["name"]] = {
        "ip": data["ip"],
        "port": data["port"],
        "ts": time.time()
    }

    save_registry()
    return {"status": "registered"}

@app.route("/ping", methods=["POST"])
def ping():
    data = request.json

    if not data or "name" not in data:
        return {"error": "invalid payload"}, 400

    name = data["name"]

    if name in REGISTRY:
        REGISTRY[name]["ts"] = time.time()
        save_registry()
        return {"status": "pong"}

    return {"error": "service not registered"}, 404


@app.route("/resolve/<name>")
def resolve(name):
    cleanup_expired()
    s = REGISTRY.get(name)
    if not s:
        return {"error": "not found"}, 404
    return {"url": f"http://{s['ip']}:{s['port']}"}

@app.route("/services")
def services_api():
    cleanup_expired()
    now = time.time()
    return jsonify([
        {
            "name": name,
            "ip": s["ip"],
            "port": s["port"],
            "last_seen": int(now - s["ts"])
        }
        for name, s in REGISTRY.items()
    ])

# ---------- DASHBOARD (THIS WAS MISSING) ----------

@app.route("/")
def dashboard():
    cleanup_expired()
    services = []

    for name, s in REGISTRY.items():
        services.append({
            "service_name": name,
            "ip": s["ip"],
            "port": s["port"],
            "route": "/",
            "last_seen": time.strftime(
                "%Y-%m-%d %H:%M:%S",
                time.gmtime(s["ts"])
            )
        })

    return render_template("index.html", services=services)


# ---------- START ----------

if __name__ == "__main__":
    load_registry()
    app.run(host="0.0.0.0", port=7000)
