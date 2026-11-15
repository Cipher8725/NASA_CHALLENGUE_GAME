"""Descarga los datos reales de la NASA y la CSA para el juego NaSA-GAME.

Se ejecuta UNA vez; los JSON resultantes se versionan en resources/.
Cada bloque escribe un JSON con campos "fuentes" (URL) y "fecha_descarga".
"""

import json
import os
import urllib.request
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FECHA_DESCARGA = datetime.now(timezone.utc).strftime("%Y-%m-%d")

UA = {"User-Agent": "Mozilla/5.0 (NASA-SpaceApps-NaSA-GAME data fetcher)"}


def get(url, timeout=180):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def get_json(url, timeout=180):
    return json.loads(get(url, timeout).decode("utf-8"))


def write_json(rel_path, data):
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  escrito:", rel_path)


# ---------------------------------------------------------------- RadLab ISS
def radlab():
    """Dosis absorbida real medida en la ISS (instrumento TEPC, familia TEPC)."""
    print("RadLab...")
    url = ("https://visualization.osdr.nasa.gov/radlab/api/"
           "?format=json&spacecraft=ISS&instrument_family=TEPC"
           "&absorbed_dose_rate&dose_equivalent_rate")
    d = get_json(url)
    cols = d["columns"]
    i_ts = cols.index("timestamp")
    i_inst = cols.index("instrument_id")
    i_adr = cols.index("absorbed_dose_rate")
    i_der = cols.index("dose_equivalent_rate")

    filas = []
    for r in d["data"]:
        adr = r[i_adr]
        der = r[i_der]
        if adr is None:
            continue
        # La API entrega la tasa en µGy/h. La dosis diaria es esa tasa por
        # 24 horas: la misión dura un día en la ISS, así que la dosis diaria
        # absorbida es la misma que la exposición de 24 h de la tasa media.
        filas.append({
            "fecha": r[i_ts][:10],
            "instrumento": r[i_inst],
            "dosis_absorbida_ugy_dia": round(float(adr) * 24.0, 3),
            "tasa_absorbida_ugy_hora": round(float(adr), 5),
            "tasa_equivalente_usv_hora": (round(float(der), 5) if der is not None else None),
        })
    filas.sort(key=lambda x: (x["fecha"], x["instrumento"]))

    valores = [f["dosis_absorbida_ugy_dia"] for f in filas]
    media = sum(valores) / len(valores) if valores else 0.0
    insts = sorted({f["instrumento"] for f in filas})

    data = {
        "descripcion": ("Dosis absorbida medida en la ISS por los instrumentos "
                        "TEPC (Tissue Equivalent Proportional Counter), "
                        "recogida por el RadLab de la NASA."),
        "fuentes": ["https://visualization.osdr.nasa.gov/radlab/api/",
                    "https://visualization.osdr.nasa.gov/radlab/gui/data-api/"],
        "url_consulta": url,
        "fecha_descarga": FECHA_DESCARGA,
        "unidades": {
            "dosis_absorbida_ugy_dia": "µGy/día (microgray por día)",
            "tasa_absorbida_ugy_hora": "µGy/hora",
            "tasa_equivalente_usv_hora": "µSv/hora",
        },
        "nota_conversion": ("RadLab publica la TASA de dosis absorbida en "
                            "µGy/hora. La dosis diaria se calcula multiplicando "
                            "esa tasa por 24 horas (un día completo en la ISS)."),
        "periodo": {
            "primera_medicion": filas[0]["fecha"] if filas else None,
            "ultima_medicion": filas[-1]["fecha"] if filas else None,
            "numero_de_mediciones_diarias": len(filas),
        },
        "instrumentos": insts,
        "estadisticas": {
            "dosis_absorbida_media_ugy_dia": round(media, 3),
            "dosis_absorbida_minima_ugy_dia": round(min(valores), 3) if valores else None,
            "dosis_absorbida_maxima_ugy_dia": round(max(valores), 3) if valores else None,
            "dosis_absorbida_media_mgy_dia": round(media / 1000.0, 6),
        },
        "mediciones": filas,
    }
    write_json("resources/radiacion/radlab_iss.json", data)
    print("    %d mediciones, media %.1f µGy/día" % (len(filas), media))


