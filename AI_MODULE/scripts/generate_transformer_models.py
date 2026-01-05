# scripts/generate_transformer_models.py
"""
Generate transformer-based embeddings and train sklearn classifiers for each device.
Saves:
 - model/transformer/  (tokenizer + model)
 - model/clf_light.joblib
 - model/clf_fan.joblib
 - model/clf_pump.joblib
 - model/mapping.json (if missing)
Run:
    python scripts/generate_transformer_models.py
"""

import os
import random
import json
import joblib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split

from transformers import AutoTokenizer, AutoModel
import torch

random.seed(42)
np.random.seed(42)
torch.manual_seed(42)

OUT_DIR = "model"
os.makedirs(OUT_DIR, exist_ok=True)

# Ensure mapping exists
mapping_path = os.path.join(OUT_DIR, "mapping.json")
if not os.path.exists(mapping_path):
    mapping = {
        "device_code": {
            "light": {"off": "0", "on": "1"},
            "fan":   {"off": "2", "on": "3"},
            "pump":  {"off": "4", "on": "5"}
        }
    }
    with open(mapping_path, "w") as f:
        json.dump(mapping, f, indent=4)

# -----------------------
# Training templates (expanded)
# -----------------------
templates = {
    "light": {
        "on": [
            "turn on the light", "light on", "switch on light",
            "it's dark", "i feel darkness", "i can't see",
            "brighten the room", "illuminate the area", "make it brighter", "let there be light"
        ],
        "off": [
            "turn off the light", "switch off the light", "light off",
            "dim the light", "no light please", "kill the lights", "lights out"
        ],
        "none": ["i'm hungry", "what a day", "call mom"]
    },
    "fan": {
        "on": [
            "turn on the fan", "fan on", "switch on fan",
            "it's hot", "i feel hot", "i'm sweating",
            "need air", "ventilate the room", "make it cooler"
        ],
        "off": [
            "turn off the fan", "fan off", "stop the fan",
            "i feel cold", "no fan needed"
        ],
        "none": ["i love movies", "i like tea"]
    },
    "pump": {
        "on": [
            "turn on the pump", "pump on", "water pump on",
            "start the pump", "start water pump", "turn on water pump",
            "start pump", "activate pump", "enable pump",
            "fill the tank", "tank empty", "need water"
        ],
        "off": [
            "turn off the pump", "stop the pump", "pump off",
            "tank full", "no water needed"
        ],
        "none": ["i enjoy music", "it's raining outside"]
    }
}

rooms = ["kitchen", "bedroom", "bathroom", "living room"]
prefixes = ["please", "hey", "ok", "kindly", ""]

def augment(text):
    t = text
    if random.random() < 0.4:
        p = random.choice(prefixes)
        if p:
            t = p + " " + t
    if random.random() < 0.35:
        t = t + " in the " + random.choice(rooms)
    if random.random() < 0.18:
        t = t + " please"
    return t.strip()

# Build dataset
X = []
y_light = []
y_fan = []
y_pump = []

SAMPLES_PER = 240

for device, groups in templates.items():
    for label, phrases in groups.items():
        for p in phrases:
            for _ in range(max(1, SAMPLES_PER // len(phrases))):
                X.append(augment(p))
                y_light.append(label if device == "light" else "none")
                y_fan.append(label if device == "fan" else "none")
                y_pump.append(label if device == "pump" else "none")

# Add global phrases to improve "all" handling
globals_off = ["shutdown all", "turn everything off", "disable all", "turn everything down"]
globals_on  = ["turn everything on", "enable all", "switch on all", "activate everything"]

for gp in globals_off:
    for _ in range(150):
        X.append(augment(gp))
        y_light.append("off")
        y_fan.append("off")
        y_pump.append("off")

for gp in globals_on:
    for _ in range(150):
        X.append(augment(gp))
        y_light.append("on")
        y_fan.append("on")
        y_pump.append("on")

print("Total samples:", len(X))

# ------------------------------
# Prepare transformer encoder
# ------------------------------
MODEL_NAME = "distilbert-base-uncased"   # will download on first run
print("Loading transformer:", MODEL_NAME)
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModel.from_pretrained(MODEL_NAME)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)
model.eval()

def embed_texts(texts, batch_size=32):
    embeddings = []
    with torch.no_grad():
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i+batch_size]
            enc = tokenizer(batch, padding=True, truncation=True, return_tensors="pt")
            enc = {k: v.to(device) for k, v in enc.items()}
            out = model(**enc)
            last = out.last_hidden_state  # (batch, seq_len, dim)
            mask = enc["attention_mask"].unsqueeze(-1)
            summed = (last * mask).sum(1)
            counts = mask.sum(1).clamp(min=1e-9)
            mean_pooled = (summed / counts).cpu().numpy()
            embeddings.append(mean_pooled)
    return np.vstack(embeddings)

print("Computing embeddings (this may take a while)...")
X_emb = embed_texts(X, batch_size=32)
print("Embeddings shape:", X_emb.shape)

# -------------------------
# Train classifiers
# -------------------------
print("Training classifiers (LogisticRegression) on embeddings...")
X_train, X_test, ly_train, ly_test, fy_train, fy_test, py_train, py_test = \
    train_test_split(X_emb, y_light, y_fan, y_pump, test_size=0.12, random_state=42)

clf_light = LogisticRegression(max_iter=800).fit(X_train, ly_train)
clf_fan   = LogisticRegression(max_iter=800).fit(X_train, fy_train)
clf_pump  = LogisticRegression(max_iter=800).fit(X_train, py_train)

print("Light acc:", clf_light.score(X_test, ly_test))
print("Fan acc:  ", clf_fan.score(X_test, fy_test))
print("Pump acc: ", clf_pump.score(X_test, py_test))

# Save classifiers
joblib.dump(clf_light, os.path.join(OUT_DIR, "clf_light.joblib"))
joblib.dump(clf_fan,   os.path.join(OUT_DIR, "clf_fan.joblib"))
joblib.dump(clf_pump,  os.path.join(OUT_DIR, "clf_pump.joblib"))

# Save transformer locally so future runs are offline
save_dir = os.path.join(OUT_DIR, "transformer")
os.makedirs(save_dir, exist_ok=True)
print("Saving transformer files locally to", save_dir)
tokenizer.save_pretrained(save_dir)
model.save_pretrained(save_dir)

print("Saved classifiers and transformer. Done.")
