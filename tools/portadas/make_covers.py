# Portadas nuevas de la biblioteca con el mismo marco que las existentes.
# Se reutiliza el marco de una portada del mismo nivel, se borra su título y su dibujo,
# y se dibuja una ilustración nueva (sin fotos de terceros).
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
D = sys.argv[1]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
BOX = (30, 149, 297, 350)   # zona de la ilustración
TITLE = (34, 36, 293, 136)  # zona del título

def ornament_mask(img):
    # Conserva los adornos dorados y cian del marco que se montan sobre la ilustración.
    m = Image.new("L", img.size, 0); px = img.load(); mp = m.load()
    for y in range(BOX[1], BOX[3]):
        for x in range(BOX[0], BOX[2]):
            r, g, b, a = px[x, y]
            gold = r > 150 and g > 105 and b < 120 and r - b > 70
            cyan = b > 170 and g > 150 and r < 110
            near_edge = y > BOX[3] - 28 or x < BOX[0] + 22 or x > BOX[2] - 22 or y < BOX[1] + 14
            if near_edge and (gold or cyan):
                mp[x, y] = 255
    return m.filter(ImageFilter.MaxFilter(3))

def frame_mask(base, other):
    # El marco es idéntico en todas las portadas del mismo nivel: donde dos portadas
    # coinciden píxel a píxel, ese píxel es marco (se conserva); donde no, es dibujo.
    a = Image.open(f"{D}/{base}").convert("RGB"); b = Image.open(f"{D}/{other}").convert("RGB")
    m = Image.new("L", a.size, 0); pa, pb, mp = a.load(), b.load(), m.load()
    for y in range(BOX[1] - 4, BOX[3] + 4):
        for x in range(BOX[0] - 4, BOX[2] + 4):
            edge = x < BOX[0] + 14 or x > BOX[2] - 14 or y < BOX[1] + 8 or y > BOX[3] - 22
            if edge and sum(abs(pa[x, y][i] - pb[x, y][i]) for i in range(3)) < 24:
                mp[x, y] = 255
    return m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))

def make(base, other, title_lines, art, out):
    img = Image.open(f"{D}/{base}").convert("RGBA")
    keep = frame_mask(base, other)
    orig = img.copy()
    W, H = BOX[2] - BOX[0], BOX[3] - BOX[1]
    pic = art(W, H)
    img.paste(pic, (BOX[0], BOX[1]))
    img.paste(orig, (0, 0), keep)
    d = ImageDraw.Draw(img)
    # Fondo del título: se copia el color de la franja izquierda (sin texto), fila por fila.
    for y in range(TITLE[1], TITLE[3]):
        c = orig.getpixel((38, y))
        d.line([(TITLE[0], y), (TITLE[2], y)], fill=c)
    f = ImageFont.truetype(FONT, 29)
    total = len(title_lines) * 36
    y0 = (TITLE[1] + TITLE[3]) // 2 - total // 2
    for i, line in enumerate(title_lines):
        w = d.textlength(line, font=f)
        x = (311 - w) / 2
        d.text((x + 2, y0 + i * 36 + 2), line, font=f, fill=(0, 0, 0, 160))
        d.text((x, y0 + i * 36), line, font=f, fill=(247, 232, 196, 255))
    img.save(f"{D}/{out}")

def glow(size, center, radius, color, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([center[0]-radius, center[1]-radius, center[0]+radius, center[1]+radius], fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur))

