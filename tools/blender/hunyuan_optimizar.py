# Optimiza los modelos de Hunyuan 3D para la cabina: menos caras, texturas más pequeñas,
# origen en el centro y tamaño real (metros) según dónde van en la cabina del Apolo 8.
import bpy, bmesh, sys, os, mathutils
a=sys.argv[sys.argv.index('--')+1:]
SRC,OUT,WIDTH,TRIS,TEX=a[0],a[1],float(a[2]),int(a[3]),int(a[4])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in ms: o.select_set(True)
bpy.context.view_layer.objects.active=ms[0]
if len(ms)>1: bpy.ops.object.join()
o=bpy.context.view_layer.objects.active
o.parent=None
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
tris=sum(len(p.vertices)-2 for p in o.data.polygons)
if tris>TRIS:
    m=o.modifiers.new('dec','DECIMATE'); m.ratio=TRIS/tris; m.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier='dec')
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS'); o.location=(0,0,0)
s=WIDTH/o.dimensions.x; o.scale=(s,s,s); bpy.ops.object.transform_apply(scale=True)
# textura base y normal más pequeñas; metal/rugosidad aún más
for img in bpy.data.images:
    if img.size[0]>TEX:
        t=TEX if 'metallic' not in img.name else max(256,TEX//2)
        img.scale(t,t)
for mat in bpy.data.materials:
    if mat.use_nodes:
        b=mat.node_tree.nodes.get('Principled BSDF')
        if b and 'Specular IOR Level' in b.inputs: b.inputs['Specular IOR Level'].default_value=0.3
base=os.path.splitext(os.path.basename(OUT))[0]
for img in bpy.data.images:
    n=img.name
    img.name=base+('_normal' if 'normal' in n else '_orm' if 'metallic' in n else '_color')
o.name=os.path.splitext(os.path.basename(OUT))[0]
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=False,export_image_format='AUTO',export_apply=True)
print('DONE',o.name,'tris',sum(len(p.vertices)-2 for p in o.data.polygons),'dims',[round(v,3) for v in o.dimensions])
