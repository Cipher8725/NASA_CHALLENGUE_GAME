"""Descarga UNA vez 6 fotos reales del rover Perseverance (NASA).

Fuente: catalogo de imagenes de la NASA (images-api.nasa.gov).
Si la API no responde, el script lo avisa y NO usa fotos de otra fuente.
"""

import json
import os
import re
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "ai_assets", "perseverance_fotos")
UA = {"User-Agent": "Mozilla/5.0 (NASA-SpaceApps-NaSA-GAME photo fetcher)"}
FECHA = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def get(url, timeout=180):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def get_json(url, timeout=180):
    return json.loads(get(url, timeout).decode("utf-8"))


def main():
    os.makedirs(DEST, exist_ok=True)
    print("Buscando fotos REALES de la superficie de Marte en el catalogo de la NASA...")

    # Se prueban varias consultas y se descartan las ilustraciones de artista:
    # solo interesan imagenes tomadas por las camaras del rover o por orbitadores.
    consultas = [
        "https://images-api.nasa.gov/search?q=perseverance+mastcam+z+rock+surface&media_type=image&page_size=100",
        "https://images-api.nasa.gov/search?q=perseverance+navigation+camera+martian+surface&media_type=image&page_size=100",
        "https://images-api.nasa.gov/search?q=mars+2020+perseverance+rock+closeup&media_type=image&page_size=100",
        "https://images-api.nasa.gov/search?q=perseverance+rover+tracks+martian+soil&media_type=image&page_size=100",
    ]

    candidatos = []
    vistas = set()
    for consulta in consultas:
        try:
            datos = get_json(consulta)
        except Exception as exc:
            print("  aviso: consulta fallo (%s): %s" % (consulta, exc))
            continue
        for item in datos.get("collection", {}).get("items", []):
            href = item.get("href")
            if not href or href in vistas:
                continue
            vistas.add(href)
            candidatos.append((item, consulta))
    print("  candidatos unicos: %d" % len(candidatos))

    fotos = []
    for item, consulta in candidatos:
        if len(fotos) >= 6:
            break

        # `collection.json` es la lista de URLs de la imagen (orig/large/...).
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

        # Los metadatos vienen en el propio resultado de la busqueda.
        meta = {}
        for d in item.get("data", []):
            if isinstance(d, dict):
                meta = d
                break

        titulo = str(meta.get("title") or "").strip()
        descripcion = str(meta.get("description") or "").strip()
        fecha = str(meta.get("date_created") or "")[:10]
        centro = str(meta.get("center") or "").strip()
        album = meta.get("album") or []
        album_texto = ", ".join([str(a) for a in album])

        # Se descartan las ilustraciones de artista: no son fotos del rover.
        if _es_ilustracion(titulo, descripcion):
            continue

        camara = _extraer_camara(titulo, descripcion)
        sol = _extraer_sol(descripcion)
        if camara == "" and sol == "":
            # Sin camara ni sol identificables no se sabe que sea del rover.
            continue

        nasa_id = str(meta.get("nasa_id") or "").strip()
        if not nasa_id:
            nasa_id = os.path.basename(original).split("~")[0]
        nombre = "%s.jpg" % nasa_id
        ruta_rel = "ai_assets/perseverance_fotos/%s" % nombre

        try:
            datos_img = get(original)
        except Exception as exc:
            print("  aviso: no se pudo bajar %s (%s)" % (nasa_id, exc))
            continue
        if len(datos_img) < 20000:
            # Una imagen valida del catalogo es mucho mayor que 20 KB.
            continue
        with open(os.path.join(DEST, nombre), "wb") as f:
            f.write(datos_img)

        fotos.append({
            "archivo": ruta_rel,
            "nasa_id": nasa_id,
            "titulo": titulo,
            "descripcion": descripcion,
            "fecha": fecha,
            "credito": "NASA/JPL-Caltech",
            "centro": centro,
            "album": album_texto,
            "url_original": original,
            "url_consulta": item["href"],
            "sol": sol,
            "camara": camara,
        })
        print("  bajada: %s (%d bytes) %s | sol=%s cam=%s"
              % (nombre, len(datos_img), titulo[:38], sol or "-", camara or "-"))

    if not fotos:
        print("AVISO: no se obtuvo ninguna foto valida de la NASA.")
        return 1

    meta = {
        "descripcion": ("Fotos reales de la superficie de Marte tomadas por el "
                        "rover Perseverance de la NASA, descargadas del "
                        "catalogo de imagenes de la NASA."),
        "fuentes": ["https://images.nasa.gov/",
                    "https://images-api.nasa.gov/search?q=perseverance+rover+mars+surface"],
        "url_consulta": consulta,
        "fecha_descarga": FECHA,
        "credito": "NASA/JPL-Caltech",
        "nota": ("El campo 'sol' y 'camara' se han extraido de la descripcion "
                 "oficial de la imagen en el catalogo de la NASA. Si una foto "
                 "no los trae, el campo queda vacio (no se inventa)."),
        "fotos": fotos,
    }
    with open(os.path.join(DEST, "fotos.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  metadata: ai_assets/perseverance_fotos/fotos.json (%d fotos)" % len(fotos))
    return 0


def _es_ilustracion(titulo, descripcion):
    """Descarta ilustraciones de artista y animaciones: no son fotos del rover."""
    texto = ("%s %s" % (titulo or "", descripcion or "")).lower()
    marcas = ("illustration", "artist's concept", "artists concept", "artist concept",
              "concept art", "illustration depicts", "rendering", "artwork",
              "animation", "animated", "this animation shows")
    return any(m in texto for m in marcas)


def _extraer_sol(texto):
    """Extrae el sol marciano de la descripcion oficial de la NASA.

    La NASA lo escribe de dos formas:
      - "on sol 1234"
      - "the 836th Martian day, or sol, of the mission"
    Si no aparece, se devuelve la cadena vacia: no se inventa el valor.
    """
    t = texto or ""
    m = re.search(r"\bsol\s*(\d{1,5})\b", t, re.IGNORECASE)
    if m:
        return m.group(1)
    m = re.search(r"(\d{1,5})(?:st|nd|rd|th)\s+Martian\s+day", t, re.IGNORECASE)
    if m:
        return m.group(1)
    m = re.search(r"(\d{1,5})(?:st|nd|rd|th)\s+Martian\s+day[^.]*?sol", t, re.IGNORECASE)
    if m:
        return m.group(1)
    return ""


def _extraer_camara(titulo, descripcion):
    """Extrae la camara de la descripcion oficial de la NASA."""
    texto = "%s %s" % (titulo or "", descripcion or "")
    for patron in (r"\b(Mastcam[- ]?Z)\b", r"\b(Mastcam)\b", r"\b(Navcam|Navigation Camera)\b",
                   r"\b(Front Hazard Avoidance Camera)\b", r"\b(Rear Hazard Avoidance Camera)\b",
                   r"\b(SuperCam)\b", r"\b(PIXL)\b", r"\b(MEDA)\b", r"\b(Sherloc)\b",
                   r"\b(HiRISE)\b", r"\b(Context Camera)\b"):
        m = re.search(patron, texto, re.IGNORECASE)
        if m:
            return m.group(1)
    return ""


if __name__ == "__main__":
    raise SystemExit(main())
