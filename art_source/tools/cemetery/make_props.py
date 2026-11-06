# The cemetery's painted pieces: the Cainos "Basic" pack's graves, statue, pillars and bench as they are,
# and the KayKit Halloween Bits pieces it lacks (crypt, iron fence, arch, dead trees, lanterns, the road's
# gate), rendered from 3D in the town's camera and coloured with the Cainos ramps (cainosify.py).
import json, sys, os
from PIL import Image
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
SP = "/tmp/claude-0/-home-claude/7c66f129-d9b2-531b-9641-c5690e385c15/scratchpad/"
OUT = SP + "full/assets/environment2d/props/"
basic = Image.open(SP + "packs/Pixel Art Top Down - Basic v1.2.3/Texture/TX Props.png").convert("RGBA")
B = json.load(open(SP + "cem/basic_objs.json"))
def crop(i):
    c = basic.crop(B[str(i)])
    return c.crop(c.getbbox())
for name, i in [("cem_rip", 29), ("cem_cross", 34), ("cem_tall", 1), ("cem_broken", 24), ("cem_low", 30),
                ("cem_tomb", 19), ("cem_monolith", 13), ("cem_statue", 5), ("cem_pillar", 23), ("cem_bench", 4),
                ("cem_sarcophagus", 12)]:
    crop(i).save(OUT + name + ".png")
for name in ["crypt", "fence_n", "fence_s", "fence_side", "arch", "tree_dead_l", "tree_dead_m", "post_lantern", "gate_side", "lantern"]:
    Image.open(SP + "cem/c3/%s.png" % name).save(OUT + "cem_" + name + ".png")
# A fresh grave's wooden cross (KayKit's grave marker, in the pack's wood)
from cainosify import cainosify
cainosify(Image.open(SP + "cem/raw3/marker.png"), force={"stone": "plank", "iron": "plank", "wood": "plank"}).save(OUT + "cem_marker.png")
# A fresh grave's mound: the village pack's heap of earth, darkened to dug soil
sheet = Image.open(SP + "packs/Pixel Art Top Down - Village v1.0.11/Texture/TX Village Props.png").convert("RGBA")
V = json.load(open(SP + "cainos_objs.json"))
heap = sheet.crop(V["114"]); heap = heap.crop(heap.getbbox())
a = np.array(heap).astype(float)
al = a[..., 3] > 0
lum = 0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]
lo, hi = np.percentile(lum[al], 3), np.percentile(lum[al], 97)
ramp = np.array([(46, 30, 22), (60, 41, 29), (75, 53, 37), (90, 66, 46), (104, 79, 56)], float)
t = np.clip((lum - lo) / max(hi - lo, 1), 0, 0.999)
a[..., :3][al] = ramp[(t * len(ramp)).astype(int)][al]
mound = Image.fromarray(a.astype(np.uint8))
# a grave is narrower than the heap: half its size, every other pixel
mound = mound.resize((mound.width // 2, mound.height // 2), Image.NEAREST)
mound.save(OUT + "cem_mound.png")
for f in sorted(os.listdir(OUT)):
    if f.startswith("cem_") and f.endswith(".png"):
        print(f, Image.open(OUT + f).size)
