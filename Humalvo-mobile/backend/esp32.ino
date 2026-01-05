#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <WiFiUdp.h>

/* ================= DEVICE INFO ================= */
const char* DEVICE_NAME = "Priya_esp";
const char* DISCOVERY_MESSAGE = "HUMALVO_DEVICE";  // Discovery identifier

/* ================= WIFI ================= */
const char* ssid = "Sorry";
const char* password = "aaaaaaaa";

/* ================= RELAY PINS ================= */
#define LIGHT_PIN  26
#define FAN_PIN    27
#define PUMP_PIN   12

/* ================= STATE ================= */
bool lightState = false;
bool fanState   = false;
bool pumpState  = false;

/* ================= SERVERS ================= */
WebServer server(80);
WebSocketsServer webSocket(81);
WiFiUDP udp;
const int UDP_DISCOVERY_PORT = 8888;

/* ================= APPLY COMMAND ================= */
void applyCommand(char c) {
  switch (c) {
    case '0': lightState = false; break;
    case '1': lightState = true;  break;
    case '2': fanState   = false; break;
    case '3': fanState   = true;  break;
    case '4': pumpState  = false; break;
    case '5': pumpState  = true;  break;
  }
}

/* ================= UPDATE RELAYS ================= */
void updateRelays() {
  digitalWrite(LIGHT_PIN, lightState ? HIGH : LOW);
  digitalWrite(FAN_PIN,   fanState   ? HIGH : LOW);
  digitalWrite(PUMP_PIN,  pumpState  ? HIGH : LOW);
}

/* ================= STATE STRING ================= */
String getStateString() {
  String s = "";
  s += (lightState ? "1" : "0");
  s += (fanState   ? "3" : "2");
  s += (pumpState  ? "5" : "4");
  return s;
}

/* ================= CLOUD UPDATE ================= */
void updateCloud() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi not connected");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;

  Serial.println("🌐 Sending cloud update...");

  if (!https.begin(client, "https://internetprotocal.onrender.com/config")) {
    Serial.println("❌ HTTPS begin failed");
    return;
  }

  https.addHeader("Content-Type", "application/json");

  String jsonBody;
  jsonBody.reserve(256);

  jsonBody =
    String("{\"deviceName\":\"") + DEVICE_NAME + "\"," +
    "\"wifiName\":\"" + String(ssid) + "\"," +
    "\"wifiPassword\":\"" + String(password) + "\"," +
    "\"deviceIp\":\"" + WiFi.localIP().toString() + "\"}";

  Serial.println("POST Body:");
  Serial.println(jsonBody);

  int httpCode = https.POST(jsonBody);

  Serial.print("HTTP Response Code: ");
  Serial.println(httpCode);

  if (httpCode > 0) {
    Serial.println("Server Response:");
    Serial.println(https.getString());
  }

  https.end();
}

/* ================= UDP DISCOVERY ================= */
void handleDiscovery() {
  int packetSize = udp.parsePacket();
  if (packetSize) {
    char incomingPacket[255];
    int len = udp.read(incomingPacket, 255);
    if (len > 0) {
      incomingPacket[len] = 0;
    }
    
    String request = String(incomingPacket);
    
    // Check if it's a discovery request
    if (request.indexOf("HUMALVO_DISCOVER") >= 0) {
      Serial.printf("📡 Discovery request from %s:%d\n", 
                    udp.remoteIP().toString().c_str(), 
                    udp.remotePort());
      
      // Send response with our IP
      String response = String(DISCOVERY_MESSAGE) + ":" + WiFi.localIP().toString();
      udp.beginPacket(udp.remoteIP(), udp.remotePort());
      udp.write((const uint8_t*)response.c_str(), response.length());
      udp.endPacket();
      
      Serial.printf("✅ Sent discovery response: %s\n", response.c_str());
    }
  }
}

/* ================= WEBSOCKET EVENT ================= */
void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    Serial.printf("[%u] Client connected\n", num);
    String state = getStateString();
    webSocket.sendTXT(num, state);
    Serial.printf("[%u] Sent initial state: %s\n", num, state.c_str());
  }
  else if (type == WStype_DISCONNECTED) {
    Serial.printf("[%u] Client disconnected\n", num);
  }
  else if (type == WStype_TEXT) {
    Serial.printf("[%u] Received: %s\n", num, (char*)payload);
    
    bool stateChanged = false;
    
    for (size_t i = 0; i < length; i++) {
      char c = (char)payload[i];
      
      if (c == 'S' || c == 's') {
        String state = getStateString();
        webSocket.sendTXT(num, state);
        Serial.printf("[%u] Sync request - sent: %s\n", num, state.c_str());
        return;
      }
      
      applyCommand(c);
      stateChanged = true;
    }
    
    if (stateChanged) {
      updateRelays();
      String state = getStateString();
      webSocket.broadcastTXT(state);
      Serial.printf("Broadcasted state: %s\n", state.c_str());
    }
  }
}

/* ================= HTTP HANDLER ================= */
void handleHttp() {
  String uri = server.uri();

  if (uri.startsWith("/setcmd/")) {
    String cmd = uri.substring(8);

    for (char c : cmd) {
      applyCommand(c);
    }

    updateRelays();
    String state = getStateString();
    webSocket.broadcastTXT(state);
    server.send(200, "text/plain", state);
    return;
  }

  server.send(404, "text/plain", "Not Found");
}

/* ================= SETUP ================= */
void setup() {
  Serial.begin(115200);

  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(PUMP_PIN, OUTPUT);
  updateRelays();

  WiFi.begin(ssid, password);
  Serial.print("Connecting WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n✅ WiFi connected");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());

  // Start UDP for discovery
  udp.begin(UDP_DISCOVERY_PORT);
  Serial.printf("📡 UDP Discovery listening on port %d\n", UDP_DISCOVERY_PORT);

  server.onNotFound(handleHttp);
  server.begin();

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);

  updateCloud();
}

/* ================= LOOP ================= */
void loop() {
  server.handleClient();
  webSocket.loop();
  handleDiscovery();  // Handle discovery requests

  static unsigned long lastCloud = 0;
  if (millis() - lastCloud > 60000) {
    updateCloud();
    lastCloud = millis();
  }
}