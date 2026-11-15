"""Descarga las imagenes de la NASA que ilustraran las dos portadas nuevas
de la biblioteca. Se guardan en ai_assets/ui/biblioteca/portadas/ como arte
(originales) y se documentan con su fuente.
"""

import json
import os
import re
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "ai_assets", "ui", "biblioteca", "portadas")
UA = {"User-Agent": "Mozilla/5.0 (NASA-SpaceApps-NaSA-GAME art fetcher)"}


def get(url, timeout=180):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def get_json(url, timeout=180):
    return json.loads(get(url, timeout).decode("utf-8"))


def buscar_y_bajar(consulta, nombre,	max_intentos=40):
    """Busca una imagen real de la NASA y la descarga como arte de portada."""
    datos = get_json("https://images-api.nasa.gov/search?media_type=image&page_size=60&q=%s" % consulta)
    items = datos.get("collection", {}).get("items", [])
    print("  '%s': %d resultados" % (consulta, len(items)))
    for item in items:
        try:
            enlaces = get_json(item["href"])
        except Exception:
            continue
        if isinstance(enlaces, dict):
            enlaces = enlaces.get("links", [])
        if not isinstance(enlaces, list):
            continue
        original = None
        for url in enlaces:
            if isinstance(url, str) and "~orig" in url and url.lower().endswith((".jpg", ".jpeg")):
                original = url
                break
        if original is None:
            continue
        meta = {}
        for d in item.get("data", []):
            if isinstance(d, dict):
                meta = d
                break
        titulo = str(meta.get("title") or "")
        descripcion = str(meta.get("description") or "")
        # Se descartan ilustraciones de artista: buscamos fotos reales.
        texto = (titulo + " " + descripcion).lower()
        if any(m in texto for m in ("illustration", "artist's concept", "artists concept", "rendering")):
            continue
        try:
            datos_img = get(original)
        except Exception:
            continue
        if len(datos_img) < 40000:
            continue
        nasa_id = str(meta.get("nasa_id") or os.path.basename(original).split("~")[0])
        ruta_rel = "ai_assets/ui/biblioteca/portadas/%s" % nombre
        with open(os.path.join(DEST, nombre), "wb") as f:
            f.write(datos_img)
        print("  bajada %s (%d bytes) <- %s" % (nombre, len(datos_img), titulo[:60]))
        return {
            "archivo": ruta_rel,
            "nasa_id": nasa_id,
            "titulo": titulo,
            "descripcion": descripcion,
            "fecha": str(meta.get("date_created") or "")[:10],
            "credito": "NASA",
            "url_original": original,
        }
    print("  AVISO: no se encontro imagen valida para '%s'" % consulta)
    return None


def main():
    os.makedirs(DEST, exist_ok=True)
    arte = []
    print("Buscando arte de las portadas nuevas en el catalogo de la NASA...")
    r1 = buscar_y_bajar("aurora+space+station+solar+storm", "_arte_clima_espacio.jpg")
    if r1:
        arte.append(r1)
    r2 = buscar_y_bajar("astronaut+treadmill+exercise+space+station", "_arte_cuerpo_espacio.jpg")
    if r2 is None:
        r2 = buscar_y_bajar("veggie+plant+growth+space+station", "_arte_cuerpo_espacio.jpg")
    if r2:
        arte.append(r2)
    if not arte:
        print("AVISO: no se obtuvo arte de la NASA.")
        return 1
    with open(os.path.join(DEST, "_arte_fuentes.json"), "w", encoding="utf-8") as f:
        json.dump({
            "descripcion": "Arte original de la NASA usado en las portadas nuevas de la biblioteca.",
            "fuentes": ["https://images.nasa.gov/"],
            "url_consulta": "https://images-api.nasa.gov/search?media_type=image",
            "imagenes": arte,
        }, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  metadata: _arte_fuentes.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
