# Puesto de oxígeno para el minijuego 3D (Blender, bpy). Exporta oxygen_station.glb.
# Nodos que usa Godot: Needle (aguja, gira sobre el centro del manómetro), Valve (volante),
# Lamp (piloto de estado), Vent (salida de vapor), GaugeCenter (centro de la esfera).
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
D=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene

def tex(path):
    img=bpy.data.images.load(os.path.join(D,path)); return img
def mat(name,color=(0.8,0.8,0.8),metal=0.0,rough=0.5,image=None,emit=None,emit_strength=0.0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=(*color,1); b.inputs['Metallic'].default_value=metal; b.inputs['Roughness'].default_value=rough
    if image:
        t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=tex(image)
        m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
    if emit:
        b.inputs['Emission Color'].default_value=(*emit,1); b.inputs['Emission Strength'].default_value=emit_strength
    return m
M={
 'plate':mat('Panel',metal=0.35,rough=0.55,image='paint_dark.png'),
 'tank':mat('Tanque',metal=0.25,rough=0.4,image='paint_white.png'),
 'label':mat('Etiqueta',rough=0.6,image='tank_label.png'),
 'steel':mat('Acero',(0.62,0.64,0.68),1.0,0.32),
 'chrome':mat('Cromo',(0.86,0.87,0.9),1.0,0.12),
 'brass':mat('Laton',(0.78,0.58,0.3),1.0,0.28),
 'copper':mat('Cobre',(0.8,0.45,0.28),1.0,0.3),
 'red':mat('Volante',(0.72,0.07,0.06),0.2,0.35),
 'yellow':mat('Pasamanos',(0.95,0.68,0.12),0.3,0.4),
 'black':mat('Goma',(0.05,0.05,0.06),0.0,0.7),
 'dial':mat('Esfera',rough=0.55,image='dial.png'),
 'needle':mat('Aguja',(0.85,0.08,0.05),0.1,0.35),
 'lamp':mat('Piloto',(0.2,0.9,0.4),0.0,0.2,emit=(0.2,1.0,0.45),emit_strength=1.2),
 'box':mat('Caja',metal=0.4,rough=0.5,image='paint_white.png'),
 'led':mat('LedAzul',(0.2,0.6,1.0),0.0,0.2,emit=(0.2,0.6,1.0),emit_strength=1.5),
}
def finish(o,m,bevel=0.0,seg=2,smooth=True):
    o.data.materials.clear(); o.data.materials.append(m)
    if bevel>0:
        bv=o.modifiers.new('Bevel','BEVEL'); bv.width=bevel; bv.segments=seg; bv.limit_method='ANGLE'
    if smooth:
        for p in o.data.polygons: p.use_smooth=True
        try:
            o.modifiers.new('Smooth','WEIGHTED_NORMAL')
        except Exception: pass
    return o
def box_uv(o,scale=1.0):
    me=o.data
    if not me.uv_layers: me.uv_layers.new()
    uv=me.uv_layers.active.data
    for p in me.polygons:
        n=p.normal; ax=max(range(3),key=lambda i:abs(n[i]))
        for li in p.loop_indices:
            v=o.matrix_world@me.vertices[me.loops[li].vertex_index].co
            a,b=[(v.y,v.z),(v.x,v.z),(v.x,v.y)][ax]
            uv[li].uv=(a*scale,b*scale)
def only(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
def cube(name,size,loc,m,bevel=0.01,uvs=1.0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name
    o.scale=size; only(o); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); box_uv(o,uvs); return finish(o,m,bevel,3,False)
def cyl(name,r,depth,loc,m,axis='Z',verts=48,bevel=0.0,uvs=None):
    rot={'Z':(0,0,0),'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc,rotation=rot); o=bpy.context.object; o.name=name
    only(o); bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    if uvs: box_uv(o,uvs)
    return finish(o,m,bevel,2)
def sphere(name,r,loc,m,scale=(1,1,1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=r,location=loc); o=bpy.context.object; o.name=name
    o.scale=scale; only(o); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,m)
def torus(name,R,r,loc,m,axis='Y'):
    rot={'Z':(0,0,0),'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=R,minor_radius=r,major_segments=64,minor_segments=16,location=loc,rotation=rot)
    o=bpy.context.object; o.name=name; only(o); bpy.ops.object.transform_apply(location=False,rotation=True,scale=False); return finish(o,m)
def pipe(name,pts,r,m):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.bevel_depth=r; cu.bevel_resolution=6; cu.use_fill_caps=True
    sp=cu.splines.new('POLY'); sp.points.add(len(pts)-1)
    for i,p in enumerate(pts): sp.points[i].co=(*p,1)
    o=bpy.data.objects.new(name,cu); sc.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o.select_set(False)
    o=bpy.context.view_layer.objects.active
    for i in range(1,len(pts)-1): sphere(name+'_codo%d'%i,r*1.25,pts[i],m)
    return finish(o,m)
def empty(name,loc,parent=None):
    e=bpy.data.objects.new(name,None); e.location=loc; sc.collection.objects.link(e)
    if parent: e.parent=parent
    return e
def parent_to(objs,p):
    for o in objs:
        mw=o.matrix_world.copy(); o.parent=p; o.matrix_world=mw

# --- Placa de montaje (frente en y=0) ---
cube('Placa',(1.66,0.06,0.9),(0,0.03,0),M['plate'],0.015,1.5)
cube('Marco_sup',(1.70,0.05,0.04),(0,-0.005,0.45),M['steel'],0.008)
cube('Marco_inf',(1.70,0.05,0.04),(0,-0.005,-0.45),M['steel'],0.008)
for x in (-0.84,0.84): cube('Marco_lat',(0.04,0.05,0.94),(x,-0.005,0),M['steel'],0.008)
for x in (-0.8,-0.27,0.27,0.8):
    for z in (-0.41,0.41): cyl('Perno',0.013,0.014,(x,-0.035,z),M['chrome'],'Y',6,0.002)
# Pasamanos amarillo (como los de la ISS) arriba.
pipe('Pasamanos',[(-0.35,-0.03,0.38),(-0.35,-0.09,0.38),(0.35,-0.09,0.38),(0.35,-0.03,0.38)],0.014,M['yellow'])
for x in (-0.35,0.35): cyl('Pie_pasamanos',0.022,0.02,(x,-0.01,0.38),M['steel'],'Y',24)

# --- Tanque de O2 ---
TX,TY=-0.52,-0.2
cyl('Tanque',0.17,0.46,(TX,TY,-0.05),M['tank'],'Z',64,0.0,3.0)
sphere('Tanque_tapa_sup',0.17,(TX,TY,0.18),M['tank'],(1,1,0.55)); box_uv(bpy.context.object,3.0)
sphere('Tanque_tapa_inf',0.17,(TX,TY,-0.28),M['tank'],(1,1,0.55)); box_uv(bpy.context.object,3.0)
lab=cyl('Tanque_etiqueta',0.1715,0.19,(TX,TY,-0.04),M['label'],'Z',96)
me=lab.data
while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(); uv=me.uv_layers.active.data
for p in me.polygons:
    us=[]
    for li in p.loop_indices:
        v=me.vertices[me.loops[li].vertex_index].co
        us.append((math.atan2(v.x,-v.y)/(2*math.pi)+0.5,(v.z+0.095)/0.19))
    if max(u for u,_ in us)-min(u for u,_ in us)>0.5: us=[(u if u>0.5 else u+1,w) for u,w in us]
    for li,(u,w) in zip(p.loop_indices,us): uv[li].uv=(u,w)
for z in (0.1,-0.2):
    cyl('Abrazadera',0.178,0.028,(TX,TY,z),M['steel'],'Z',64,0.004)
    cube('Soporte',(0.05,0.07,0.03),(TX,-0.035,z),M['steel'],0.006)
    cyl('Tornillo',0.008,0.06,(TX,-0.06,z),M['chrome'],'Y',8)
cyl('Cuello',0.045,0.06,(TX,TY,0.29),M['brass'],'Z',32,0.004)
cyl('Valvula_tanque',0.03,0.05,(TX,TY,0.345),M['brass'],'Z',32)
cyl('Tuerca',0.04,0.025,(TX,TY,0.37),M['chrome'],'Z',6,0.003)

# --- Tubería del tanque al manómetro ---
GX,GZ=0.16,-0.03
pipe('Tuberia',[(TX,TY,0.37),(TX,TY,0.43),(TX,-0.075,0.43),(GX,-0.075,0.43),(GX,-0.075,0.3)],0.02,M['copper'])
cyl('Racor_manometro',0.035,0.05,(GX,-0.075,0.29),M['brass'],'Z',6,0.004)

# --- Válvula de purga con volante rojo (Valve gira sobre su eje frontal) ---
VX=-0.2
cyl('Cuerpo_valvula',0.05,0.12,(VX,-0.075,0.43),M['brass'],'X',32,0.006)
cyl('Vastago',0.012,0.12,(VX,-0.15,0.43),M['steel'],'Y',16)
valve=empty('Valve',(VX,-0.2,0.43))
parts=[torus('Volante_aro',0.085,0.013,(VX,-0.2,0.43),M['red'],'Y'),
       cyl('Volante_cubo',0.022,0.03,(VX,-0.2,0.43),M['red'],'Y',24,0.004)]
for k in range(4):
    a=k*math.pi/2+math.pi/4
    o=cyl('Volante_radio',0.008,0.085,(VX+0.0425*math.cos(a),-0.2,0.43+0.0425*math.sin(a)),M['red'],'Z',12)
    o.data.transform(Matrix.Rotation(-a+math.pi/2,4,'Y')); parts.append(o)
parent_to(parts,valve)
empty('Vent',(VX+0.06,-0.075,0.47))

# --- Manómetro ---
cyl('Caja_manometro',0.3,0.1,(GX,-0.05,GZ),M['steel'],'Y',96,0.01)
torus('Bisel',0.282,0.022,(GX,-0.1,GZ),M['chrome'],'Y')
bpy.ops.mesh.primitive_circle_add(vertices=128,radius=0.268,fill_type='NGON',location=(GX,-0.102,GZ),rotation=(math.pi/2,0,0))
face=bpy.context.object; face.name='Esfera'; only(face); bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
me=face.data
while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(); uv=me.uv_layers.active.data
for p in me.polygons:
    for li in p.loop_indices:
        v=me.vertices[me.loops[li].vertex_index].co
        uv[li].uv=(0.5+v.x/(2*0.268),0.5+v.z/(2*0.268))
finish(face,M['dial'],smooth=False)
gc=empty('GaugeCenter',(GX,-0.104,GZ))
# Aguja: pivota en el centro y apunta hacia arriba (+Z) en reposo.
bm=bmesh.new()
pts=[(-0.012,-0.05),(0.012,-0.05),(0.006,0.0),(0.0025,0.225),(-0.0025,0.225),(-0.006,0.0)]
top=[bm.verts.new((x,-0.003,z)) for x,z in pts]; bot=[bm.verts.new((x,0.003,z)) for x,z in pts]
bm.faces.new(top); bm.faces.new(list(reversed(bot)))
for i in range(len(pts)): j=(i+1)%len(pts); bm.faces.new([top[i],top[j],bot[j],bot[i]])
nm=bpy.data.meshes.new('Needle'); bm.to_mesh(nm); bm.free()
needle=bpy.data.objects.new('Needle',nm); sc.collection.objects.link(needle); needle.location=(GX,-0.112,GZ)
finish(needle,M['needle'],smooth=False)
cap=cyl('Tapa_aguja',0.024,0.014,(GX,-0.12,GZ),M['chrome'],'Y',32,0.004)
parent_to([cap],needle)

# --- Piloto de estado y caja de control ---
LX,LZ=0.62,0.27
cyl('Base_piloto',0.05,0.03,(LX,-0.015,LZ),M['steel'],'Y',32,0.004)
lamp=sphere('Lamp',0.04,(LX,-0.035,LZ),M['lamp'],(1,0.9,1))
for r in (0.042,0.046): torus('Rejilla',r,0.004,(LX,-0.05,LZ),M['steel'],'Z')
cube('Caja_control',(0.3,0.08,0.34),(0.62,-0.04,-0.17),M['box'],0.012,3.0)
cube('Placa_caja',(0.24,0.006,0.06),(0.62,-0.083,-0.04),M['black'],0.002)
for i,x in enumerate((0.55,0.62,0.69)):
    cyl('Base_interruptor',0.016,0.012,(x,-0.086,-0.15),M['chrome'],'Y',24)
    o=cyl('Interruptor',0.006,0.05,(x,-0.1,-0.135),M['steel'],'Z',12); o.data.transform(Matrix.Rotation(math.radians(-35),4,'X'))
    sphere('Led',0.009,(x,-0.083,-0.24),M['led'] if i!=1 else M['lamp'])
cyl('Manguera_caja',0.012,0.2,(0.42,-0.04,-0.29),M['black'],'X',16)

# Origen del modelo: centro de la placa al frente.
bpy.ops.export_scene.gltf(filepath=os.path.join(D,'oxygen_station.glb'),export_format='GLB',export_apply=True,
    export_image_format='AUTO',export_yup=True)
print('EXPORT OK', len(bpy.data.objects))
