import numpy as np
from PIL import Image
rng=np.random.default_rng(5)
N=128; bw,bh=16,8
img=np.zeros((N,N,3))
base=np.array([158,150,132.0])
for r in range(N//bh):
    off=(bw//2)*(r%2)
    for c in range(-1,N//bw+1):
        x0=c*bw+off; tone=base+rng.uniform(-9,9)
        for y in range(r*bh,(r+1)*bh):
            for x in range(x0,x0+bw):
                xx=x%N; ly=y-r*bh; lx=x-x0
                col=tone.copy()
                if ly==0 or lx==0: col=np.array([108,98,80.0])          # joint
                elif ly==bh-1 or lx==bw-1: col=tone*0.84                # shaded lower/right lip
                elif ly==1 or lx==1: col=tone*1.07                      # lit upper/left lip
                img[y,xx]=col
Image.fromarray(np.clip(img,0,255).astype(np.uint8)).save('paving.png')
