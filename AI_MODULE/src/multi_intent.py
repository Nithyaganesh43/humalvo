"""
HOME AUTOMATION MULTI-INTENT ENGINE
- Scene handling preserved
- Multi-device ON/OFF fixed
- Absolute import used (no ImportError)
"""

import os
import re
import json
from src.transformer_intent import ml_predict_single   # ✅ FIXED IMPORT

# ================= LOAD DEVICE → CODE MAPPING =================
BASE = os.path.dirname(os.path.dirname(__file__))
with open(os.path.join(BASE, "model", "mapping.json"), "r") as f:
    mapping = json.load(f)["device_code"]

DEVICES = ["light", "fan", "pump"]

# ================= SCENE COMMANDS =================
SCENES = {
    "good night": {"light": "off", "fan": "on"},
    "sleep": {"light": "off", "fan": "on"},

    "i am leaving the house": {"light": "off", "fan": "off", "pump": "off"},
    "leaving the house": {"light": "off", "fan": "off", "pump": "off"},

    "everything in off state": {"light": "off", "fan": "off", "pump": "off"},
    "all off": {"light": "off", "fan": "off", "pump": "off"},

    "all on": {"light": "on", "fan": "on", "pump": "on"},
}

# ================= MEANING RULES =================
RULES = {
    "light_on": ["dark", "cant see", "cannot see"],
    "light_off": ["too bright"],

    "fan_on": ["hot", "warm", "uncomfortable"],
    "fan_off": ["cold", "freezing"],

    "pump_on": ["tank empty", "no water"],
    "pump_off": ["overflow", "flood"],
}

# ================= UTILITIES =================
def clean(text):
    return re.sub(r"[^\w\s]", "", text.lower()).strip()

def match_scene(text):
    for k, v in SCENES.items():
        if k in text:
            return v
    return None

def detect_devices(text):
    return [d for d in DEVICES if d in text]

# ================= ✅ FIXED MULTI-DEVICE HANDLER =================
def explicit_multi_device(text):
    actions = {}

    if any(w in text for w in ["on", "start", "turn on", "switch on"]):
        for d in DEVICES:
            if d in text:
                actions[d] = "on"

    if any(w in text for w in ["off", "stop", "turn off", "shut"]):
        for d in DEVICES:
            if d in text:
                actions[d] = "off"

    return actions

def rule_match(text):
    actions = {}
    for rule, words in RULES.items():
        for w in words:
            if w in text:
                dev, act = rule.split("_")
                actions[dev] = act
    return actions

# ================= MAIN FUNCTION =================
def predict_multi_intent(text):
    if not text or not text.strip():
        return "null"

    t = clean(text)

    # 1️⃣ SCENE (HARD RETURN)
    scene = match_scene(t)
    if scene:
        return "".join(mapping[d][scene[d]] for d in scene)

    # 2️⃣ EXPLICIT MULTI-DEVICE (FIXED)
    explicit = explicit_multi_device(t)
    if explicit:
        return "".join(mapping[d][explicit[d]] for d in explicit)

    # 3️⃣ RULE-BASED
    rules = rule_match(t)
    if rules:
        return "".join(mapping[d][rules[d]] for d in rules)

    # 4️⃣ ML FALLBACK (ONLY IF DEVICE WORD EXISTS)
    devices = detect_devices(t)
    results = {}
    for d in devices:
        ml = ml_predict_single(t, d)
        if ml in ("on", "off"):
            results[d] = ml

    if results:
        return "".join(mapping[d][results[d]] for d in results)

    return "null"
