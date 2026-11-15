"""Render a top-down minimap of scenes/habitat_decor.tscn.

Layout comes from the scene's node transforms (rooms are 20x20 m, corridors
4x8 m). Optional AI-generated floor textures (from Layer) fill each room.
Usage: python3 render.py OUT.png [TEXTURE_DIR]
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

# World-space (x, z) centers, measured from habitat_decor.tscn
ROOMS = [
    ("Módulo Central",     0.0,      0.0,     "central"),
    ("Cuartos",            0.0166,  19.6345,  "quarters"),
    ("Sala de Reuniones",  0.0,     47.0,     "briefing"),
    ("Enfermería",         0.0,     74.4,     "medbay"),
    ("Hidroponía",         0.0,    101.8,     "hydro"),
    ("Sala del Generador", -27.7637,  7.6104, "generator"),
    ("Sala de Oxígeno",    -27.58,  -11.59,   "oxygen"),
    ("Vestíbulo",          27.4181,   0.1327, "vestibule"),
    ("Sala de Mando",      27.4449, -27.6178, "command"),
]
# Corridors: (cx, cz, half_w_x, half_w_z) — no labels
CORRIDORS = [
    (-13.98, 0.16, 4.0, 2.0),    # central <-> generador (rotated 90°)
    (13.46, 0.16, 4.0, 2.0),     # central <-> vestíbulo
    (27.58, -13.54, 2.0, 4.0),   # vestíbulo <-> mando
    (-0.09, 33.23, 2.0, 4.0),    # cuartos <-> reuniones
    (-0.09, 60.83, 2.0, 4.0),    # reuniones <-> enfermería
    (-0.09, 88.23, 2.0, 4.0),    # enfermería <-> hidroponía
]
# Nombres en inglés (versión en/ del minimapa).
EN_NAMES = {
    "Módulo Central": "Central Module", "Cuartos": "Crew Quarters", "Sala de Reuniones": "Briefing Room",
    "Enfermería": "Medical Bay", "Hidroponía": "Hydroponics", "Sala del Generador": "Generator Room",
    "Sala de Oxígeno": "Oxygen Room", "Vestíbulo": "Lobby", "Sala de Mando": "Command Room",
}
# Accent colour per room (sci-fi palette matching each module's walls)
ACCENT = {
    "central": (120, 200, 255), "quarters": (90, 150, 255), "briefing": (255, 160, 70),
    "medbay": (90, 230, 160), "hydro": (130, 230, 90), "generator": (255, 90, 80),
    "oxygen": (90, 220, 240), "vestibule": (180, 200, 220), "command": (200, 130, 255),
}
HALF = 10.0
PPM = 14           # pixels per metre
MARGIN = 7.0       # metres


def find_font():
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/segoeuib.ttf",
              "/System/Library/Fonts/Supplemental/Arial Bold.ttf"):
        if os.path.exists(p):
            return p
    return "DejaVuSans-Bold.ttf"


def main(out, texdir=None, english=False):
    xs = [r[1] for r in ROOMS]; zs = [r[2] for r in ROOMS]
    minx, maxx = min(xs) - HALF - MARGIN, max(xs) + HALF + MARGIN
    minz, maxz = min(zs) - HALF - MARGIN, max(zs) + HALF + MARGIN
    W, H = int((maxx - minx) * PPM), int((maxz - minz) * PPM)
    to_px = lambda x, z: ((x - minx) * PPM, (z - minz) * PPM)

    bg = Image.new("RGBA", (W, H), (6, 10, 20, 255))
    d = ImageDraw.Draw(bg)
    for gx in range(0, W, PPM * 4):  # 4 m grid
        d.line([(gx, 0), (gx, H)], fill=(18, 30, 50, 255))
    for gy in range(0, H, PPM * 4):
        d.line([(0, gy), (W, gy)], fill=(18, 30, 50, 255))

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    shapes = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shapes)

    # corridors first (under rooms)
    for cx, cz, hx, hz in CORRIDORS:
        a = to_px(cx - hx, cz - hz); b = to_px(cx + hx, cz + hz)
        sd.rectangle([a, b], fill=(40, 52, 70, 255), outline=(110, 140, 170, 255), width=3)
        # centre walkway stripe
        if hx > hz:
            y = (a[1] + b[1]) / 2; sd.line([(a[0], y), (b[0], y)], fill=(230, 180, 60, 255), width=3)
        else:
            x = (a[0] + b[0]) / 2; sd.line([(x, a[1]), (x, b[1])], fill=(230, 180, 60, 255), width=3)

    room_px = []
    for name, x, z, key in ROOMS:
        if english:
            name = EN_NAMES.get(name, name)
        a = to_px(x - HALF, z - HALF); b = to_px(x + HALF, z + HALF)
        box = [int(a[0]), int(a[1]), int(b[0]), int(b[1])]
        room_px.append((name, key, box))
        col = ACCENT[key]
        gd.rounded_rectangle(box, radius=10, outline=col + (255,), width=14)
        tex = None
        if texdir:
            for ext in (".png", ".jpg", ".webp"):
                p = os.path.join(texdir, key + ext)
                if os.path.exists(p):
                    tex = Image.open(p).convert("RGBA"); break
        w, h = box[2] - box[0], box[3] - box[1]
        if tex is not None:
            tex = tex.resize((w, h), Image.LANCZOS)
            tex = ImageEnhance.Brightness(tex).enhance(0.62)  # keep labels readable
            tint = Image.new("RGBA", (w, h), col + (60,))
            tex = Image.alpha_composite(tex, tint)
        else:
            tex = Image.new("RGBA", (w, h), (30, 40, 58, 255))
            td = ImageDraw.Draw(tex)
            for i in range(0, w, PPM * 4):
                td.line([(i, 0), (i, h)], fill=(45, 58, 80, 255), width=2)
            for j in range(0, h, PPM * 4):
                td.line([(0, j), (w, j)], fill=(45, 58, 80, 255), width=2)
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=10, fill=255)
        shapes.paste(tex, (box[0], box[1]), mask)
        sd.rounded_rectangle(box, radius=10, outline=col + (255,), width=5)

    glow = glow.filter(ImageFilter.GaussianBlur(10))
    img = Image.alpha_composite(bg, glow)
    img = Image.alpha_composite(img, shapes)

    # labels
    d = ImageDraw.Draw(img)
    font_path = find_font()
    for name, key, box in room_px:
        w = box[2] - box[0]
        size = 34
        while True:
            f = ImageFont.truetype(font_path, size)
            words = name.split(" ")
            lines = [name] if d.textlength(name, font=f) < w * 0.86 else \
                [" ".join(words[:math.ceil(len(words) / 2)]), " ".join(words[math.ceil(len(words) / 2):])]
            if max(d.textlength(l, font=f) for l in lines) < w * 0.86 or size <= 18:
                break
            size -= 2
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        lh = size * 1.2
        total = lh * len(lines)
        # plate behind label
        pw = max(d.textlength(l, font=f) for l in lines) + 28
        plate = [cx - pw / 2, cy - total / 2 - 10, cx + pw / 2, cy + total / 2 + 10]
        ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle(plate, radius=10, fill=(5, 10, 22, 190),
                                              outline=ACCENT[key] + (255,), width=2)
        img = Image.alpha_composite(img, ov); d = ImageDraw.Draw(img)
        for i, l in enumerate(lines):
            y = cy - total / 2 + i * lh + lh / 2
            d.text((cx, y), l, font=f, fill=(240, 248, 255, 255), anchor="mm",
                   stroke_width=3, stroke_fill=(0, 0, 0, 255))

    # north arrow (Godot -Z = norte)
    f = ImageFont.truetype(font_path, 26)
    ax, ay = W - 50, 60
    d.polygon([(ax, ay - 30), (ax - 14, ay + 6), (ax + 14, ay + 6)], fill=(240, 248, 255, 255))
    d.text((ax, ay + 26), "N", font=f, fill=(240, 248, 255, 255), anchor="mm")
    img.convert("RGB").save(out)
    print("saved", out, img.size)




# ---------------------------------------------------------------------------
# Layer API (clave en API.txt): genera una textura de suelo cenital por sala.
# ---------------------------------------------------------------------------
import json, re, time, urllib.request, urllib.error

API = "https://api.app.layer.ai/api/v2"
PROMPTS = {
    "central": "central living module, metal floor tiles, bunks, cafeteria table, hydroponics rack",
    "quarters": "crew quarters, blue carpet, rows of bunk beds and bedside tables",
    "briefing": "briefing room, orange carpet, octagonal meeting table surrounded by 12 chairs",
    "medbay": "medical bay, white medical floor, hospital beds, cryo pods, biomonitors",
    "hydro": "hydroponics greenhouse, green plant beds in rows, grow lights",
    "generator": "generator room, red walls, large orange reactor generator, batteries, hazard stripes",
    "oxygen": "oxygen room, air tanks, pipes, air conditioners, control panel",
    "vestibule": "entrance lobby, big wall screen, control desk, stacked green batteries",
    "command": "command room, circular holographic orrery in the centre, six workstations",
}
STYLE = ("top-down orthographic view straight from above, sci-fi space station interior room, "
         "game minimap tile, clean stylised, square, no text, no letters")


def _req(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + token, "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.loads(resp.read().decode())


def _find(obj, keys):
    """Primer valor cuyo nombre de campo esté en keys (búsqueda recursiva)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in keys and isinstance(v, (str, int)):
                return v
        for v in obj.values():
            r = _find(v, keys)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = _find(v, keys)
            if r is not None:
                return r
    return None


