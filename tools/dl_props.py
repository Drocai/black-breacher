import json, urllib.request, os, sys

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) black-breacher-asset-fetch"}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60)

def dl(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with get(url) as r, open(dest, "wb") as f:
        f.write(r.read())

models = sys.argv[1:] or ["wooden_display_shelves_01", "metal_office_desk", "drawer_cabinet", "industrial_storage_cart"]
res = "2k"
base = os.path.join(os.getcwd(), "props")
for m in models:
    try:
        d = json.load(get(f"https://api.polyhaven.com/files/{m}"))
        node = d["gltf"][res]["gltf"]
        folder = os.path.join(base, m)
        dl(node["url"], os.path.join(folder, os.path.basename(node["url"])))
        for rel, info in node.get("include", {}).items():
            dl(info["url"], os.path.join(folder, rel.replace("/", os.sep)))
        print("DL_OK", m)
    except Exception as e:
        print("DL_FAIL", m, repr(e))
print("PROPS_DONE")
