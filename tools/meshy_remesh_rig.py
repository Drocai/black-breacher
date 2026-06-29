#!/usr/bin/env python3
"""
Black Breacher - Meshy remesh + rig a generated character.

Meshy text-to-3D output can exceed the 300k-face rigging limit, so this
remeshes the refine task down to a game-appropriate polycount, then rigs the
remeshed model and downloads the rigged GLB + walk/run animation GLBs.

Usage:
    python tools/meshy_remesh_rig.py <refine_task_id> <out_name> [polycount] [height_m]
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
    for i in range(180):
        time.sleep(5)
        try:
            t = api("GET", base + "/" + str(tid))
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
    if len(sys.argv) < 3:
        print("usage: meshy_remesh_rig.py <refine_task_id> <out_name> [poly] [height]"); return 1
    task_id = sys.argv[1]
    name = sys.argv[2]
    poly = int(sys.argv[3]) if len(sys.argv) > 3 else 30000
    height = float(sys.argv[4]) if len(sys.argv) > 4 else 1.85
    os.makedirs(OUTDIR, exist_ok=True)

    # 1) remesh down to a riggable / game-appropriate polycount
    try:
        res = api("POST", REMESH, {
            "input_task_id": task_id, "target_polycount": poly,
            "target_formats": ["glb"], "topology": "triangle",
        })
    except urllib.error.HTTPError as e:
        print("REMESH POST ERROR", e.code, e.read().decode()[:600]); return 1
    mid = res.get("result") if isinstance(res, dict) else res
    print("REMESH_TASK", mid)
    st, t = poll(REMESH, mid, "remesh")
    if st != "SUCCEEDED":
        print("remesh failed:", json.dumps(t)[:600]); return 2
    glb_url = (t.get("model_urls", {}) or {}).get("glb")
    print("REMESHED_GLB", glb_url[:80] if glb_url else None)
    if not glb_url:
        print("no remeshed glb"); return 2

    # 2) rig the remeshed model
    try:
        res = api("POST", RIG, {"model_url": glb_url, "height_meters": height})
    except urllib.error.HTTPError as e:
        print("RIG POST ERROR", e.code, e.read().decode()[:600]); return 1
    rid = res.get("result") if isinstance(res, dict) else res
    print("RIG_TASK", rid)
    st, t = poll(RIG, rid, "rig")
    if st != "SUCCEEDED":
        print("rig failed:", json.dumps(t)[:600]); return 2

    print("RESULT_KEYS", list(t.keys()))
    ba = t.get("basic_animations", {}) or {}
    print("BASIC_ANIM_KEYS", list(ba.keys()))

    def dl(url, fn):
        if not (isinstance(url, str) and url.startswith("http")):
            return
        p = os.path.join(OUTDIR, fn)
        urllib.request.urlretrieve(url, p)
        print("saved", fn, os.path.getsize(p))

    dl(t.get("rigged_character_glb_url"), name + "_rigged.glb")
    dl(ba.get("walking_glb_url"), name + "_walk.glb")
    dl(ba.get("running_glb_url"), name + "_run.glb")
    print("DONE", name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
