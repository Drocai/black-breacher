#!/usr/bin/env python3
"""
Black Breacher - end-to-end Meshy character builder.

One command: text -> preview(t-pose) -> refine(PBR) -> remesh(<=poly) ->
rig -> download rigged GLB + walk/run animation GLBs + thumbnail into
characters/ (web/game-ready). Keeps the pipeline autonomous so new tactical
operators can be produced without manual step-chaining.

Usage:
    python tools/meshy_build_character.py <out_name> "<prompt>" [poly] [height]

Output GLBs are written to characters/ ; review the *_thumb.png BEFORE wiring
a new model into a scene (art-direction gate: realistic adult tactical only).
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
OUTDIR = os.path.join(PROJECT, "characters")
T2D = "https://api.meshy.ai/openapi/v2/text-to-3d"
REMESH = "https://api.meshy.ai/openapi/v1/remesh"
RIG = "https://api.meshy.ai/openapi/v1/rigging"


def api(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.loads(r.read().decode())


def poll(base, tid, label):
    t = {}
    status = None
    for i in range(240):
        time.sleep(5)
        try:
            t = api("GET", base + "/" + str(tid))
        except urllib.error.HTTPError as e:
            print("poll error", e.code); continue
        status = t.get("status")
        if i % 4 == 0 or status not in ("PENDING", "IN_PROGRESS"):
            print(label, "poll", i, status, t.get("progress"), flush=True)
        if status in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
            break
    return status, t


def post_id(url, body, label):
    try:
        res = api("POST", url, body)
    except urllib.error.HTTPError as e:
        print(label, "POST ERROR", e.code, e.read().decode()[:600]); return None
    return res.get("result") if isinstance(res, dict) else res


def dl(url, fn):
    if not (isinstance(url, str) and url.startswith("http")):
        return
    p = os.path.join(OUTDIR, fn)
    urllib.request.urlretrieve(url, p)
    print("saved", fn, os.path.getsize(p), flush=True)


def main():
    if not KEY:
        print("MESHY_API_KEY not set"); return 1
    if len(sys.argv) < 3:
        print('usage: meshy_build_character.py <name> "<prompt>" [poly] [height]'); return 1
    name = sys.argv[1]
    prompt = sys.argv[2]
    poly = int(sys.argv[3]) if len(sys.argv) > 3 else 30000
    height = float(sys.argv[4]) if len(sys.argv) > 4 else 1.85
    os.makedirs(OUTDIR, exist_ok=True)
    print("BUILD", name, "::", prompt[:80], flush=True)

    # 1) preview (geometry, t-pose / riggable)
    pid = post_id(T2D, {
        "mode": "preview", "prompt": prompt, "ai_model": "meshy-6",
        "pose_mode": "t-pose", "model_type": "standard", "target_polycount": poly,
    }, "PREVIEW")
    if not pid:
        return 1
    print("PREVIEW_TASK", pid, flush=True)
    if poll(T2D, pid, "preview")[0] != "SUCCEEDED":
        return 2

    # 2) refine (PBR textures)
    rid = post_id(T2D, {"mode": "refine", "preview_task_id": pid,
                        "enable_pbr": True, "ai_model": "meshy-6"}, "REFINE")
    if not rid:
        return 1
    print("REFINE_TASK", rid, flush=True)
    st, t = poll(T2D, rid, "refine")
    if st != "SUCCEEDED":
        return 2
    # Thumbnail only (the hi-poly refine is remeshed below; its full-res
    # textures don't belong in the Godot-scanned characters/ dir).
    dl(t.get("thumbnail_url"), name + "_thumb.png")

    # 3) remesh (under 300k faces / game-appropriate)
    mid = post_id(REMESH, {"input_task_id": rid, "target_polycount": poly,
                           "target_formats": ["glb"], "topology": "triangle"}, "REMESH")
    if not mid:
        return 1
    print("REMESH_TASK", mid, flush=True)
    st, t = poll(REMESH, mid, "remesh")
    if st != "SUCCEEDED":
        return 2
    glb_url = (t.get("model_urls", {}) or {}).get("glb")
    if not glb_url:
        print("no remeshed glb"); return 2

    # 4) rig (+ basic walk/run)
    rg = post_id(RIG, {"model_url": glb_url, "height_meters": height}, "RIG")
    if not rg:
        return 1
    print("RIG_TASK", rg, flush=True)
    st, t = poll(RIG, rg, "rig")
    if st != "SUCCEEDED":
        return 2
    res = t.get("result") if isinstance(t.get("result"), dict) else t
    ba = res.get("basic_animations", {}) or {}
    dl(res.get("rigged_character_glb_url"), name + "_rigged.glb")
    dl(ba.get("walking_glb_url"), name + "_walk.glb")
    dl(ba.get("running_glb_url"), name + "_run.glb")
    print("DONE", name, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
