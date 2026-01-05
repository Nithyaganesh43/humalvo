# 🤖 AI Microservice (Multi‑Intent Prediction API)

This service provides an **AI-powered intent recognition API** used in the Hybrid Transformer Home Automation system.

It acts as a **microservice** that:
- Runs an AI/NLP model for intent prediction
- Registers itself to a **central Host Server**
- Sends periodic **heartbeat pings**
- Exposes REST APIs for prediction
- Works fully **offline on LAN**

---

## 🚀 Features

- 🧠 Multi-intent prediction from text input
- 🔌 Auto service registration to Host Server
- ❤️ Heartbeat-based liveness monitoring
- 🌐 REST API using Flask
- 🔄 Easily consumable by Web, Flutter, ESP32, or other services

---

## 🧠 How It Works

1. AI service starts
2. Detects its **local LAN IP**
3. Registers itself with the **Host Server**
4. Sends heartbeat pings at regular intervals
5. Accepts text input via REST API
6. Returns predicted intents/actions

---

## 📡 Service Registration (Automatic)

On startup, the service registers itself with the Host Server:

```json
{
  "name": "AI",
  "ip": "<LOCAL_IP>",
  "port": 5000
}
```

Heartbeat pings keep the service marked as **alive**.

---

## 📡 API Endpoints

### 🏠 Health Check

**GET** `/`

**Response**
```json
{
  "status": "OK",
  "message": "Hybrid Transformer Home Automation API is running"
}
```

---

### 🔮 Predict Intent

**POST** `/predict`

**Payload**
```json
{
  "text": "turn on the living room light"
}
```

**Response**
```json
{
  "input": "turn on the living room light",
  "prediction": {
    "intent": "LIGHT_ON",
    "confidence": 0.94
  }
}
```

---

## ⚙ Configuration

Modify these values in `app.py` if required:

```python
HOST_SERVER_IP = "192.168.1.6"
HOST_SERVER_PORT = 7000

SERVICE_NAME = "AI"
SERVICE_PORT = 5000
PING_INTERVAL = 5
```

---

## 📂 Project Structure

```
ai_service/
│
├── app.py                 # Flask AI API
├── src/
│   └── multi_intent.py    # AI model logic
├── requirements.txt
└── README.md
```

---

## 📦 Requirements

Typical dependencies:

```
flask
flask-cors
requests
torch
transformers
```

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
http://0.0.0.0:5000
```

Once running, it will automatically appear in the **Host Server dashboard**.

---

## 🧪 Example Use Cases

- Voice-controlled home automation
- NLP-based command processing
- AI inference service for ESP32
- Offline AI demos on LAN

---

## 🛡 Notes

- Ensure the **Host Server** is running before starting this service
- Designed for microservice-based architectures
- Fully LAN-compatible (no cloud dependency)

---

## 📜 License

Open-source.  
Free to use, modify, and extend.
