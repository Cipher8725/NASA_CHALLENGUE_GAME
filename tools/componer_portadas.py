"""Compone las portadas nuevas de la biblioteca con el estilo art deco de las
existentes: marco dorado y turquesa, titulo en serif y la ilustracion real de
la NASA en la parte central.

El arte se descarga con tools/descargar_arte_biblioteca.py.
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "ai_assets", "ui", "biblioteca", "portadas")

# Paleta tomada de las portadas existentes.
FONDO = (6, 38, 44)
FONDO_OSCURO = (2, 22, 27)
DORADO = (201, 158, 74)
DORADO_CLARO = (238, 206, 133)
TURQUESA = (52, 168, 178)
CREMA = (243, 235, 214)

ANCHO = 312
ALTO = 378


def fuente_serif(tamano: int) -> ImageFont.FreeTypeFont:
    """Busca una fuente serif del sistema para el titulo."""
    candidatas = [
        "C:/Windows/Fonts/georgiab.ttf",
        "C:/Windows/Fonts/georgia.ttf",
        "C:/Windows/Fonts/timesbd.ttf",
        "C:/Windows/Fonts/times.ttf",
        "C:/Windows/Fonts/constanb.ttf",
    ]
    for ruta in candidatas:
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tamano)
    return ImageFont.load_default()


def marco(draw: ImageDraw.ImageDraw, ancho: int, alto: int) -> None:
    """Dibuja el marco art deco: doble filete dorado con esquinas."""
    # Marco exterior e interior.
    draw.rectangle([0, 0, ancho - 1, alto - 1], outline=DORADO, width=3)
    draw.rectangle([7, 7, ancho - 8, alto - 8], outline=DORADO, width=1)
    # Filetes turquesa que accompanying al dorado.
    draw.rectangle([12, 12, ancho - 13, alto - 13], outline=TURQUESA, width=1)
    draw.rectangle([16, 16, ancho - 17, alto - 17], outline=DORADO_CLARO, width=1)
    # Esquinas:uadrilátero art deco.
    for x, y, dx, dy in ((0, 0, 1, 1), (ancho - 1, 0, -1, 1), (0, alto - 1, 1, -1), (ancho - 1, alto - 1, -1, -1)):
        draw.polygon(
            [
                (x + dx * 46, y + dy * 4),
                (x + dx * 46, y + dy * 17),
                (x + dx * 4, y + dy * 46),
                (x + dx * 4, y + dy * 4),
            ],
            outline=DORADO,
        )
        draw.polygon(
            [
                (x + dx * 40, y + dy * 9),
                (x + dx * 40, y + dy * 16),
                (x + dx * 9, y + dy * 40),
                (x + dx * 9, y + dy * 9),
            ],
            outline=TURQUESA,
        )


def panel_titulo(draw: ImageDraw.ImageDraw, ancho: int) -> None:
    """Banda superior donde va el titulo."""
    alto_panel = 118
    draw.rectangle([30, 26, ancho - 31, 26 + alto_panel], fill=FONDO, outline=DORADO, width=2)
    draw.rectangle([36, 32, ancho - 37, 26 + alto_panel - 6], outline=TURQUESA, width=1)


def escribir_titulo(imagen: Image.Image, titulo: str) -> None:
    """Escribe el titulo centrado en la banda superior, en dos lineas."""
    draw = ImageDraw.Draw(imagen)
    fuente = fuente_serif(30)
    ancho, alto = imagen.size
    palabras = titulo.split()
    lineas = []
    actual = ""
    for palabra in palabras:
        prueba = (actual + " " + palabra).strip()
        if draw.textlength(prueba, font=fuente) > (ancho - 76) and actual:
            lineas.append(actual)
            actual = palabra
        else:
            actual = prueba
    if actual:
        lineas.append(actual)
    y = 48
    for linea in lineas:
        ancho_texto = draw.textlength(linea, font=fuente)
        x = (ancho - ancho_texto) * 0.5
        # Sombra para que resalte sobre el fondo.
        draw.text((x + 2, y + 2), linea, font=fuente, fill=(0, 0, 0))
        draw.text((x, y), linea, font=fuente, fill=CREMA)
        y += 36


def pegar_arte(imagen: Image.Image, ruta_arte: str, caja: tuple) -> None:
    """Pega la foto de la NASA en la region de ilustracion, con borde dorado."""
    x0, y0, x1, y1 = caja
    ancho, alto = x1 - x0, y1 - y0
    arte = Image.open(ruta_arte).convert("RGB")
    # Recorte centrado en la region pedida.
    escala = max(ancho / arte.width, alto / arte.height)
    nuevo = (max(1, int(arte.width * escala)), max(1, int(arte.height * escala)))
    arte = arte.resize(nuevo, Image.LANCZOS)
    izquierda = (nuevo[0] - ancho) // 2
    arriba = (nuevo[1] - alto) // 2
    arte = arte.crop((izquierda, arriba, izquierda + ancho, arriba + alto))
    imagen.paste(arte, (x0, y0))
    draw = ImageDraw.Draw(imagen)
    draw.rectangle([x0, y0, x1 - 1, y1 - 1], outline=DORADO, width=2)


def emblemas(imagen: Image.Image) -> None:
    """Pequeños emblemas circulares arriba y abajo, como en las otras portadas."""
    draw = ImageDraw.Draw(imagen)
    ancho, alto = imagen.size
    for cy in (10, alto - 11):
        r = 9
        draw.ellipse([ancho // 2 - r, cy - r, ancho // 2 + r, cy + r], outline=DORADO, width=1)
        draw.ellipse([ancho // 2 - r + 3, cy - r + 3, ancho // 2 + r - 3, cy + r - 3], outline=TURQUESA, width=1)


def componer(nombre: str, titulo: str, arte: str) -> None:
    imagen = Image.new("RGB", (ANCHO, ALTO), FONDO)
    # Degradado vertical suave del fondo.
    degradado = Image.new("RGB", (ANCHO, ALTO), FONDO_OSCURO)
    d = ImageDraw.Draw(degradado)
    for y in range(ALTO):
        t = y / float(ALTO)
        color = (
            int(FONDO_OSCURO[0] + (FONDO[0] - FONDO_OSCURO[0]) * t),
            int(FONDO_OSCURO[1] + (FONDO[1] - FONDO_OSCURO[1]) * t),
            int(FONDO_OSCURO[2] + (FONDO[2] - FONDO_OSCURO[2]) * t),
        )
        d.line([(0, y), (ANCHO, y)], fill=color)
    imagen = degradado

    caja_arte = (26, 158, ANCHO - 27, ALTO - 30)
    pegar_arte(imagen, os.path.join(DEST, arte), caja_arte)

    draw = ImageDraw.Draw(imagen)
    marco(draw, ANCHO, ALTO)
    panel_titulo(draw, ANCHO)
    emblemas(imagen)
    escribir_titulo(imagen, titulo)

    ruta = os.path.join(DEST, nombre)
    imagen.save(ruta, "PNG", optimize=True)
    print("  escrita:", nombre, imagen.size)


def main() -> int:
    print("Componiendo las portadas nuevas...")
    componer("cuerpo_espacio.png", "Tu cuerpo en el espacio", "_arte_cuerpo_espacio.jpg")
    componer("clima_espacio.png", "El clima del espacio", "_arte_clima_espacio.jpg")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
