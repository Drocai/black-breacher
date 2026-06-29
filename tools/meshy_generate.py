#!/usr/bin/env python3
"""
Black Breacher - Meshy text-to-3D character generator.

Generates a realistic, T-posed (riggable) character via the Meshy Text-to-3D
API: preview (geometry, t-pose) -> refine (PBR textures) -> download glb +
thumbnail into _meshy_out/ for human visual review BEFORE any rigging /
integration. Does NOT touch production scenes.

Usage:
    python tools/meshy_generate.py <out_name> "<prompt>"
    (MESHY_API_KEY env or tools/.meshy_key)
Docs: https://docs.meshy.ai/en/api/text-to-3d
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error


def _load_key() -> str:
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
OUTDIR = os.path.join(PROJECT, "_meshy_out")
BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"

DEFAULT_PROMPT = (
    "Realistic modern special forces operator, full body adult male, standing. "
    "Black tactical plate carrier vest with MOLLE pouches, ballistic combat "
    "helmet, black balaclava and goggles covering the face, dark grey combat "
    "fatigues, tactical gloves, knee pads, combat boots, holstered sidearm. "
    "Gritty weathered military gear, realistic PBR materials, muted tactical "
    "color palette, grounded realistic adult proportions."
)


def api(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode())


def poll(task_id, label):
    t = {}
    status = None
    for i in range(180):  # ~15 min @ 5s
        time.sleep(5)
        try:
            t = api("GET", BASE + "/" + str(task_id))
        except urllib.error.HTTPError as e:
            print("poll error", e.code); continue
        status = t.get("status")
        if i % 4 == 0 or status not in ("PENDING", "IN_PROGRESS"):
            print(label, "poll", i, status, t.get("progress"))
        if status in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
            break
    return status, t


def main():
    if not KEY:
        print("MESHY_API_KEY not set"); return 1
    name = sys.argv[1] if len(sys.argv) > 1 else "operator"
    prompt = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_PROMPT
    os.makedirs(OUTDIR, exist_ok=True)
    print("GEN", name, "::", prompt[:80])

    # 1) preview — geometry in t-pose (riggable)
    try:
        res = api("POST", BASE, {
            "mode": "preview", "prompt": prompt, "ai_model": "meshy-6",
            "pose_mode": "t-pose", "model_type": "standard", "target_polycount": 30000,
        })
    except urllib.error.HTTPError as e:
        print("PREVIEW POST ERROR", e.code, e.read().decode()[:600]); return 1
    pid = res.get("result") if isinstance(res, dict) else res
    print("PREVIEW_TASK", pid)
    st, _ = poll(pid, "preview")
    if st != "SUCCEEDED":
        print("preview not succeeded:", st); return 2

    # 2) refine — PBR textures
    try:
        res = api("POST", BASE, {
            "mode": "refine", "preview_task_id": pid,
            "enable_pbr": True, "ai_model": "meshy-6",
        })
    except urllib.error.HTTPError as e:
        print("REFINE POST ERROR", e.code, e.read().decode()[:600]); return 1
    rid = res.get("result") if isinstance(res, dict) else res
    print("REFINE_TASK", rid)
    st, t = poll(rid, "refine")
    if st != "SUCCEEDED":
        print("refine not succeeded:", st); return 2

    mu = t.get("model_urls", {}) or {}
    thumb = t.get("thumbnail_url")
    print("MODEL_URLS", json.dumps(mu)[:400])

    def dl(url, fn):
        p = os.path.join(OUTDIR, fn)
        urllib.request.urlretrieve(url, p)
        print("saved", fn, os.path.getsize(p))

    if mu.get("glb"):
        dl(mu["glb"], name + ".glb")
    if thumb:
        dl(thumb, name + "_thumb.png")
    print("DONE", name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
