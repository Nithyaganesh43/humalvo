# Ì≥± Flutter AI Service Client

This Flutter module provides a robust client-side integration for communicating with the **AI Microservice** in a local microservices ecosystem.  
It is designed to work seamlessly with the **Local Service Discovery Host Server**, enabling dynamic endpoint resolution without hardcoded IPs.

---

## Ì∫Ä What This Module Does

- Ì¥ç Dynamically resolves the AI service endpoint from the Host Server  
- Ì≤æ Caches the last-known working endpoint using `SharedPreferences`  
- Ì¥Å Falls back to a local/default endpoint if the resolver is unavailable  
- Ì≥° Sends text input to the AI service and retrieves predictions  
- Ì∑™ Provides utilities for connection testing and debugging  

This ensures reliable AI access even in offline or unstable LAN environments.

---

## Ì∑† Architecture Fit

This module acts as a **Consumer** in the system:

```
Flutter App ‚îÄ‚îÄ‚ñ∂ Host Server ‚îÄ‚îÄ‚ñ∂ AI Service  
       ‚îÇ               ‚îÇ  
       ‚îî‚îÄ‚îÄ‚îÄ‚îÄ fallback / cache
```

---

## Ì¥Å Endpoint Resolution Flow

1. Use cached endpoint (if available)  
2. Resolve AI service from Host Server (`/resolve/AI`)  
3. Store resolved endpoint locally  
4. Use last-known endpoint if Host Server is unreachable  
5. Final fallback to a hardcoded local endpoint  

This makes the app resilient and demo-safe.

---

## ‚öô Configuration

Edit these values in `ai_service.dart`:

```dart
static const String _ipServer = "http://192.168.4.1:5000"; // Host Server
static const String _fallbackEndpoint = "http://127.0.0.1:5001/predict";
```

---

## Ì≥° Key Methods

### Ì¥Æ getResponse()

Send text input to the AI service and receive a response:

```dart
final ai = AiService();
final reply = await ai.getResponse("turn on the fan");
```

### Ì∑™ testConnection()

Check if the AI service is reachable:

```dart
bool alive = await ai.testConnection();
```

### Ì¥Ñ clearCache()

Force re-resolution of the AI endpoint:

```dart
ai.clearCache();
```

### Ìª∞ getCurrentEndpoint()

Get the currently resolved AI endpoint:

```dart
String endpoint = await ai.getCurrentEndpoint();
```

---

## Ì≥Ç File Location

Recommended placement:

```
lib/
‚îî‚îÄ‚îÄ services/
    ‚îî‚îÄ‚îÄ ai_service.dart
```

---

## Ì≥¶ Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.2.0
  shared_preferences: ^2.2.0
```

Then run:

```bash
flutter pub get
```

---

## Ì∑™ Example Use Cases

- Voice-controlled Flutter apps  
- Offline-first AI assistants  
- Smart home control panels  
- LAN-based college/demo projects  

---

## Ìª° Design Highlights

- No cloud dependency  
- No hardcoded AI IPs  
- Automatic recovery from network changes  
- Clean separation of concerns  
- Production-safe microservice consumer  

---

## Ì≥ú License

**Open-source.**  
Free to use, modify, and extend.

---

## ‚ú® Author Note

This module is part of a **LAN-based microservices architecture** built for AI, STT, ESP32, and Flutter ‚Äî focusing on **offline reliability**, **clean design**, and **dynamic service discovery**.

