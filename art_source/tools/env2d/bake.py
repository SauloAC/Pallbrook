import json, sys, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
A='/mnt/user-data/uploads/Assets/'
d=json.load(open('/mnt/user-data/uploads/Pallbrook/art_source/_roads.json'))
PX=0.04375; S50=0.76604444
x0,x1,z0,z1=d['bounds']
W=int(round((x1-x0)/PX)); H=int(round((z1-z0)*S50/PX))
def raster(polys):
    im=Image.new('L',(W,H),0); dr=ImageDraw.Draw(im)
    for p in polys:
        dr.polygon([((x-x0)/PX,(z-z0)*S50/PX) for x,z in p],fill=255)
    return np.array(im)>0
rng=np.random.default_rng(7)
def vnoise(scale):
    gw,gh=W//scale+3,H//scale+3
    g=rng.random((gh,gw))
    im=Image.fromarray((g*255).astype(np.uint8)).resize((gw*scale,gh*scale),Image.BICUBIC)
    return np.array(im)[:H,:W]/255.0-0.5
n=vnoise(16)*8.0+vnoise(6)*3.5+vnoise(2)*1.5
def soft(mask, grow=0.0):
    # close the small gaps between road pieces, round the corners (blur and re-cut), then wobble
    # the edge like a hand-drawn path
    mask=ndimage.binary_closing(mask, structure=np.ones((3,3)), iterations=14)
    mask=ndimage.gaussian_filter(mask.astype(float), 7.0)>0.5
    inside=ndimage.distance_transform_edt(mask); outside=ndimage.distance_transform_edt(~mask)
    return (inside-outside)+n+grow>0
stone=soft(raster(d['stone'])); dirt=soft(raster(d['dirt']))&~stone
# The paved squares (the plaza around the well, the tavern's patio): stone slabs, straight edges
props=json.load(open('/mnt/user-data/uploads/Pallbrook/art_source/_props.json'))
slabs=[]
for r in props:
    if r[0].startswith('Floor_Brick') and r[7] in ('Plaza','Tavern'):
        x,z=r[2],r[4]; hx,hz=r[5][0]/2,r[5][1]/2
        slabs.append([[x-hx,z-hz],[x+hx,z-hz],[x+hx,z+hz],[x-hx,z+hz]])
slab=ndimage.binary_closing(raster(slabs),structure=np.ones((3,3)),iterations=3)
g=Image.open(A+'Pixel Art Top Down - Village v1.0.11/Texture/TX Tileset Grass.png').convert('RGB')
gA=np.array(g.crop((384,0,512,128))); gB=np.array(g.crop((384,160,512,288)))
dt=np.array(Image.open(A+'Pixel Art Top Down - Village v1.0.11/Texture/TX Tileset Dirt.png').convert('RGB').crop((0,0,128,128)))
st=np.array(Image.open('cobble.png').convert('RGB'))
def tile(t): return np.tile(t,(H//128+1,W//128+1,1))[:H,:W].astype(float)
grass=tile(gA); fl=tile(gB)
cells=rng.random((H//128+1,W//128+1))<0.2
cm=np.kron(cells,np.ones((128,128),bool))[:H,:W]; grass[cm]=fl[cm]
out=grass.copy()
D=tile(dt); out[dirt]=D[dirt]
St=tile(st)
# a dirt margin around the stone roads, as worn ground (the stones sit in the earth)
margin=soft(raster(d['stone']),grow=3.0)&~stone&~dirt
out[margin]=D[margin]
out[stone]=St[stone]
Sl=tile(np.array(Image.open('paving.png').convert('RGB')))
out[slab]=Sl[slab]
# Ada's fields: tilled soil in furrows (the pack's dirt, darker and richer), straight edges
FIELDS=[(29.4,-44.6,33.4,-37.4),(35.2,-44.6,42.4,-38.0)]   # FarmField_W, FarmField_E (x0, z0, x1, z1)
field=raster([[[a,b],[c,b],[c,d],[a,d]] for a,b,c,d in FIELDS])
# ragged edges: the grass grows a little over the soil (Nature2D adds tufts along them)
fin=ndimage.distance_transform_edt(field)
field=field&(fin+n*0.45>2.5)
rows=np.arange(H)[:,None]%6
soil=D*np.array([0.70,0.62,0.55])
soil=np.where((rows==0)[...,None],soil*0.72,soil)
soil=np.where((rows==1)[...,None],np.minimum(soil*1.18,255),soil)
out[field]=soil[field]
ground=dirt|stone|margin|slab|field
rim=ndimage.binary_dilation(ground)&~ground
out[rim]=out[rim]*np.array([0.76,0.80,0.66])
grass_m=~ground
lip=np.zeros_like(ground); lip[1:]|=grass_m[:-1]; lip[2:]|=grass_m[:-2]
sh=ground&lip; out[sh]=out[sh]*0.82
# The riverbanks (the river runs between x -15 and -10): the grass edge overhangs the water,
# a dark line and a shadowed lip, as the pack draws its cliff tops
for bank,side in ((-15.0,-1),(-10.0,1)):
    c=(bank-x0)/PX
    cols=np.arange(W)
    d=(cols-c)*side   # pixels from the water's edge, inland
    wob=np.round(n[:, :1]*0.0)   # (straight: the water's edge is a straight mesh)
    edge=(d>=0)&(d<1); lipc=(d>=1)&(d<3)
    out[:,edge]=out[:,edge]*0.45
    out[:,lipc]=out[:,lipc]*0.78
img=Image.fromarray(np.clip(out,0,255).astype(np.uint8))
img.save('ground_baked.png', optimize=True)
cx,cz=float(sys.argv[1]),float(sys.argv[2])
u=int((cx-x0)/PX); v=int((cz-z0)*S50/PX)
img.crop((u-400,v-250,u+400,v+250)).resize((1600,1000),Image.NEAREST).save('crop.png')
print(W,H)
