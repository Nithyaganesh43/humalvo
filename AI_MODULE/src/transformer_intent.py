# src/transformer_intent.py

import os
import joblib
import numpy as np
from transformers import AutoTokenizer, AutoModel
import torch

# Base
BASE = os.path.dirname(os.path.dirname(__file__))
MODEL_DIR = os.path.join(BASE, "model")
TRANS_DIR = os.path.join(MODEL_DIR, "transformer")

# Load tokenizer/model (from model/transformer if present)
tokenizer = AutoTokenizer.from_pretrained(TRANS_DIR)
model = AutoModel.from_pretrained(TRANS_DIR)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)
model.eval()

# Load classifiers
clf_light = joblib.load(os.path.join(MODEL_DIR, "clf_light.joblib"))
clf_fan   = joblib.load(os.path.join(MODEL_DIR, "clf_fan.joblib"))
clf_pump  = joblib.load(os.path.join(MODEL_DIR, "clf_pump.joblib"))

def _embed_texts(texts, batch_size=32):
    embeddings = []
    with torch.no_grad():
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i+batch_size]
            enc = tokenizer(batch, padding=True, truncation=True, return_tensors="pt")
            enc = {k: v.to(device) for k, v in enc.items()}
            out = model(**enc)
            last = out.last_hidden_state
            mask = enc["attention_mask"].unsqueeze(-1)
            summed = (last * mask).sum(1)
            counts = mask.sum(1).clamp(min=1e-9)
            mean_pooled = (summed / counts).cpu().numpy()
            embeddings.append(mean_pooled)
    return np.vstack(embeddings)

def ml_predict_single(text, device):
    """
    Returns: "on", "off", or "none"
    """
    emb = _embed_texts([text])
    if device == "light":
        return clf_light.predict(emb)[0]
    if device == "fan":
        return clf_fan.predict(emb)[0]
    if device == "pump":
        return clf_pump.predict(emb)[0]
    return "none"
