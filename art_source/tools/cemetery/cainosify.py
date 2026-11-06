# Turns a toon render of a 3D piece into the Cainos pack's look: each material (stone, slate roof,
# iron, wood, flame) mapped onto the pack's own colour ramps by its shade, and a dark outline.
import sys, numpy as np
from PIL import Image
RAMPS = {
    "stone": [(88, 76, 62), (98, 90, 79), (105, 99, 90), (122, 119, 110), (135, 132, 121), (146, 142, 132)],
    "roof":  [(58, 52, 56), (69, 62, 65), (81, 74, 75), (93, 86, 85), (104, 97, 95)],
    "iron":  [(34, 30, 36), (46, 42, 48), (60, 56, 62), (76, 72, 78)],
    "plank": [(78, 46, 27), (96, 63, 39), (114, 80, 52), (134, 98, 64), (150, 115, 77)],
    "wood":  [(74, 60, 48), (90, 78, 66), (106, 98, 86), (122, 116, 102), (136, 131, 118)],
}
OUTLINE = {"plank": (61, 33, 16), "stone": (79, 41, 19), "roof": (72, 37, 16), "iron": (24, 20, 24), "wood": (64, 40, 25), "flame": (79, 41, 19)}

def classify(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    mx = rgb.max(-1); mn = rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    cls = np.full(r.shape, "stone", dtype=object)
    cls[(sat > 0.35) & (r > g) & (g > b) & (r - b > 60)] = "roof"
    cls[(sat > 0.12) & (sat <= 0.35) & (r > b + 12) & (lum < 130)] = "wood"
    cls[lum < 62] = "iron"
    cls[(r > 200) & (g > 120) & (b < 120)] = "flame"
    return cls, lum

def cainosify(im, force=None, outline=True):
    a = np.array(im.convert("RGBA")).astype(float)
    rgb, al = a[..., :3], a[..., 3] > 0
    cls, lum = classify(rgb)
    if force:
        for k, v in force.items():
            cls[(cls == k)] = v
    out = a.copy()
    for name, ramp in RAMPS.items():
        m = al & (cls == name)
        if not m.any():
            continue
        lo, hi = np.percentile(lum[m], 3), np.percentile(lum[m], 97)
        t = np.clip((lum - lo) / max(hi - lo, 1), 0, 0.999)
        idx = (t * len(ramp)).astype(int)
        cols = np.array(ramp, float)[idx]
        out[..., :3][m] = cols[m]
    if outline:
        tr = ~al
        edge = np.zeros_like(al)
        edge[1:, :] |= tr[:-1, :]; edge[:-1, :] |= tr[1:, :]; edge[:, 1:] |= tr[:, :-1]; edge[:, :-1] |= tr[:, 1:]
        edge[0, :] = edge[-1, :] = True; edge[:, 0] = edge[:, -1] = True
        edge &= al
        for name, col in OUTLINE.items():
            m = edge & (cls == name)
            out[..., :3][m] = col
    out[..., 3] = np.where(al, 255, 0)
    img = Image.fromarray(out.astype(np.uint8))
    return img.crop(img.getbbox())

if __name__ == "__main__":
    for src, dst in zip(sys.argv[1::2], sys.argv[2::2]):
        cainosify(Image.open(src)).save(dst)
