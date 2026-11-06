"""Turns the furniture renders (render/render.gd) into the interiors' props: the dark line around each
piece and between its parts, as the Cainos art draws them, then cropped to the piece.

    python3 finish.py <render out dir> <props dir> [piece ...]

Writes <props dir>/prop_<piece>.png for each <piece>.png / <piece>_id.png pair, and for a layered
piece (a bed: <piece>_layers.png) its three layers too, each the size of the whole picture:
prop_<piece>_foot.png, _body.png, _head.png. The game stands the foot up at the front of the piece, lays
the body flat over it, and stands the head up at its back (art_source/tools/b2d/scene.py, "split"), so
that someone lying in the bed shows between them. The head stands HEAD_ROWS rows up the picture (at the
back of the footprint): what of it is lower goes with the body."""
import glob, json, os, sys
import numpy as np
from PIL import Image

OUTLINE = (54, 20, 28)      # A dark red-purple, as the references draw their outlines
SHADOW_SHIFT = (3, 2)       # The shadow cast down and right of the piece (pixels), as the references cast it
SHADOW_PAD = 4              # ...for which its picture runs this much further right and down than the piece's
HEAD_ROWS = {"bed": 47, "pew": 0, "chair_e": 0, "chair_w": 0}   # (a pew has no head: its back is its foot, its seat its body)     # 0.766 (sin 50) x 1.37 (the head's depth behind the foot, building units) x 44.8 px
INNER = 0.55                # A line between two parts: the nearer part's edge, darkened this much


def finish(colour, ids):
    a = np.array(colour.convert("RGBA")).astype(float)
    idv = np.array(ids.convert("RGB")).astype(int)
    key = idv[..., 0] * 65536 + idv[..., 1] * 256 + idv[..., 2]
    al = a[..., 3] > 128
    out = a.copy()
    # between parts: where a pixel's part differs from the one above or to its left
    inner = np.zeros_like(al)
    inner[1:, :] |= (key[1:, :] != key[:-1, :]) & al[:-1, :]
    inner[:, 1:] |= (key[:, 1:] != key[:, :-1]) & al[:, :-1]
    inner &= al
    out[..., :3][inner] = out[..., :3][inner] * INNER * 0.7 + np.array(OUTLINE, float) * 0.3
    # around the piece
    tr = np.pad(~al, 1, constant_values=True)
    edge = tr[:-2, 1:-1] | tr[2:, 1:-1] | tr[1:-1, :-2] | tr[1:-1, 2:]
    edge &= al
    out[..., :3][edge] = OUTLINE
    out[..., 3] = np.where(al, 255, 0)
    img = Image.fromarray(out.astype(np.uint8))
    return img, img.getbbox()


def shadow(foot, box):
    """The shadow a piece casts on the floor: its footprint (the flat render) a pixel wider all round,
    moved down and right, cropped as the picture is but SHADOW_PAD further right and down. Black, its
    alpha the mask: the game's material gives it its colour and strength"""
    m = np.array(foot.convert("RGBA"))[..., 3] > 128
    g = np.pad(m, 1)
    m = g[1:-1, 1:-1] | g[:-2, 1:-1] | g[2:, 1:-1] | g[1:-1, :-2] | g[1:-1, 2:]
    sx, sy = SHADOW_SHIFT
    moved = np.zeros((m.shape[0] + SHADOW_PAD, m.shape[1] + SHADOW_PAD), bool)
    moved[sy:sy + m.shape[0], sx:sx + m.shape[1]] = m
    x0, y0, x1, y1 = box
    out = np.zeros(moved.shape + (4,), np.uint8)
    out[..., 3] = np.where(moved, 255, 0)
    return Image.fromarray(out).crop((x0, y0, x1 + SHADOW_PAD, y1 + SHADOW_PAD))


def layers(img, box, lay, head_rows):
    """The finished picture split by the layer render (red: foot, green: body, blue: head)"""
    a = np.array(img)
    lv = np.array(lay.convert("RGB")).astype(int)
    which = np.argmax(lv, axis=-1)            # 0 foot, 1 body, 2 head
    # pixels on the outline take the layer of their nearest neighbour inside (the layer render has no outline)
    rows = np.arange(a.shape[0])[:, None] * np.ones((1, a.shape[1]), int)
    bottom = box[3] - 1
    which[(which == 2) & (bottom - rows < head_rows)] = 1
    out = {}
    for k, name in enumerate(("foot", "body", "head")):
        b = a.copy()
        b[..., 3] = np.where(which == k, a[..., 3], 0)
        out[name] = Image.fromarray(b).crop(box)
    return out


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or [os.path.basename(f)[:-4] for f in glob.glob(os.path.join(src, "*.png")) if not f.endswith(("_id.png", "_layers.png", "_shadow.png"))]
    for n in names:
        img, box = finish(Image.open(os.path.join(src, n + ".png")), Image.open(os.path.join(src, n + "_id.png")))
        img.crop(box).save(os.path.join(dst, "prop_%s.png" % n))
        fl = os.path.join(src, n + "_flames.json")
        flames = [(int(round(x - box[0] - 0.5)), int(round(y - box[1] - 0.5))) for x, y in json.load(open(fl))] if os.path.exists(fl) else []
        print(n, img.crop(box).size, ("flames %s" % flames) if flames else "")     # the spec's "flames"
        sh = os.path.join(src, n + "_shadow.png")
        if os.path.exists(sh):
            shadow(Image.open(sh), box).save(os.path.join(dst, "prop_%s_shadow.png" % n))
        lay = os.path.join(src, n + "_layers.png")
        if os.path.exists(lay):
            for part, im in layers(img, box, Image.open(lay), HEAD_ROWS[n]).items():
                im.save(os.path.join(dst, "prop_%s_%s.png" % (n, part)))
