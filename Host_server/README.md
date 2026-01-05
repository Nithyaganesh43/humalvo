# 🔌 Local Service Discovery Host Server

A **lightweight offline service discovery system** for **LAN / private networks**.  
Designed for **AI services, Voice-to-Text (STT), ESP32, Flutter apps, and Web frontends** running on different devices — **without hardcoded IPs, cloud dependency, or DNS**.

---

## 🚀 Why This Project?

When working on local networks, you often face:

- 🔄 Dynamic IP addresses  
- 🖥️ Multiple services on different machines  
- ❌ No internet / cloud access  
- 🤷 Guessing or manually changing IPs  
- 🧪 Unreliable demos  

This project **solves all of that** by providing a **central local resolver**.

---

## 🧠 Architecture Overview

### 🔑 Roles

#### 🖥 Host Server
- Central registry  
- Stores service name → IP + port  
- Removes dead services automatically  

#### 📡 Producers
- AI models  
- Speech-to-Text services  
- ESP32 devices  
- Register themselves and send heartbeat pings  

#### 📱 Consumers
- Web frontends  
- Flutter / Mobile apps  
- Resolve service URLs dynamically  

---

## 🔁 Runtime Flow

1. Host server starts  
2. Producers register themselves  
3. Producers periodically send heartbeat pings  
4. Consumers resolve services by name  
5. Inactive services are automatically removed  

---

## 📡 Host Server API

### 1️⃣ Register a Service

**POST** `/register`

```json
{
  "name": "STT",
  "ip": "192.168.1.10",
  "port": 5000
}
```

---

### 2️⃣ Ping (Heartbeat)

**POST** `/ping`

```json
{
  "name": "STT"
}
```

---

### 3️⃣ Resolve a Service

**GET** `/resolve/<service_name>`

```json
{
  "url": "http://192.168.1.10:5000"
}
```

---

### 4️⃣ List All Active Services

**GET** `/services`

Returns all currently alive services.

---

## 🖥 Web Dashboard

Access the dashboard at:

```
http://<HOST_IP>:7000/
```

Features:
- Registered services list  
- IP & port  
- Last seen time  
- Auto-removal of expired services  

---

## 📂 Project Structure

```
host_server/
│
├── host_server.py
├── registry.json
├── requirements.txt
└── templates/
    └── index.html
```

---

## 📦 Requirements

```
flask
flask-cors
```

Install dependencies:

```bash
pip install -r requirements.txt
```

---

## ▶️ Run the Server

```bash
python host_server.py
```

Server runs on:

```
http://0.0.0.0:7000
```

---

## 🛡️ Advantages

- No cloud dependency  
- No DNS required  
- No hardcoded IPs  
- Fully offline  
- Demo & production friendly  

---

## 📜 License

Open-source and free to use.
