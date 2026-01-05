/*******************************
 * CONFIG
 *******************************/

// 🌐 Central IP server (public / reachable)
const IP_SERVER = "http://192.168.1.6:7000"; // CHANGE WHEN READY

// 🔁 Fallback URLs (local / dev / demo)
const FALLBACK = {
    VOICE_START: "http://127.0.0.1:5000/start",
    VOICE_POLL:  "http://127.0.0.1:5000/poll",
    AI_PREDICT:  "http://127.0.0.1:5001/predict",
    ESP:         "http://127.0.0.1:9000/putcmd"
};

// Runtime resolved URLs
let VOICE_START_URL;
let VOICE_POLL_URL;
let AI_PREDICT_URL;
let espEndpoint;


/*******************************
 * STATE
 *******************************/
let isListening = false;
let pollInterval = null;


/*******************************
 * UI ELEMENTS
 *******************************/
const toggleBtn = document.getElementById("toggleBtn");
const latestCommand = document.getElementById("latestCommand");
const conversationLog = document.getElementById("conversationLog");


/*******************************
 * SERVICE RESOLVER
 *******************************/
async function resolve(service) {
    try {
        const r = await fetch(`${IP_SERVER}/resolve/${service}`);
        if (!r.ok) throw new Error("Resolver failed");
        const d = await r.json();
        return d.url;
    } catch (e) {
        console.warn(`⚠ Using fallback for ${service}`);
        return null;
    }
}


/*******************************
 * INIT (runs once on load)
 *******************************/
window.onload = async () => {

    // 🎙 STT service
    const stt = await resolve("STT");
    VOICE_START_URL = stt ? `${stt}/start` : FALLBACK.VOICE_START;
    VOICE_POLL_URL  = stt ? `${stt}/poll`  : FALLBACK.VOICE_POLL;

    // 🧠 AI service
    const ai = await resolve("AI");
    AI_PREDICT_URL = ai ? `${ai}/predict` : FALLBACK.AI_PREDICT;

    // ⚡ ESP service
    const esp = await resolve("ESP");
    espEndpoint = esp ? `${esp}/putcmd` : FALLBACK.ESP;

    console.log("✅ Active Endpoints:", {
        VOICE_START_URL,
        VOICE_POLL_URL,
        AI_PREDICT_URL,
        espEndpoint
    });
};


/*******************************
 * BUTTON HANDLER
 *******************************/
toggleBtn.addEventListener("click", async () => {
    if (!isListening) {
        await startListening();
    } else {
        stopListening();
    }
});


/*******************************
 * VOICE CONTROL
 *******************************/
async function startListening() {
    try {
        await fetch(VOICE_START_URL, { method: "POST" });

        isListening = true;
        toggleBtn.textContent = "Stop Listening";
        toggleBtn.classList.remove("start");
        toggleBtn.classList.add("stop");

        pollInterval = setInterval(pollVoiceResults, 1000);
    } catch (err) {
        console.error("❌ Failed to start voice listener", err);
    }
}

function stopListening() {
    isListening = false;
    toggleBtn.textContent = "Start Listening";
    toggleBtn.classList.remove("stop");
    toggleBtn.classList.add("start");

    clearInterval(pollInterval);
}


/*******************************
 * VOICE POLLING
 *******************************/
async function pollVoiceResults() {
    try {
        const res = await fetch(VOICE_POLL_URL);
        const data = await res.json();

        for (const text of data.results) {
            handleRecognizedText(text);
        }
    } catch (err) {
        console.error("❌ Polling error", err);
    }
}


/*******************************
 * AI PIPELINE
 *******************************/
async function handleRecognizedText(text) {
    addMessage("user", text);

    try {
        const res = await fetch(AI_PREDICT_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text })
        });

        const data = await res.json();
        const command = data.prediction;

        latestCommand.textContent = JSON.stringify(command, null, 2);
        addMessage("ai", JSON.stringify(command));

        // 🚀 Auto-send to ESP
        if (command !== null && command !== undefined) {
            sendCommandToESP(command);
        }

    } catch (err) {
        console.error("❌ AI prediction error", err);
    }
}


/*******************************
 * ESP COMMAND
 *******************************/
async function sendCommandToESP(command) {
    try {
        await fetch(espEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ command })
        });

        console.log("✅ ESP command sent:", command);

    } catch (err) {
        console.error("❌ ESP send failed", err);
    }
}


/*******************************
 * UI HELPERS
 *******************************/
function addMessage(type, content) {
    const div = document.createElement("div");
    div.classList.add("message", type);
    div.textContent = content;
    conversationLog.appendChild(div);
    conversationLog.scrollTop = conversationLog.scrollHeight;
}
