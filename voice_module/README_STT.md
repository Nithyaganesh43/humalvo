# 🎙 STT Microservice (Whisper Listener)

This service provides **Speech-to-Text (STT)** functionality using a Whisper-based listener and is designed to work as a **microservice** within a local network.

It automatically:
- Registers itself to a **central Host Server**
- Sends periodic **heartbeat pings**
- Exposes REST APIs for starting speech recognition and polling results

---

## 🚀 Features

- 🎧 Local Speech-to-Text processing (offline capable)
- 🔌 Auto service registration to Host Server
- ❤️ Heartbeat-based liveness detection
- 🌐 CORS-enabled Flask API
- 🧩 Easily integrable with AI models, Web UI, Flutter apps, ESP32, etc.

---

## 🧠 How It Works

1. Service starts
2. Detects its **local LAN IP**
3. Registers itself to the **Host Server**
4. Sends heartbeat pings every few seconds
5. Listens for speech when `/start` is called
6. Recognized text is fetched using `/poll`

---

## 📡 Service Registration (Automatic)

On startup, the service registers itself to the Host Server:

```json
{
  "name": "STT",
  "ip": "<LOCAL_IP>",
  "port": 8002
}
```

Heartbeat pings are sent periodically to keep the service alive.

---

## 📡 API Endpoints

### ▶ Start Listening

**POST** `/start`

Starts the Whisper speech listener in a background thread.

**Response**
```json
{
  "status": "listening started"
}
```

---

### 📥 Poll Recognized Text

**GET** `/poll`

Fetches all recognized speech results from the queue.

**Response**
```json
{
  "results": [
    "turn on the light",
    "open the door"
  ]
}
```

---

## ⚙ Configuration

Edit these values in the code if needed:

```python
HOST_SERVER_IP = "192.168.1.6"
HOST_SERVER_PORT = 7000

SERVICE_NAME = "STT"
SERVICE_PORT = 8002
PING_INTERVAL = 5
```

---

## 📂 Project Structure

```
stt_service/
│
├── app.py                # Flask STT service
├── whisper_listener.py   # Whisper speech listener logic
├── requirements.txt
└── README.md
```

---

## 📦 Requirements

Typical dependencies include:

```
flask
flask-cors
requests
whisper
torch
```
*(Adjust based on your Whisper setup)*

Install dependencies:
```bash
pip install -r requirements.txt
```

---

## ▶ Run the Service

```bash
python app.py
```

The service runs on:
```
http://0.0.0.0:8002
```

Once running, it will automatically appear in the Host Server dashboard.

---

## 🧪 Example Use Case

- Voice-controlled home automation
- AI command processing pipeline
- Offline speech interfaces
- ESP32 + AI integrations

---

## 🛡 Notes

- Ensure the **Host Server** is running before starting this service
- Works best on the same LAN as consumers
- Designed for microservice-based architectures

---

## 📜 License

Open-source.  
Free to use, modify, and extend.
