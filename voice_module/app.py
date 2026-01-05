from flask import Flask, jsonify
from flask_cors import CORS
import threading
import time
import socket
import requests

from whisper_listener import start_listener, result_queue

# ==============================
# CONFIG (STATIC)
# ==============================
HOST_SERVER_IP = "192.168.1.6"   # Central Host / Registry
HOST_SERVER_PORT = 7000

SERVICE_NAME = "STT"
SERVICE_PORT = 8002             # Change if needed
PING_INTERVAL = 5               # seconds

# ==============================
# FLASK APP
# ==============================
app = Flask(__name__)
CORS(app)

listener_thread = None

# ==============================
# NETWORK UTILS
# ==============================
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

# ==============================
# REGISTRY CLIENT
# ==============================
def register_service():
    payload = {
        "name": SERVICE_NAME,
        "ip": get_local_ip(),
        "port": SERVICE_PORT
    }
    try:
        requests.post(
            f"http://{HOST_SERVER_IP}:{HOST_SERVER_PORT}/register",
            json=payload,
            timeout=3
        )
        print(f"✅ Registered STT service: {payload}")
    except Exception as e:
        print(f"❌ STT registration failed: {e}")

def ping_service():
    while True:
        time.sleep(PING_INTERVAL)
        try:
            requests.post(
                f"http://{HOST_SERVER_IP}:{HOST_SERVER_PORT}/ping",
                json={"name": SERVICE_NAME},
                timeout=3
            )
        except Exception as e:
            print(f"⚠ STT ping failed: {e}")

# ==============================
# ROUTES (UNCHANGED LOGIC)
# ==============================
@app.route("/start", methods=["POST"])
def start():
    global listener_thread
    if listener_thread is None or not listener_thread.is_alive():
        listener_thread = threading.Thread(
            target=start_listener,
            daemon=True
        )
        listener_thread.start()
        return jsonify({"status": "listening started"})
    return jsonify({"status": "already running"})

@app.route("/poll", methods=["GET"])
def poll():
    texts = []
    while not result_queue.empty():
        texts.append(result_queue.get())
    return jsonify({"results": texts})

# ==============================
# BOOTSTRAP
# ==============================
if __name__ == "__main__":
    # 1️⃣ Register to central host
    register_service()

    # 2️⃣ Start heartbeat
    threading.Thread(target=ping_service, daemon=True).start()

    # 3️⃣ Start STT API
    app.run(
        host="0.0.0.0",
        port=SERVICE_PORT,
        debug=False,
        use_reloader=False
    )
