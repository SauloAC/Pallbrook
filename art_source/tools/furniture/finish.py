"""Turns the furniture renders (render/render.gd) into the interiors' props: the dark line around each
piece and between its parts, as the Cainos art draws them, then cropped to the piece.

    python3 finish.py <render out dir> <props dir> [piece ...]

Writes <props dir>/prop_<piece>.png for each <piece>.png / <piece>_id.png pair."""
import glob, os, sys
import numpy as np
from PIL import Image

OUTLINE = (72, 37, 16)      # The Cainos props' own outline
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
    out[..., :3][inner] *= INNER
    # around the piece
    tr = np.pad(~al, 1, constant_values=True)
    edge = tr[:-2, 1:-1] | tr[2:, 1:-1] | tr[1:-1, :-2] | tr[1:-1, 2:]
    edge &= al
    out[..., :3][edge] = OUTLINE
    out[..., 3] = np.where(al, 255, 0)
    img = Image.fromarray(out.astype(np.uint8))
    return img.crop(img.getbbox())


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or [os.path.basename(f)[:-4] for f in glob.glob(os.path.join(src, "*.png")) if not f.endswith("_id.png")]
    for n in names:
        img = finish(Image.open(os.path.join(src, n + ".png")), Image.open(os.path.join(src, n + "_id.png")))
        img.save(os.path.join(dst, "prop_%s.png" % n))
        print(n, img.size)
