# =====================================================================
#  PUERTA CORREDIZA A MEDIDA — NaSA-GAME (Blender 4.x / 5.x)
# ---------------------------------------------------------------------
#  Cómo usar:
#   1. Abre Blender → pestaña "Scripting" → botón "Abrir" → elige este archivo.
#   2. Cambia las MEDIDAS de abajo (en metros).
#   3. Pulsa "Ejecutar script" (▶). Se crea la puerta y se exporta un .glb
#      en la misma carpeta que tu archivo .blend (o en tu carpeta personal).
#
#  A diferencia de escalar con la tecla S, aquí los postes y el borde del
#  marco mantienen su grosor: solo cambia el tamaño del hueco. Así una puerta
#  angosta o una gigante se ven bien proporcionadas.
#
#  En Godot también puedes ajustar el tamaño sin Blender: selecciona la puerta
#  y cambia "Tamaño (ajustable)" en el Inspector.
# =====================================================================
import bpy, bmesh, os, sys

# ---------------- MEDIDAS (cámbialas) ----------------
ANCHO = 1.7          # ancho total del marco (mínimo 0.9 m)
ALTO = 2.2           # alto total del marco (mínimo 1.3 m)
GROSOR = 0.30        # grosor del marco (pared)
TIPO = "normal"      # "normal" (azul) o "restringida" (roja con franjas de peligro)
DIRECCION = "arriba" # "arriba", "izquierda" o "derecha": hacia dónde se esconde la hoja
NOMBRE = "puerta_a_medida"
# -----------------------------------------------------

# Permite usarlo también desde la línea de comandos: blender -b -P archivo.py -- ANCHO ALTO GROSOR TIPO DIRECCION SALIDA
if "--" in sys.argv:
    a = sys.argv[sys.argv.index("--") + 1:]
    ANCHO, ALTO, GROSOR, TIPO, DIRECCION = float(a[0]), float(a[1]), float(a[2]), a[3], a[4]
    SALIDA = a[5]
    NOMBRE = os.path.splitext(os.path.basename(SALIDA))[0]
else:
    carpeta = bpy.path.abspath("//") or os.path.expanduser("~")
    SALIDA = os.path.join(carpeta, NOMBRE + ".glb")

ANCHO = max(ANCHO, 0.9)
ALTO = max(ALTO, 1.3)
POSTE = 0.23     # grosor de cada poste
CHAFLAN = 0.30   # esquina superior cortada
sc = bpy.context.scene

for o in [o for o in sc.objects if o.name.startswith(("MarcoPuerta", "HojaPuerta", "Franja", "Letrero"))]:
    bpy.data.objects.remove(o, do_unlink=True)

def material(nombre, color, metal=0.3, rugosidad=0.45, brillo=None):
    m = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rugosidad
    if brillo:
        b.inputs["Emission Color"].default_value = (*brillo, 1)
        b.inputs["Emission Strength"].default_value = 2.0
    return m

def prisma(nombre, contorno, grosor, y0, bisel, mat):
    """Extruye un contorno 2D (x, alto) con el grosor indicado."""
    me = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    cara = bm.faces.new([bm.verts.new((x, y0, z)) for x, z in contorno])
    bmesh.ops.recalc_face_normals(bm, faces=[cara])
    ext = bmesh.ops.extrude_face_region(bm, geom=[cara])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, grosor, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nombre, me)
    sc.collection.objects.link(ob)
    if bisel > 0:
        mod = ob.modifiers.new("bisel", "BEVEL")
        mod.width = bisel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    ob.data.materials.append(mat)
    return ob

def caja(nombre, tam, pos, mat, padre):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = nombre
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    o.parent = padre
    o.matrix_parent_inverse = padre.matrix_world.inverted()
    return o

mw = ANCHO / 2          # medio ancho exterior
xi = mw - POSTE         # medio ancho interior
H = ALTO
marco_pts = [(-mw, 0), (-mw, H - 0.35), (-mw + CHAFLAN, H), (mw - CHAFLAN, H), (mw, H - 0.35), (mw, 0),
             (mw - 0.4, 0), (mw - 0.4, 0.14), (xi, 0.32), (xi, H - 0.5), (xi - 0.22, H - 0.25),
             (-(xi - 0.22), H - 0.25), (-xi, H - 0.5), (-xi, 0.32), (-(mw - 0.4), 0.14), (-(mw - 0.4), 0)]
hoja_pts = [(-(xi + 0.01), 0), (-(xi + 0.01), H - 0.49), (-(xi - 0.21), H - 0.24),
            (xi - 0.21, H - 0.24), (xi + 0.01, H - 0.49), (xi + 0.01, 0)]

restringida = TIPO.lower().startswith("r")
color_marco = (0.55, 0.12, 0.10) if restringida else (0.36, 0.50, 0.58)
color_hoja = (0.55, 0.57, 0.62) if restringida else (0.68, 0.72, 0.88)
marco = prisma("MarcoPuerta", marco_pts, GROSOR, -GROSOR / 2, 0.035, material("Marco_" + TIPO, color_marco, 0.55, 0.4))
hoja = prisma("HojaPuerta", hoja_pts, 0.06, 0.02, 0.0, material("Hoja_" + TIPO, color_hoja, 0.2, 0.5))
extras = []
if restringida:
    amarillo = material("Peligro_amarillo", (0.95, 0.75, 0.05))
    negro = material("Peligro_negro", (0.03, 0.03, 0.03))
    n = max(3, int((2 * xi) / 0.17)) | 1
    ancho_franja = (2 * xi - 0.2) / n
    for i in range(n):
        x = -xi + 0.1 + ancho_franja * (i + 0.5)
        extras.append(caja(f"Franja{i}", (ancho_franja, 0.012, 0.16), (x, 0.008, H * 0.41), amarillo if i % 2 == 0 else negro, hoja))
    extras.append(caja("Letrero", (min(0.7, 2 * xi - 0.2), 0.012, 0.14), (0, -GROSOR / 2 - 0.01, H - 0.13),
                       material("Letrero_rojo", (0.6, 0.05, 0.05), brillo=(0.9, 0.1, 0.05)), marco))

# Animación "abrir" (30 fps, 0,8 s): la hoja se esconde arriba o de lado.
sc.render.fps = 30
recorrido = {"arriba": (0, 0, H - 0.26), "izquierda": (-(2 * xi + 0.05), 0, 0), "derecha": (2 * xi + 0.05, 0, 0)}
hoja.location = (0, 0, 0)
hoja.keyframe_insert("location", frame=1)
hoja.location = recorrido.get(DIRECCION, recorrido["arriba"])
hoja.keyframe_insert("location", frame=24)
hoja.animation_data.action.name = "abrir"
hoja.location = (0, 0, 0)
sc.frame_set(1)

bpy.ops.object.select_all(action="DESELECT")
for o in [marco, hoja] + extras:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=SALIDA, export_format="GLB", use_selection=True, export_apply=True,
                          export_animations=True, export_draco_mesh_compression_enable=False)
print(f"Puerta {ANCHO:.2f} x {ALTO:.2f} m ({TIPO}, se abre hacia {DIRECCION}) exportada en: {SALIDA}")
