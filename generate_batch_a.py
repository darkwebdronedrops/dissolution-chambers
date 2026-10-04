#!/usr/bin/env python3
"""The Dissolution Chambers — Backgrounds Batch A + Objects Batch A"""
import requests, base64, io, time
from pathlib import Path
from PIL import Image

import os
API_KEY = os.environ.get("PIXELLAB_API_KEY", "")
if not API_KEY:
    raise SystemExit("Set PIXELLAB_API_KEY in the environment")
BASE_URL = "https://api.pixellab.ai/v1"
OUT_BG = Path("/root/.openclaw/workspace/Creative/Kira/The_Dissolution_Chambers/assets/backgrounds")
OUT_OBJ = Path("/root/.openclaw/workspace/Creative/Kira/The_Dissolution_Chambers/assets/objects")
OUT_PART = Path("/root/.openclaw/workspace/Creative/Kira/The_Dissolution_Chambers/assets/particles")

# Ensure dirs exist
for p in [OUT_BG, OUT_OBJ, OUT_PART]:
    p.mkdir(parents=True, exist_ok=True)

# Target sizes
BG_SIZE = (1920, 1080)
OBJ_SIZE = (400, 400)

def generate_bg(name, prompt, seed=2000):
    target = OUT_BG / f"{name}.png"
    try:
        resp = requests.post(
            f"{BASE_URL}/generate-image-pixflux",
            headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
            json={"description": prompt, "image_size": {"width": 400, "height": 400}, "no_background": False, "seed": seed},
            timeout=120,
        )
        if resp.status_code == 200:
            data = resp.json()
            img_data = data.get("image")
            b64 = img_data.get("base64") if isinstance(img_data, dict) else (img_data if isinstance(img_data, str) else None)
            if b64:
                img = Image.open(io.BytesIO(base64.b64decode(b64)))
                img = img.resize(BG_SIZE, Image.NEAREST)
                img.save(target)
                print(f"[OK BG] {name}.png {img.size}")
                return True
        print(f"[FAIL BG] {name}: HTTP {resp.status_code}")
        return False
    except Exception as e:
        print(f"[ERROR BG] {name}: {e}")
        return False

def generate_obj(name, prompt, seed=3000):
    target = OUT_OBJ / f"{name}.png"
    try:
        resp = requests.post(
            f"{BASE_URL}/generate-image-pixflux",
            headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
            json={"description": prompt, "image_size": {"width": 400, "height": 400}, "no_background": True, "seed": seed},
            timeout=120,
        )
        if resp.status_code == 200:
            data = resp.json()
            img_data = data.get("image")
            b64 = img_data.get("base64") if isinstance(img_data, dict) else (img_data if isinstance(img_data, str) else None)
            if b64:
                img = Image.open(io.BytesIO(base64.b64decode(b64)))
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                # Post-process: remove corner background color
                px = img.load()
                w, h = img.size
                # Sample corners for background reference
                corners = [px[0,0], px[w-1,0], px[0,h-1], px[w-1,h-1]]
                bg_r = sum(c[0] for c in corners) // 4
                bg_g = sum(c[1] for c in corners) // 4
                bg_b = sum(c[2] for c in corners) // 4
                transparent = 0
                for y in range(h):
                    for x in range(w):
                        r, g, b, a = px[x, y]
                        dist = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
                        if dist < 90:  # tolerance
                            px[x, y] = (0, 0, 0, 0)
                            transparent += 1
                img = img.resize(OBJ_SIZE, Image.NEAREST)
                img.save(target)
                print(f"[OK OBJ] {name}.png {img.size} ({transparent} transparent px)")
                return True
        print(f"[FAIL OBJ] {name}: HTTP {resp.status_code}")
        return False
    except Exception as e:
        print(f"[ERROR OBJ] {name}: {e}")
        return False

# ========== BACKGROUNDS BATCH A ==========
# Rules: Atmosphere only. NO detailed objects that should be clickable.
# Mention shelves, walls, floor — but not the items ON them.

BG_JOBS = [
    # 1. Threshold — Entry chamber, purple mist, floating platforms, bioluminescent doorways
    ("threshold", 2000,
     "pixel art background, misty ethereal threshold chamber, floating stone platforms in purple fog, "
     "bioluminescent doorways glowing in distance, deep violet and lavender color palette, "
     "mysterious entrance to a daemonette realm, atmospheric, soft glowing light, "
     "top-down view, game environment, no objects or items, just architecture and atmosphere, "
     "crisp pixel edges, dark and moody"),

    # 2. Writing Room — Desk area, but NO papers/books/items. Just the room.
    ("writing_room", 2001,
     "pixel art background, cozy writer's study, wooden desk surface visible, empty bookshelves on walls, "
     "inkwell-shaped stain on desk, warm amber and purple lighting, fantasy study, "
     "window showing starfield, soft interior glow, game environment, "
     "no books or papers on desk, just the room architecture, atmospheric"),

    # 3. Garden — Organic growth, bioluminescent plants, but NO specific clickable plants
    ("garden", 2002,
     "pixel art background, mystical indoor garden, bioluminescent plants glowing softly, "
     "purple and green organic growth, vine-covered walls, soft earth floor, "
     "ethereal light filtering through leaves, fantasy greenhouse, "
     "no specific objects, just lush atmospheric vegetation, moody and alive, "
     "game environment, dark corners with glowing accents"),
]

# ========== OBJECTS BATCH A ==========
# Transparent-background items to place ON the backgrounds.

OBJ_JOBS = [
    # Writing Room objects
    ("desk_papers_scattered", 3000,
     "pixel art, scattered papers and manuscript pages on a desk, "
     "handwritten text visible, fantasy script, warm paper tones, "
     "game object, transparent background, crisp pixel edges"),
    
    ("inkwell_quill", 3001,
     "pixel art, ornate inkwell with feather quill, dark glass bottle, "
     "gold accents, magical purple ink glow, game object, "
     "transparent background, crisp pixel edges"),
     
    ("floating_word_glow", 3002,
     'pixel art, glowing floating word "BECOME" in golden script, '
     'ethereal light, magical text particle, game object, '
     'transparent background, crisp pixel edges'),
     
    # Garden objects
    ("plant_glowing_purple", 3003,
     "pixel art, small bioluminescent plant, purple petals glowing softly, "
     "ethereal light, magical flower, game object, "
     "transparent background, crisp pixel edges"),
     
    ("plant_carnivorous", 3004,
     "pixel art, small carnivorous plant, toothy maw, hungry looking, "
     "dark green with red accents, slightly menacing, game object, "
     "transparent background, crisp pixel edges"),
     
    ("crystal_growth", 3005,
     "pixel art, small purple crystal formation growing from ground, "
     "glowing facets, magical mineral, game object, "
     "transparent background, crisp pixel edges"),
]

if __name__ == "__main__":
    ok = 0; fail = 0
    
    # Generate backgrounds
    print("=== BACKGROUNDS ===")
    for name, seed, prompt in BG_JOBS:
        print(f"[BG] {name}...", end=" ", flush=True)
        if generate_bg(name, prompt, seed):
            ok += 1
        else:
            fail += 1
        time.sleep(2)
    
    # Generate objects
    print("\n=== OBJECTS ===")
    for name, seed, prompt in OBJ_JOBS:
        print(f"[OBJ] {name}...", end=" ", flush=True)
        if generate_obj(name, prompt, seed):
            ok += 1
        else:
            fail += 1
        time.sleep(2)
    
    print(f"\nDONE: {ok}/{ok+fail} OK, {fail} failed")
