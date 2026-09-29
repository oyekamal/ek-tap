import random, json, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W,H=392,696; R=sys.argv[1]; seed=int(sys.argv[2])
bg=Image.open("sprites/bg_space_v5.png").convert("RGBA").resize((W,H),Image.LANCZOS)
S=lambda n:Image.open(f"sprites_game5/{n}.png").convert("RGBA")
def put(c,n,cx,cy,h,rot=0):
    s=S(n); s=s.resize((int(s.width*h/s.height),h),Image.LANCZOS)
    if rot: s=s.rotate(rot,expand=True,resample=Image.BICUBIC)
    c.alpha_composite(s,(int(cx-s.width/2),int(cy-s.height/2)))
def ring(c,cx,cy,r,col,w=12):
    g=Image.new("RGBA",c.size,(0,0,0,0)); d=ImageDraw.Draw(g)
    for a in range(0,360,18): d.arc([cx-r,cy-r,cx+r,cy+r],a,a+12,fill=col,width=w)
    c.alpha_composite(g.filter(ImageFilter.GaussianBlur(9))); c.alpha_composite(g.filter(ImageFilter.GaussianBlur(3))); c.alpha_composite(g)
def grade(c):  # shared light: warm top-left, cool vignette bottom-right
    y,x=np.mgrid[0:H,0:W]; d=np.sqrt((x/W-0.15)**2+(y/H-0.1)**2)
    warm=np.clip(1-d*1.6,0,1)*70; cool=np.clip((d-0.7)*1.2,0,1)*80
    l=np.zeros((H,W,4),np.uint8); l[...,0]=255;l[...,1]=225;l[...,2]=190;l[...,3]=warm.astype(np.uint8)
    v=np.zeros((H,W,4),np.uint8); v[...,0]=20;v[...,1]=10;v[...,2]=70;v[...,3]=cool.astype(np.uint8)
    c.alpha_composite(Image.fromarray(l,"RGBA")); c.alpha_composite(Image.fromarray(v,"RGBA"))
def ui(c):
    L=Image.new("RGBA",c.size,(0,0,0,0)); d=ImageDraw.Draw(L)
    gl=Image.new("RGBA",c.size,(0,0,0,0)); ImageDraw.Draw(gl).rounded_rectangle([W//2-56,18,W//2+56,72],radius=27,fill=(120,200,255,150)); c.alpha_composite(gl.filter(ImageFilter.GaussianBlur(8)))
    d.rounded_rectangle([W//2-54,20,W//2+54,70],radius=25,fill=(30,24,84,255),outline=(120,220,255,255),width=4)
    d.ellipse([W-64,22,W-16,70],fill=(30,24,84,255),outline=(120,220,255,255),width=4)
    d.rectangle([W-47,37,W-42,55],fill=(255,248,240,255)); d.rectangle([W-38,37,W-33,55],fill=(255,248,240,255))
    f=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",30); d.text((W//2+2,26),"12",font=f,fill=(255,248,240,255))
    c.alpha_composite(L); put(c,"star",W//2-26,45,28)
scenes=[
 dict(pl=[("planet_ringo",140,470,230),("planet_mochi_moon",290,190,140)],rg=[(140,470,165,(120,240,255,235)),(290,190,105,(255,214,63,240))],pf=("puff_neutral",140,470-165-5,130,0),ex=[("star",215,330,52)]),
 dict(pl=[("planet_boba_bubble",245,480,210),("planet_frosty_pop",90,215,250)],rg=[(245,480,150,(120,240,255,235)),(90,215,118,(255,214,63,240))],pf=("puff_fly",180,345,140,-15),ex=[("golden_seed",305,300,54)]),
 dict(pl=[("planet_cactus_pal",125,500,210),("planet_ringo",285,270,170)],rg=[(125,500,150,(120,240,255,235)),(285,270,118,(255,214,63,240))],pf=("puff_happy",125,500-150-5,125,0),ex=[("star",215,420,52)]),
]
random.seed(seed); key={}
for i,sc in enumerate(scenes,1):
    c=bg.copy()
    for cx,cy,r,col in sc["rg"]: ring(c,cx,cy,r,col)
    for p in sc["pl"]: put(c,*p)
    for e in sc["ex"]: put(c,*e)
    put(c,*sc["pf"]); grade(c); ui(c)
    ours=c.convert("RGB"); ours.save(f"gauntlet/ours_{R}_{i}.png")
    bar=Image.open(f"bar/bar_{i}.jpg").convert("RGB").resize((W,H)); left=random.random()<0.5
    pair=Image.new("RGB",(W*2+30,H+20),"#888"); a,b=(ours,bar) if left else (bar,ours)
    pair.paste(a,(10,10)); pair.paste(b,(W+20,10)); pair.save(f"gauntlet/pair_{R}_{i}.png"); key[i]="A" if left else "B"
json.dump(key,open(f"gauntlet/key_{R}.json","w")); print(key)
