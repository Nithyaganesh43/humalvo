# app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from src.multi_intent import predict_multi_intent

import requests
import socket
import time
import threading

# ==============================
# CONFIG (ONLY THESE ARE STATIC)
# ==============================
HOST_SERVER_IP = "192.168.1.6"   # Central Host / Registry
HOST_SERVER_PORT = 7000

SERVICE_NAME = "AI"
SERVICE_PORT = 5000             # This AI server port
PING_INTERVAL = 5               # seconds

# ==============================
# FLASK APP
# ==============================
app = Flask(__name__)
CORS(app)

# ==============================
# NETWORK UTILS
# ==============================
def get_local_ip():
    """Get LAN IP address reliably"""
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
    ip = get_local_ip()
    payload = {
        "name": SERVICE_NAME,
        "ip": ip,
        "port": SERVICE_PORT
    }

    try:
        r = requests.post(
            f"http://{HOST_SERVER_IP}:{HOST_SERVER_PORT}/register",
            json=payload,
            timeout=3
        )
        print(f"✅ Registered AI service: {payload}")
    except Exception as e:
        print(f"❌ Registration failed: {e}")

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
            print(f"⚠ Ping failed: {e}")

# ==============================
# ROUTES
# ==============================
@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "status": "OK",
        "message": "Hybrid Transformer Home Automation API is running"
    })

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()

    if not data or "text" not in data:
        return jsonify({"error": "Send JSON with key 'text'"}), 400

    text = data["text"].strip()
    if not text:
        return jsonify({"error": "Text cannot be empty"}), 400

    try:
        result = predict_multi_intent(text)
        return jsonify({
            "input": text,
            "prediction": result
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==============================
# BOOTSTRAP
# ==============================
if __name__ == "__main__":
    # 1️⃣ Register once
    register_service()

    # 2️⃣ Start ping thread
    threading.Thread(target=ping_service, daemon=True).start()

    # 3️⃣ Start API
    app.run(host="0.0.0.0", port=SERVICE_PORT, debug=True)
