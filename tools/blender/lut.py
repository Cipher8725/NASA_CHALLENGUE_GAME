import bpy, bmesh, sys, os, math
OUT=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,r=0.6,m=0.3):
    x=bpy.data.materials.new(n); x.use_nodes=True; b=x.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=(*c,1); b.inputs['Roughness'].default_value=r; b.inputs['Metallic'].default_value=m; return x
RED=mat('torre_roja',(0.55,0.08,0.05)); GRAY=mat('plataforma_gris',(0.38,0.38,0.37),0.85,0.05); DARK=mat('hueco',(0.05,0.05,0.05),0.9,0)
parts=[]
def box(cx,cy,z0,sx,sy,sz,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(cx,cy,z0+sz/2)); o=bpy.context.object; o.scale=(sx,sy,sz)
    bpy.ops.object.transform_apply(scale=True); o.data.materials.append(m); parts.append(o); return o
def beam(p,q,t,m):
    # viga entre dos puntos
    import mathutils
    a=mathutils.Vector(p); b=mathutils.Vector(q); d=b-a; L=d.length
    bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2); o=bpy.context.object
    o.scale=(t,t,L); o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True); o.data.materials.append(m); parts.append(o)
# Plataforma de lanzamiento (Mobile Launcher Apollo: ~49 x 41 x 7.6 m), cohete en el centro (0,0)
box(0,0,-7.6,49,41,7.6,GRAY)
box(0,0,-0.02,14,14,0.05,DARK)   # hueco de las llamas bajo los F-1
# Torre umbilical (LUT): ~12 x 12 m, ~122 m de alto, junto al cohete en +Y
TX,TY,W,H=0,22,12,122
for sx in (-1,1):
    for sy in (-1,1):
        box(TX+sx*W/2,TY+sy*W/2,0,1.2,1.2,H,RED)
for z in range(0,H+1,8):
    for (a,b) in [((-1,-1),(1,-1)),((1,-1),(1,1)),((1,1),(-1,1)),((-1,1),(-1,-1))]:
        beam((TX+a[0]*W/2,TY+a[1]*W/2,z),(TX+b[0]*W/2,TY+b[1]*W/2,z),0.6,RED)
    if z+8<=H:
        for (a,b) in [((-1,-1),(1,-1)),((1,1),(-1,1)),((-1,-1),(-1,1)),((1,-1),(1,1))]:
            beam((TX+a[0]*W/2,TY+a[1]*W/2,z),(TX+b[0]*W/2,TY+b[1]*W/2,z+8),0.45,RED)
# Grúa arriba
box(TX,TY-3,H,3,20,2,RED)
# Brazos de servicio (el de acceso de la tripulación llega a la cápsula, ~98 m)
for z in [20,36,52,68,84]:
    box(TX,(TY-W/2+5.5)/2+(-1),z,3,TY-W/2-5.5+2,2,RED)
box(TX,(TY-W/2+4.2)/2,97,2.6,TY-W/2-4.2,2.6,RED)
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
o=bpy.context.object; o.name='PlataformaLanzamiento'
print('TRIS',sum(len(p.vertices)-2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'plataforma_torre_lanzamiento.glb'),use_selection=True,export_format='GLB',export_apply=True)
