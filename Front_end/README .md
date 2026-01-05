# 🎤 Voice Control System

A real-time voice recognition system that listens to your commands, processes them through AI, and sends control signals to an ESP device.

---

## 📋 What Does This Do?

1. **Listens** to your voice commands
2. **Converts** speech to text
3. **Processes** the text through AI to understand the command
4. **Sends** the command to your ESP device (like Arduino/ESP32)

---

## 🏗️ System Architecture

```
[Your Voice] 
    ↓
[Voice Recognition Service - Port 5000]
    ↓
[AI Prediction Service - Port 5001]
    ↓
[ESP Device Controller - Port 9000]
```

---

## 🔧 Setup Instructions

### 1. **Configure Your IP Server**

Open the JavaScript file and change this line:

```javascript
const IP_SERVER = "http://192.168.1.6:7000";
```

Replace `192.168.1.6` with your actual server IP address.

### 2. **Required Services**

You need these three services running:

| Service | Default Port | Purpose |
|---------|-------------|---------|
| **STT (Speech-to-Text)** | 5000 | Converts voice to text |
| **AI Prediction** | 5001 | Processes commands |
| **ESP Controller** | 9000 | Sends commands to hardware |

### 3. **Service Endpoints**

Each service needs these endpoints:

#### Voice Recognition Service (Port 5000)
- `POST /start` - Start listening
- `GET /poll` - Get recognized text

#### AI Service (Port 5001)
- `POST /predict` - Process text and return command

#### ESP Service (Port 9000)
- `POST /putcmd` - Send command to ESP device

---

## 🚀 How to Use

### Step 1: Start Your Services

Make sure all three services are running:
- Voice recognition on port 5000
- AI prediction on port 5001
- ESP controller on port 9000

### Step 2: Open the Web Interface

Open `index.html` in your browser.

### Step 3: Start Listening

Click the **"Start Listening"** button.

### Step 4: Speak Your Commands

The system will:
1. Display your spoken text
2. Show the AI's interpretation
3. Automatically send commands to your ESP device

### Step 5: Stop When Done

Click **"Stop Listening"** to pause.

---

## 🌐 How the Resolver Works

The system tries to automatically find your services:

1. **First**: Asks the IP server where services are located
2. **Fallback**: Uses local development URLs if server is unavailable

```
Try: http://192.168.1.6:7000/resolve/STT
  ↓ (if fails)
Use: http://127.0.0.1:5000 (local fallback)
```

---

## 📊 Example Flow

```
You say: "Turn on the light"
    ↓
System hears: "turn on the light"
    ↓
AI interprets: { action: "light", state: "on" }
    ↓
ESP receives: { command: { action: "light", state: "on" } }
    ↓
Your device turns on the light ✨
```

---

## 🔍 Troubleshooting

### Problem: "Resolver failed" warnings

**Solution**: Check if your IP server is running and accessible at the configured address.

### Problem: Commands not recognized

**Solution**: 
- Verify AI service is running on port 5001
- Check browser console for errors
- Ensure microphone permissions are granted

### Problem: ESP not responding

**Solution**:
- Confirm ESP service is running on port 9000
- Check ESP device connection
- Verify command format matches ESP expectations

### Problem: No voice detected

**Solution**:
- Check microphone permissions in browser
- Verify voice service is running on port 5000
- Test microphone in browser settings

---

## 🛠️ Development vs Production

### Development Mode (Fallback URLs)
```javascript
Voice: http://127.0.0.1:5000
AI:    http://127.0.0.1:5001
ESP:   http://127.0.0.1:9000
```

### Production Mode (IP Server)
```javascript
IP Server resolves actual service locations dynamically
```

---

## 📝 Configuration Checklist

- [ ] Update `IP_SERVER` with your server address
- [ ] Start voice recognition service
- [ ] Start AI prediction service
- [ ] Start ESP controller service
- [ ] Grant microphone permissions in browser
- [ ] Test with a simple command

---

## 💡 Tips

- **Keep services running**: All three services must be active
- **Check console**: Open browser DevTools to see connection status
- **Watch the log**: Conversation log shows all activity in real-time
- **Latest command**: Shows the most recent AI interpretation

---

## 📦 File Structure

```
project/
├── index.html          (Your web interface)
├── script.js           (This control code)
├── style.css           (UI styling)
└── README.md           (This file)
```

---

## 🔐 Security Notes

- This system uses HTTP (not HTTPS)
- Suitable for local network / development
- For production, implement proper authentication
- Consider HTTPS for sensitive deployments

---

## 📞 Support

If you encounter issues:

1. Check browser console (F12) for errors
2. Verify all services are running
3. Test each service endpoint individually
4. Confirm network connectivity

---

## 📄 License

Configure according to your project needs.

---

**Made with ❤️ for voice-controlled systems**