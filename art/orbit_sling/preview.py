import sys
from PIL import Image
names=sys.argv[2:]; out=sys.argv[1]; ims=[Image.open(f"sprites/{n}.png") for n in names]
H=300; ims=[i.resize((int(i.width*H/i.height),H)) for i in ims]
W=sum(i.width for i in ims)+20*(len(ims)+1); c=Image.new("RGBA",(W,H+40),"#14122B"); x=20
for i in ims: c.alpha_composite(i,(x,20)); x+=i.width+20
c.save(out)
