#!/usr/bin/env python3
"""
Black Breacher - Meshy Retexture pipeline.

Uploads the project's breacher.glb to the Meshy Retexture API, waits for the
texture pass, and downloads the result (textured glb + PBR maps) into
_meshy_out/ for inspection. It does NOT overwrite the working breacher.glb --
retexturing a rigged model can strip animations, so a human/automation step
verifies the result before swapping.

Usage:
    set MESHY_API_KEY in the environment, then:
    python tools/meshy_retexture.py

Docs: https://docs.meshy.ai/en/api/retexture
"""

import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

def _load_key() -> str:
    # 1) env var, 2) git-ignored local file tools/.meshy_key
    k = os.environ.get("MESHY_API_KEY")
    if k:
        return k.strip()
    kf = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".meshy_key")
    if os.path.exists(kf):
        with open(kf) as f:
            return f.read().strip()
    return ""


KEY = _load_key()
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB = os.path.join(PROJECT, "breacher.glb")
OUTDIR = os.path.join(PROJECT, "_meshy_out")
BASE = "https://api.meshy.ai/openapi/v1/retexture"

PROMPT = (
    "Photorealistic gritty ex-military door breacher. Heavily weathered scarred "
    "face, short stubble, shaved head. Worn open dark olive-black tactical work "
    "jacket over a charcoal henley. Faded olive ripstop cargo pants. Scuffed "
    "black leather combat boots. Brass key on a knotted bootlace at the neck. "
    "Realistic skin, fabric weave, worn leather, grime; muted cinematic grade."
)


def api(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode())


def main():
    if not KEY:
        print("MESHY_API_KEY not set"); return 1
    os.makedirs(OUTDIR, exist_ok=True)

    with open(GLB, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    data_uri = "data:application/octet-stream;base64," + b64
    print("encoded glb:", len(b64), "base64 chars")

    body = {
        "model_url": data_uri,
        "text_style_prompt": PROMPT,
        "ai_model": "meshy-6",
        "enable_pbr": True,
        "enable_original_uv": True,
    }
    try:
        res = api("POST", BASE, body)
    except urllib.error.HTTPError as e:
        print("POST ERROR", e.code, e.read().decode()[:600]); return 1
    task_id = res.get("result") if isinstance(res, dict) else res
    print("TASK_ID", task_id)

    t = {}
    status = None
    for i in range(150):  # ~12.5 min @ 5s
        time.sleep(5)
        try:
            t = api("GET", BASE + "/" + str(task_id))
        except urllib.error.HTTPError as e:
            print("poll error", e.code); continue
        status = t.get("status")
        print("poll", i, status, t.get("progress"))
        if status in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
            break
    if status != "SUCCEEDED":
        print("NOT SUCCEEDED:", json.dumps(t)[:800]); return 2

    mu = t.get("model_urls", {}) or {}
    tu = t.get("texture_urls", []) or []
    print("MODEL_URLS", json.dumps(mu))
    print("TEXTURE_URLS", json.dumps(tu)[:1200])

    def dl(url, name):
        path = os.path.join(OUTDIR, name)
        urllib.request.urlretrieve(url, path)
        print("saved", name, os.path.getsize(path))

    if isinstance(mu, dict) and mu.get("glb"):
        dl(mu["glb"], "breacher_textured.glb")
    for idx, tx in enumerate(tu):
        if not isinstance(tx, dict):
            continue
        for k, v in tx.items():
            if isinstance(v, str) and v.startswith("http"):
                ext = v.split("?")[0].split(".")[-1][:4]
                dl(v, "tex_%d_%s.%s" % (idx, k, ext))
    print("DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