def _urls(obj):
    s = json.dumps(obj)
    return re.findall(r'https?://[^"\\\s]+', s)


def read_token(project_root):
    txt = open(os.path.join(project_root, "API.txt"), encoding="utf-8").read()
    return txt.split("=", 1)[-1].strip()


def pick_model(token, ws):
    res = _req("GET", f"{API}/workspaces/{ws}/base-models?limit=100", token)
    items = res.get("data") or res.get("items") or res.get("base_models") or res.get("results") or []
    def is_img(m):
        t = json.dumps(m).lower()
        return "image" in t and "video" not in (str(m.get("modality", "")).lower())
    for pref in ("flux", "imagen", "gpt-image", "seedream", "sdxl"):
        for m in items:
            if is_img(m) and pref in json.dumps(m).lower():
                return _find(m, {"base_model_id", "id"})
    for m in items:
        if is_img(m):
            return _find(m, {"base_model_id", "id"})
    raise RuntimeError("No se encontró un modelo de imagen en el workspace")


def generate_textures(project_root, texdir):
    token = read_token(project_root)
    ws_res = _req("GET", f"{API}/workspaces", token)
    ws = os.environ.get("LAYER_WORKSPACE_ID") or _find(ws_res, {"workspace_id", "id"})
    model = pick_model(token, ws)
    print("workspace", ws, "model", model)
    os.makedirs(texdir, exist_ok=True)
    jobs = {}
    for key, desc in PROMPTS.items():
        if os.path.exists(os.path.join(texdir, key + ".png")):
            continue
        body = {"base_model_id": model, "prompt": f"{STYLE}, {desc}", "width": 1024, "height": 1024}
        res = _req("POST", f"{API}/workspaces/{ws}/inferences", token, body)
        jobs[key] = _find(res, {"inference_id", "id"})
        print("lanzado", key, jobs[key])
    t0 = time.time()
    while jobs and time.time() - t0 < 900:
        time.sleep(6)
        for key, iid in list(jobs.items()):
            res = _req("GET", f"{API}/workspaces/{ws}/inferences/{iid}", token)
            st = str(res.get("status", "")).lower()
            if st in ("complete", "completed", "succeeded"):
                url = next(u for u in _urls(res) if re.search(r"\.(png|jpe?g|webp)", u, re.I)
                           or "file" in u or "asset" in u)
                raw = urllib.request.urlopen(url, timeout=120).read()
                p = os.path.join(texdir, key + ".png")
                open(p + ".tmp", "wb").write(raw)
                Image.open(p + ".tmp").convert("RGB").save(p); os.remove(p + ".tmp")
                print("descargado", key); del jobs[key]
            elif st in ("failed", "error", "cancelled"):
                print("falló", key, res); del jobs[key]


if __name__ == "__main__":
    # uso: python tools/generate_minimap.py  (desde la raíz del proyecto)
    root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    outdir = os.path.join(root, "ai_assets", "IMG", "Map")
    texdir = os.path.join(outdir, "textures")
    os.makedirs(outdir, exist_ok=True)
    if "--no-api" not in sys.argv:
        generate_textures(root, texdir)
    main(os.path.join(outdir, "minimapa_habitat.png"), texdir)
    os.makedirs(os.path.join(outdir, "en"), exist_ok=True)
    main(os.path.join(outdir, "en", "minimapa_habitat.png"), texdir, english=True)