# ------------------------------------------------------------------- DONKI
def donki():
    """Tormentas solares (FLR) y eyecciones de masa coronal (CME) reales."""
    print("DONKI...")
    base = "https://ccmc.gsfc.nasa.gov/DONKI/api/donki/nuggets/"
    ini, fin = "2025-11-01", "2026-11-01"
    comunes = "startDate=%s&endDate=%s" % (ini, fin)

    flr_raw = get_json(base + "flr/?" + comunes)
    cme_raw = get_json(base + "cme/?" + comunes)

    eventos = []
    for f in flr_raw:
        clase = f.get("class") or ""
        if not clase:
            continue
        eventos.append({
            "tipo": "tormenta_solar",
            "id_donki": f.get("activityID"),
            "nugget_id": f.get("nuggetID"),
            "fecha": (f.get("peakTime") or f.get("startTime") or "")[:10],
            "fecha_inicio": (f.get("startTime") or "")[:10],
            "fecha_pico": (f.get("peakTime") or "")[:10],
            "clase": clase,
            "familia_clase": clase[0].upper() if clase else "",
            "ubicacion": f.get("sourceLocation") or "",
            "region_activa": f.get("activeRegionNum"),
            "catalog": f.get("catalog"),
        })

    for c in cme_raw:
        analyses = c.get("cmeAnalyses") or []
        vel = None
        hora = (c.get("startTime") or "")[:10]
        for a in analyses:
            if a.get("isMostAccurate") and a.get("speed"):
                vel = a.get("speed")
                break
        if vel is None and analyses:
            vel = analyses[0].get("speed")
        eventos.append({
            "tipo": "eyeccion_masa_coronal",
            "id_donki": c.get("activityID"),
            "nugget_id": c.get("nuggetID"),
            "fecha": hora,
            "fecha_inicio": hora,
            "velocidad_km_s": vel,
            "catalog": "M2M_CATALOG",
        })

    eventos.sort(key=lambda e: (e["fecha"], e["tipo"]))

    # Tabla clase -> severidad. Es una simplificacion de juego.
    severidades = {
        "C": {"severidad": 0.2, "etiqueta": "baja"},
        "M": {"severidad": 0.55, "etiqueta": "media"},
        "X": {"severidad": 0.9, "etiqueta": "alta"},
    }

    data = {
        "descripcion": ("Eventos reales de clima espacial de la base de datos "
                        "DONKI de la NASA: tormentas solares (FLR) y eyecciones "
                        "de masa coronal (CME)."),
        "fuentes": ["https://ccmc.gsfc.nasa.gov/DONKI/",
                    "https://ccmc.gsfc.nasa.gov/DONKI/api/",
                    "https://ccmc.gsfc.nasa.gov/tools/DONKI/"],
        "urls_consulta": {
            "tormentas_solares": base + "flr/?" + comunes,
            "eyecciones_masa_coronal": base + "cme/?" + comunes,
        },
        "fecha_descarga": FECHA_DESCARGA,
        "periodo_consultado": {"desde": ini, "hasta": fin},
        "catalogo": "M2M_CATALOG",
        "clase_a_severidad": {
            "C": {"severidad": severidades["C"]["severidad"],
                  "etiqueta": severidades["C"]["etiqueta"]},
            "M": {"severidad": severidades["M"]["severidad"],
                  "etiqueta": severidades["M"]["etiqueta"]},
            "X": {"severidad": severidades["X"]["severidad"],
                  "etiqueta": severidades["X"]["etiqueta"]},
        },
        "nota_severidad": ("APROXIMADO (juego): la tabla clase -> severidad NO "
                           "es de la NASA. Es una simplificacion para que la "
                           "partida de 180 s sea jugable. La clase C/M/X si es "
                           "el dato real de DONKI."),
        "totales": {
            "eventos": len(eventos),
            "tormentas_solares": sum(1 for e in eventos if e["tipo"] == "tormenta_solar"),
            "eyecciones_masa_coronal": sum(1 for e in eventos if e["tipo"] == "eyeccion_masa_coronal"),
        },
        "eventos": eventos,
    }
    write_json("resources/radiacion/donki_eventos.json", data)
    print("    %d eventos (%d FLR, %d CME)" % (
        len(eventos), data["totales"]["tormentas_solares"],
        data["totales"]["eyecciones_masa_coronal"]))


# -------------------------------------------------------------------- OSDR
def osdr():
    """Estudios reales del repositorio OSDR de la NASA."""
    print("OSDR...")
    ids = ["OSD-655", "OSD-780", "OSD-745"]
    estudios = []
    for sid in ids:
        d = get_json("https://osdr.nasa.gov/osdr/data/search?term=%s" % sid)
        hits = [h for h in d.get("hits", {}).get("hits", [])
                if h.get("_source", {}).get("Study Identifier") == sid]
        if not hits:
            print("    AVISO: no se encontro", sid)
            continue
        s = hits[0]["_source"]
        estudios.append({
            "id": sid,
            "titulo": s.get("Study Title", ""),
            "titulo_publicacion": s.get("Study Publication Title", ""),
            "proyecto": s.get("Project Identifier", ""),
            "titulo_proyecto": s.get("Project Title", ""),
            "organismo": s.get("organism", ""),
            "material": s.get("Material Type", ""),
            "programa": s.get("Flight Program", ""),
            "centro_gestor": s.get("Managing NASA Center", ""),
            "protocolo": " ".join(str(s.get("Study Protocol Name", "")).split()),
            "tecnicas": " ".join(str(s.get("Study Assay Technology Type", "")).split()),
            "factores": " ".join(str(s.get("Study Factor Name", "")).split()),
            "descripcion": " ".join(str(s.get("Study Description", "")).split()),
            "descripcion_protocolo": " ".join(str(s.get("Study Protocol Description", "")).split()),
            "autores_publicacion": " ".join(str(s.get("Study Publication Author List", "")).split()),
            "enlace": "https://osdr.nasa.gov/osdr/data/studies/%s" % sid,
            "url_consulta": "https://osdr.nasa.gov/osdr/data/search?term=%s" % sid,
        })

    data = {
        "descripcion": ("Estudios reales del Open Science Data Repository (OSDR) "
                        "de la NASA sobre fisiologia humana en el espacio y "
                        "cultivos espaciales."),
        "fuentes": ["https://osdr.nasa.gov/osdr/data/search?term=bone",
                    "https://osdr.nasa.gov/",
                    "https://visualization.osdr.nasa.gov/bio/repo/data/studies/OSD-655"],
        "fecha_descarga": FECHA_DESCARGA,
        "estudios": estudios,
    }
    write_json("resources/biblioteca/osdr_estudios.json", data)
    print("    %d estudios" % len(estudios))


if __name__ == "__main__":
    radlab()
    donki()
    osdr()
    print("Listo.")
