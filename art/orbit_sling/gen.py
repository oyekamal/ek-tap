#!/usr/bin/env python3
"""gen.py NAME "prompt" [ref.png ...] -> raw/NAME.png (Gemini) + sprites/NAME.png (grey bg flood-keyed, trimmed).
Key: GEMINI_API_KEY from personal-agent-v2/.env. ponytail: edge flood-fill keying; fails on grey-touching art."""
import sys, os, io, json, base64, urllib.request, collections
from PIL import Image
import numpy as np
for l in open(os.path.expanduser("~/Documents/free_work/personal-agent-v2/.env")):
    if l.startswith("GEMINI_API_KEY="): KEY = l.split("=",1)[1].strip().strip('"\'')
MODEL = os.environ.get("MODEL", "gemini-3-pro-image")
STYLE = open(os.path.join(os.path.dirname(__file__), "STYLE_PROMPT.txt")).read().strip()
BG = (128,128,128)

def gen(prompt, refs):
    parts = [{"text": f"{STYLE}\n\n{prompt}\nBackground: perfectly flat solid mid-grey #808080, nothing else."}]
    for r in refs: parts.append({"inline_data": {"mime_type": "image/png", "data": base64.b64encode(open(r,'rb').read()).decode()}})
    body = json.dumps({"contents": [{"parts": parts}], "generationConfig": {"responseModalities": ["IMAGE"]}}).encode()
    req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={KEY}", body, {"Content-Type": "application/json"})
    d = json.load(urllib.request.urlopen(req, timeout=240))
    for p in d["candidates"][0]["content"]["parts"]:
        if "inlineData" in p: return Image.open(io.BytesIO(base64.b64decode(p["inlineData"]["data"]))).convert("RGB")
    raise SystemExit("no image: " + json.dumps(d)[:400])

def key(im, tol=38):
    a = np.array(im).astype(int); h, w, _ = a.shape
    near = (np.abs(a - np.array(BG)).sum(axis=2) <= tol*3//2) | (np.abs(a - a[0,0]).sum(axis=2) <= tol)
    bg = np.zeros((h,w), bool); q = collections.deque()
    for x in range(w): q += [(0,x),(h-1,x)]
    for y in range(h): q += [(y,0),(y,w-1)]
    while q:
        y,x = q.popleft()
        if 0<=y<h and 0<=x<w and near[y,x] and not bg[y,x]:
            bg[y,x]=True; q += [(y+1,x),(y-1,x),(y,x+1),(y,x-1)]
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    out = Image.fromarray(np.dstack([a.astype(np.uint8), alpha]), "RGBA")
    return out.crop(out.getchannel("A").getbbox())

if __name__ == "__main__":
    name, prompt, refs = sys.argv[1], sys.argv[2], sys.argv[3:]
    im = gen(prompt, refs); im.save(f"raw/{name}.png"); s = key(im); s.save(f"sprites/{name}.png"); print(name, im.size, "->", s.size)
