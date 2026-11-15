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
  'steel':mat('Acero',(0.62,0.64,0.68),1.0,0.32),
 'chrome':mat('Cromo',(0.86,0.87,0.9),1.0,0.12),
 'brass':mat('Laton',(0.78,0.58,0.3),1.0,0.28),
 'copper':mat('Cobre',(0.8,0.45,0.28),1.0,0.3),
 'red':mat('Volante',(0.72,0.07,0.06),0.2,0.35),
 'yellow':mat('Pasamanos',(0.95,0.68,0.12),0.3,0.4),
 'black':mat('Goma',(0.05,0.05,0.06),0.0,0.7),
  'needle':mat('Aguja',(0.85,0.08,0.05),0.1,0.35),
 'lamp':mat('Piloto',(0.2,0.9,0.4),0.0,0.2,emit=(0.2,1.0,0.45),emit_strength=1.2),
 'mid':mat('PanelMedio',metal=0.35,rough=0.5,image='paint_mid.png'),
 'warn':mat('Aviso',rough=0.6,image='warning.png'),
 'socket':mat('Toma',(0.16,0.17,0.19),0.3,0.5),
 'plug':mat('Enchufe',(0.85,0.85,0.85),0.0,0.45),
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


# Gabinete de distribución eléctrica (frente en y=0, X a la derecha, Z arriba).
cube('Gabinete',(1.34,0.2,0.94),(0,0.1,0),M['plate'],0.02,1.5)
cube('Panel_interior',(1.2,0.02,0.8),(0,-0.008,0),M['mid'],0.006,2.0)
for z in (0.455,-0.455): cube('Marco_h',(1.38,0.05,0.04),(0,-0.012,z),M['steel'],0.008)
for x in (-0.675,0.675): cube('Marco_v',(0.04,0.05,0.95),(x,-0.012,0),M['steel'],0.008)
for x in (-0.62,0.62):
    for z in (-0.42,0.42): cyl('Perno',0.013,0.014,(x,-0.04,z),M['chrome'],'Y',6,0.002)
# Bandeja de cables arriba a la izquierda con 4 pasacables (Outlet_i: de ahí salen los cables).
cube('Bandeja',(0.62,0.12,0.09),(-0.27,-0.07,0.33),M['steel'],0.01)
XS=[-0.5,-0.36,-0.22,-0.08]
for i,x in enumerate(XS):
    cyl('Pasacables',0.026,0.03,(x,-0.09,0.28),M['black'],'Z',24,0.004)
    empty('Outlet_%d'%i,(x,-0.09,0.265))
# Enchufes colgando (Plug_i). Su punta mira hacia abajo; el cable entra por arriba (CableEnd_i).
RZ=[0.02,-0.06,0.0,-0.09]
for i,x in enumerate(XS):
    p=empty('Plug_%d'%i,(x,-0.12,RZ[i]))
    parts=[cyl('PlugBody_%d'%i,0.03,0.09,(x,-0.12,RZ[i]),M['plug'],'Z',32,0.006)]
    for dz in (-0.02,0.0,0.02): parts.append(torus('Agarre',0.031,0.004,(x,-0.12,RZ[i]+dz),M['black'],'Z'))
    parts.append(cyl('Cuello_enchufe',0.016,0.03,(x,-0.12,RZ[i]+0.058),M['black'],'Z',16))
    for dx in (-0.01,0.01): parts.append(cyl('Pin',0.004,0.03,(x+dx,-0.12,RZ[i]-0.058),M['brass'],'Z',8))
    parent_to(parts,p)
    empty('CableEnd_%d'%i,(0,0,0.073),p)
# Tomas a la derecha (Socket_i en la boca) con su piloto (SocketLed_i).
SZ=[0.24,0.09,-0.06,-0.21]
for i,z in enumerate(SZ):
    cube('Placa_toma',(0.14,0.02,0.12),(0.4,-0.025,z),M['steel'],0.008)
    cyl('Toma',0.036,0.03,(0.4,-0.045,z),M['socket'],'Y',32,0.004)
    cyl('Agujero',0.022,0.01,(0.4,-0.061,z),M['black'],'Y',24)
    torus('Aro_toma',0.04,0.005,(0.4,-0.06,z),M['chrome'],'Y')
    empty('Socket_%d'%i,(0.4,-0.062,z))
    cyl('Base_led',0.016,0.012,(0.53,-0.03,z),M['chrome'],'Y',24)
    sphere('SocketLed_%d'%i,0.012,(0.53,-0.04,z),M['plug'])
    empty('SocketLabel_%d'%i,(0.29,-0.03,z))
# Interruptor general abajo (Lever gira hacia arriba al terminar) y aviso de peligro.
cube('Base_palanca',(0.16,0.05,0.14),(0.12,-0.035,-0.31),M['steel'],0.01)
lev=empty('Lever',(0.12,-0.06,-0.31))
lp=[cyl('Palanca',0.012,0.12,(0.12,-0.06,-0.37),M['steel'],'Z',16),
    sphere('Pomo',0.026,(0.12,-0.06,-0.43),M['red'],(1,1,1.2))]
parent_to(lp,lev)
cube('Aviso',(0.26,0.004,0.13),(-0.3,-0.02,-0.31),M['warn'],0.0)
mw=bpy.data.objects['Aviso']; me=mw.data
while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(); uv=me.uv_layers.active.data
for p in me.polygons:
    for li in p.loop_indices:
        v=me.vertices[me.loops[li].vertex_index].co
        uv[li].uv=(v.x/0.26+0.5,v.z/0.13+0.5)
for k in range(5): cube('Rejilla',(0.18,0.012,0.012),(-0.3+0.0,-0.02,0.36-0.0+k*0.0) if False else (0.45,-0.02,-0.27-k*0.022),M['black'],0.003)
sphere('MainLed',0.02,(0.25,-0.03,-0.31),M['plug'])
bpy.ops.export_scene.gltf(filepath=os.path.join(D,'power_panel.glb'),export_format='GLB',export_apply=True,export_image_format='AUTO',export_yup=True)
print('EXPORT OK',len(bpy.data.objects))
