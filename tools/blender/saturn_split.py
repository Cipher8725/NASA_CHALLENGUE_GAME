import bpy, bmesh, mathutils, json, sys, os
OUT=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/work/sv/sv_in.glb')
sc=bpy.context.scene
objs=[o for o in sc.objects if o.type=='MESH']
names=[o.name for o in objs]
# aplicar transformaciones
for o in objs:
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    o.parent=None
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in list(sc.objects):
    if o.type!='MESH': bpy.data.objects.remove(o)
body=bpy.data.objects['pCylinder1']
cx=sum(v.co.x for v in body.data.vertices)/len(body.data.vertices); cy=sum(v.co.y for v in body.data.vertices)/len(body.data.vertices)
objs=[bpy.data.objects[n] for n in names]
zmin=min(v.co.z for o in objs for v in o.data.vertices)
CUTS=[('s_ic',-99,4.8),('s_ii',4.8,7.75),('s_ivb',7.75,10.26),('adaptador_sla',10.26,11.01),('csm',11.01,11.66),('torre_escape',11.66,99)]
# cortar el cuerpo con planos
bm=bmesh.new(); bm.from_mesh(body.data)
for _,_,z in CUTS[:-1]:
    geom=bm.verts[:]+bm.edges[:]+bm.faces[:]
    bmesh.ops.bisect_plane(bm,geom=geom,plane_co=(0,0,z),plane_no=(0,0,1))
bm.to_mesh(body.data); bm.free()
groups={n:[] for n,_,_ in CUTS}
def which(z):
    for n,a,b in CUTS:
        if a<=z<b: return n
    return CUTS[-1][0]
# separar caras del cuerpo por altura
for n,a,b in CUTS:
    cp=body.copy(); cp.data=body.data.copy(); sc.collection.objects.link(cp)
    bm=bmesh.new(); bm.from_mesh(cp.data)
    kill=[f for f in bm.faces if not (a<=f.calc_center_median().z<b)]
    bmesh.ops.delete(bm,geom=kill,context='FACES'); bm.to_mesh(cp.data); bm.free()
    cp.name='body_'+n; groups[n].append(cp)
bpy.data.objects.remove(body)
for nm in names:
    if nm=='pCylinder1': continue
    o=bpy.data.objects[nm]
    zc=sum(v.co.z for v in o.data.vertices)/len(o.data.vertices); groups[which(zc)].append(o)
S=110.6/(max(v.co.z for o in sc.objects for v in o.data.vertices)-zmin)
info={'escala':S,'piezas':{}}
for n,lst in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in lst: o.select_set(True)
    bpy.context.view_layer.objects.active=lst[0]
    if len(lst)>1: bpy.ops.object.join()
    o=bpy.context.view_layer.objects.active; o.name=n
    for v in o.data.vertices: v.co=mathutils.Vector(((v.co.x-cx)*S,(v.co.y-cy)*S,(v.co.z-zmin)*S))
    o.data.update()
    zs=[v.co.z for v in o.data.vertices]
    info['piezas'][n]={'base_m':round(min(zs),2),'tope_m':round(max(zs),2),'tris':sum(len(p.vertices)-2 for p in o.data.polygons)}
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,f'saturno_v_{n}.glb'),use_selection=True,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88,export_apply=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'saturno_v_completo.glb'),use_selection=True,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88)
json.dump(info,open(os.path.join(OUT,'saturno_v.json'),'w'),indent=1)
print('INFO',json.dumps(info))