def veggie(W, H):
    # Huerto Veggie de la ISS: cámara iluminada con LED rojo y azul, lechugas rojas y mizuna.
    random.seed(4)
    im = Image.new("RGBA", (W, H), (20, 10, 30, 255))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(70 + 90 * (1 - t)), int(18 + 10 * t), int(80 + 60 * (1 - t)), 255))
    im = Image.alpha_composite(im, glow((W, H), (W // 2, 10), 120, (255, 80, 200, 150), 30))
    d = ImageDraw.Draw(im)
    # Paredes de la cámara (tela blanca del Veggie)
    d.polygon([(0, 0), (34, 22), (34, H - 40), (0, H)], fill=(205, 190, 215, 255))
    d.polygon([(W, 0), (W - 34, 22), (W - 34, H - 40), (W, H)], fill=(190, 175, 205, 255))
    # Barra de LED
    d.rectangle([34, 8, W - 34, 22], fill=(60, 50, 70, 255))
    for x in range(42, W - 40, 9):
        d.ellipse([x, 12, x + 5, 18], fill=(255, 60, 90, 255) if (x // 9) % 3 else (90, 120, 255, 255))
    # Base con almohadillas
    d.rectangle([34, H - 52, W - 34, H - 40], fill=(225, 225, 230, 255))
    for i in range(6):
        cx = 50 + i * ((W - 100) // 5)
        d.rectangle([cx - 14, H - 62, cx + 14, H - 50], fill=(240, 236, 220, 255))
        # Plantas: alternan lechuga roja (Outredgeous) y mizuna verde
        red = i % 2 == 0
        for k in range(9):
            ang = math.radians(-160 + k * 17 + random.uniform(-6, 6))
            L = random.uniform(26, 40) if red else random.uniform(30, 48)
            x2, y2 = cx + math.cos(ang) * L * 0.75, H - 62 + math.sin(ang) * L
            col = (150 + random.randint(0, 40), 30, 60, 255) if red else (90, 170 + random.randint(0, 40), 70, 255)
            if red:
                d.ellipse([min(cx, x2) - 7, min(H - 62, y2) - 5, max(cx, x2) + 7, max(H - 62, y2) + 3], fill=col)
            else:
                d.line([(cx, H - 62), (x2, y2)], fill=col, width=5)
                d.ellipse([x2 - 5, y2 - 5, x2 + 5, y2 + 5], fill=col)
    im = Image.alpha_composite(im, glow((W, H), (W // 2, H // 2), 140, (255, 60, 180, 45), 40))
    # Suelo de la estación
    d = ImageDraw.Draw(im)
    d.rectangle([0, H - 40, W, H], fill=(60, 64, 80, 255))
    d.line([(0, H - 40), (W, H - 40)], fill=(120, 125, 140, 255), width=2)
    return im

def space_weather(W, H):
    # Una erupción solar viaja hacia la Tierra; el campo magnético la desvía.
    random.seed(7)
    im = Image.new("RGBA", (W, H), (6, 6, 22, 255))
    d = ImageDraw.Draw(im)
    for _ in range(90):
        x, y = random.randint(0, W), random.randint(0, H)
        b = random.randint(120, 255)
        d.point((x, y), fill=(b, b, b, 255))
    sun = (-10, H // 2)
    im = Image.alpha_composite(im, glow((W, H), sun, 110, (255, 140, 40, 200), 28))
    im = Image.alpha_composite(im, glow((W, H), sun, 82, (255, 200, 80, 255), 6))
    d = ImageDraw.Draw(im)
    # Arcos de la erupción
    for k, (r, a0, a1) in enumerate([(30, 300, 420), (22, 320, 400), (40, 20, 120)]):
        cx, cy = 66, H // 2 - 40 + k * 40
        d.arc([cx - r, cy - r, cx + r, cy + r], a0, a1, fill=(255, 220, 120, 255), width=4)
    # Partículas viajando hacia la Tierra
    for i in range(140):
        t = random.random()
        x = 80 + t * 120
        y = H // 2 + random.gauss(0, 10 + t * 26)
        a = int(220 * (1 - t * 0.6))
        d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(255, 190, 90, a))
    earth = (W - 52, H // 2)
    # Campo magnético
    for s in (1.0, 1.5, 2.1, 2.8):
        d.ellipse([earth[0] - 26 * s * 0.8, earth[1] - 26 * s, earth[0] + 26 * s * 1.6, earth[1] + 26 * s], outline=(110, 170, 255, 170), width=2)
    im = Image.alpha_composite(im, glow((W, H), earth, 30, (90, 160, 255, 160), 8))
    d = ImageDraw.Draw(im)
    d.ellipse([earth[0] - 22, earth[1] - 22, earth[0] + 22, earth[1] + 22], fill=(30, 90, 190, 255))
    d.chord([earth[0] - 22, earth[1] - 22, earth[0] + 22, earth[1] + 22], 200, 300, fill=(60, 150, 80, 255))
    d.ellipse([earth[0] - 4, earth[1] + 2, earth[0] + 14, earth[1] + 14], fill=(70, 150, 80, 255))
    return im

make("rover.png", "soporte_vital.png", ["Tu cuerpo", "en el espacio"], veggie, "cuerpo_espacio.png")
make("control_mision.png", "trajes_espaciales.png", ["El clima", "del espacio"], space_weather, "clima_espacial.png")
