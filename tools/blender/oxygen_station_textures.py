# Texturas del puesto de oxígeno: esfera del manómetro, etiqueta del tanque y metal pintado con desgaste.
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
B='/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'
S='/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf'

# 1) Esfera: 0..100 en un arco de 270° (de -135° a +135°, medido desde arriba en sentido horario).
N=1024; c=N/2; R=N/2
im=Image.new('RGB',(N,N),(232,233,226)); d=ImageDraw.Draw(im)
for r in range(int(R),0,-2):  # leve viñeta
    t=r/R; g=int(236-18*t**3); d.ellipse([c-r,c-r,c+r,c+r],fill=(g,g,g-6))
def pt(a,r): return (c+r*math.sin(a), c-r*math.cos(a))
for i in range(0,101):
    a=math.radians(-135+270*i/100)
    if i%10==0: r0,r1,w=0.68*R,0.80*R,9
    elif i%5==0: r0,r1,w=0.72*R,0.80*R,5
    else: r0,r1,w=0.75*R,0.80*R,3
    d.line([pt(a,r0),pt(a,r1)],fill=(25,28,32),width=w)
d.arc([c-0.80*R,c-0.80*R,c+0.80*R,c+0.80*R],start=-225,end=45,fill=(25,28,32),width=4)
f=ImageFont.truetype(B,54)
for i in range(0,101,10):
    a=math.radians(-135+270*i/100); x,y=pt(a,0.56*R)
    d.text((x,y),str(i),font=f,fill=(25,28,32),anchor='mm')
def o2(d,x,y,size,fill):
    fo=ImageFont.truetype(B,size); fs=ImageFont.truetype(B,int(size*0.55))
    wo=d.textlength('O',font=fo); ws=d.textlength('2',font=fs); x0=x-(wo+ws)/2
    d.text((x0,y),'O',font=fo,fill=fill,anchor='lm'); d.text((x0+wo+2,y+size*0.28),'2',font=fs,fill=fill,anchor='lm')
o2(d,c,c+0.30*R,96,(20,90,160))
d.text((c,c+0.47*R),'%',font=ImageFont.truetype(S,46),fill=(60,64,70),anchor='mm')
d.text((c,c-0.30*R),'NaSA-GAME',font=ImageFont.truetype(S,30),fill=(110,114,120),anchor='mm')
im.save('dial.png')

# 2) Etiqueta del tanque (se enrolla en un cilindro; el centro de la imagen queda al frente).
W,H=2048,384
im=Image.new('RGB',(W,H),(236,238,232)); d=ImageDraw.Draw(im)
d.rectangle([0,0,W,46],fill=(20,90,160)); d.rectangle([0,H-46,W,H],fill=(20,90,160))
for cx in (W*0.5, 0, W):
    o2(d,cx,H/2,190,(20,90,160))
for cx in (W*0.25, W*0.75):
    for k in range(-6,7):  # franjas de seguridad
        x=cx+k*34; d.polygon([(x,60),(x+18,60),(x-2,H-60),(x-20,H-60)],fill=(240,190,40) if k%2 else (30,30,30))
im.save('tank_label.png')

# 3) Metal pintado con desgaste (se repite): base clara con ruido, rayones y bordes gastados.
def painted(name, base, n_scr):
    W=1024; im=Image.new('RGB',(W,W),base); px=im.load()
    noise=Image.effect_noise((W,W),18).filter(ImageFilter.GaussianBlur(1.2))
    nz=noise.load()
    for y in range(W):
        for x in range(W):
            v=(nz[x,y]-128)//6
            px[x,y]=tuple(max(0,min(255,ch+v)) for ch in base)
    d=ImageDraw.Draw(im)
    for _ in range(n_scr):
        x=random.randint(0,W); y=random.randint(0,W); l=random.randint(10,70); a=random.uniform(0,math.pi)
        col=tuple(min(255,ch+38) for ch in base)
        d.line([(x,y),(x+l*math.cos(a),y+l*math.sin(a))],fill=col,width=1)
    for _ in range(40):
        x=random.randint(0,W); y=random.randint(0,W); r=random.randint(2,9)
        d.ellipse([x-r,y-r,x+r,y+r],fill=tuple(max(0,ch-30) for ch in base))
    im=im.filter(ImageFilter.GaussianBlur(0.6)); im.save(name)
painted('paint_white.png',(214,216,212),260)
painted('paint_dark.png',(58,64,72),220)
print('ok')
