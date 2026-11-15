"""Genera el domo de la estación con la API de Meshy (text-to-3d) y lo guarda en
res://ai_assets/models/domo/domo_estacion.glb (AGENTS.md §4).

Uso:
    python tools/generar_domo_meshy.py saldo      # solo consulta los créditos
    python tools/generar_domo_meshy.py generar    # preview + refine + descarga

La clave se lee de la variable de entorno MESHY_API_KEY y nunca se imprime.
El progreso se guarda en ai_assets/models/domo/meshy_tareas.json para poder
reanudar la descarga sin volver a gastar créditos si el script se corta.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.meshy.ai"
RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "ai_assets" / "models" / "domo"
ESTADO = DESTINO / "meshy_tareas.json"
GLB = DESTINO / "domo_estacion.glb"

PROMPT = (
    "Huge sci-fi geodesic dome for a lunar base, a hollow hemisphere shell made of "
    "triangular glass panels held by a thin white metal lattice frame, open bottom "
    "with no floor, empty inside, smooth regular shape, symmetrical"
)
NEGATIVO = "floor, base platform, buildings inside, interior objects, people, text"


def _clave() -> str:
    clave = os.environ.get("MESHY_API_KEY", "").strip()
    if not clave:
        sys.exit("Falta la variable de entorno MESHY_API_KEY.")
    return clave


def _peticion(metodo: str, ruta: str, cuerpo: dict | None = None) -> dict:
    datos = json.dumps(cuerpo).encode("utf-8") if cuerpo is not None else None
    req = urllib.request.Request(API + ruta, data=datos, method=metodo)
    req.add_header("Authorization", "Bearer " + _clave())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        detalle = err.read().decode("utf-8", "replace")[:500]
        sys.exit(f"Meshy respondió {err.code} en {ruta}: {detalle}")


def _esperar(tarea: str) -> dict:
    """Consulta la tarea cada 10 s hasta que termine."""
    while True:
        info = _peticion("GET", f"/openapi/v2/text-to-3d/{tarea}")
        estado = info.get("status")
        print(f"  tarea {tarea[:8]}…: {estado} {info.get('progress', 0)}%", flush=True)
        if estado == "SUCCEEDED":
            return info
        if estado in ("FAILED", "CANCELED", "EXPIRED"):
            sys.exit(f"La tarea terminó en {estado}: {info.get('task_error')}")
        time.sleep(10)


def _guardar_estado(estado: dict) -> None:
    ESTADO.write_text(json.dumps(estado, indent=2), encoding="utf-8")


def saldo() -> None:
    print("Créditos disponibles:", _peticion("GET", "/openapi/v1/balance").get("balance"))


def generar() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    estado: dict = json.loads(ESTADO.read_text(encoding="utf-8")) if ESTADO.exists() else {}

    # 1) Preview: la geometría (sin textura).
    if "preview" not in estado:
        resp = _peticion("POST", "/openapi/v2/text-to-3d", {
            "mode": "preview",
            "prompt": PROMPT,
            "negative_prompt": NEGATIVO,
            "art_style": "realistic",
            "should_remesh": True,
            "topology": "triangle",
            "target_polycount": 30000,
        })
        estado["preview"] = resp["result"]
        _guardar_estado(estado)
    print("Preview:", estado["preview"][:8], flush=True)
    _esperar(estado["preview"])

    # 2) Refine: añade las texturas PBR sobre la misma geometría.
    if "refine" not in estado:
        resp = _peticion("POST", "/openapi/v2/text-to-3d", {
            "mode": "refine",
            "preview_task_id": estado["preview"],
            "enable_pbr": True,
        })
        estado["refine"] = resp["result"]
        _guardar_estado(estado)
    print("Refine:", estado["refine"][:8], flush=True)
    info = _esperar(estado["refine"])

    # 3) Descarga del .glb final.
    url = info.get("model_urls", {}).get("glb")
    if not url:
        sys.exit("La tarea no devolvió un .glb.")
    with urllib.request.urlopen(url, timeout=300) as resp:
        GLB.write_bytes(resp.read())
    estado["glb"] = str(GLB.relative_to(RAIZ)).replace("\\", "/")
    _guardar_estado(estado)
    print(f"Descargado {GLB.relative_to(RAIZ)} ({GLB.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    {"saldo": saldo, "generar": generar}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit(__doc__))()
