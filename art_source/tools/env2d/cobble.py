import numpy as np
from PIL import Image
rng=np.random.default_rng(11)
N=128; cell=8
g=N//cell+1
pts=[]
cs=N/ (N//cell)
k=N//cell
for i in range(k):
    for j in range(k):
        pts.append(((i+0.5+rng.uniform(-0.3,0.3))*cs,(j+0.5+rng.uniform(-0.3,0.3))*cs*1.0))
pts=np.array(pts)
yy,xx=np.mgrid[0:N,0:N]
best=np.full((N,N),1e9); second=np.full((N,N),1e9); idx=np.zeros((N,N),int)
for n,(px,py) in enumerate(pts):
    for ox in (-N,0,N):
        for oy in (-N,0,N):
            dx=xx-(px+ox); dy=(yy-(py+oy))*1.15
            d=np.sqrt(dx*dx+dy*dy)
            m=d<best
            second=np.where(m,best,np.minimum(second,d)); idx=np.where(m,n,idx); best=np.where(m,d,best)
edge=second-best   # distance to cell border
base=np.array([148,142,126],float)
shade=rng.uniform(-10,10,len(pts))
img=np.zeros((N,N,3))
for n in range(len(pts)):
    img[idx==n]=base+shade[n]+np.array([0,0,-2])
gap=edge<1.2
outline=(edge>=1.2)&(edge<2.1)
img[outline]=img[outline]*0.80
# highlight: upper-left inside of each stone
cy=pts[idx][:, :] if False else None
px=pts[:,0][idx]; py=pts[:,1][idx]
dxs=((xx-px+N/2)%N)-N/2; dys=((yy-py+N/2)%N)-N/2
hl=(edge>=2.1)&(edge<3.0)&(dxs+dys< -1.5)
img[hl]=img[hl]*1.10
img[gap]=np.array([104,92,72])
Image.fromarray(np.clip(img,0,255).astype(np.uint8)).save('cobble.png')
t=Image.open('cobble.png'); W=Image.new('RGB',(256,256))
for i in range(2):
    for j in range(2): W.paste(t,(i*128,j*128))
W.resize((768,768),Image.NEAREST).save('cobble_prev.png')
