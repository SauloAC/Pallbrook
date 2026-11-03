"""The outside: the painted front planes, the roof, a balcony drawn in the art, and the plain volume behind."""
import math, os
from .core import COS, SIN


def build(h):
    sp = h.spec
    # front planes: each a rectangle of the art standing at its own depth
    h.fronts = []
    for i, pl in enumerate(sp["planes"]):
        x0, r0, x1, r1 = pl["rect"]
        z = pl["z"]
        vs = [(h.px(x0), h.y_on(pl, r1), z), (h.px(x1), h.y_on(pl, r1), z), (h.px(x1), h.y_on(pl, r0), z), (h.px(x0), h.y_on(pl, r0), z)]
        uvs = [h.uv(x0, r1), h.uv(x1, r1), h.uv(x1, r0), h.uv(x0, r0)]
        tex = h.key + "_facade.png"
        if pl.get("keep_cols"):        # below keep_from, only these columns belong to this plane
            im = h.art.copy(); pxl = im.load()
            for y in range(pl["keep_from"], h.ih):
                for x in range(h.iw):
                    if not any(a <= x < b for a, b in pl["keep_cols"]):
                        pxl[x, y] = (0, 0, 0, 0)
            tex = "%s_facade_%d.png" % (h.key, i)
            im.save(os.path.join(h.out, tex))
        h.fronts.append((h.obj("Front%d" % i, [(vs, uvs, 1)], ["0 0 1"]), tex))

    # the roof: one slope from the eave row of the art to the top of the image, at the back
    rp = h.plane(sp["roof"]["on_plane"])
    h.re = re = sp["roof"]["row"]
    h.ye, h.ze = ye, ze = h.y_on(rp, re), rp["z"]
    h.yt = yt = (rp["base"] / 32.0 - (ze + h.D) * SIN) / COS
    assert yt >= ye - 0.01, "roof would lean forward: make the house shallower (yt %.2f < eave %.2f)" % (yt, ye)
    XL, XR, D = h.XL * h.kx, -h.XL * h.kx, h.D

    # a balcony in the art becomes a floor at the upper level, cut out of the roof's picture
    h.roof_tex = h.key + "_facade.png"
    h.deck_fn = None
    if h.DECK:
        dk = h.DECK
        dx0, dr0, dx1, dr1 = dk["rect"]
        dpl = h.plane(dk["plane"])
        zrow = lambda r: dpl["z"] - ((dpl["base"] - r) / 32.0 - dk["y"] * COS) / SIN
        h.deck_fn = h.obj("Deck", [([(h.px(dx0), dk["y"], zrow(dr1)), (h.px(dx1), dk["y"], zrow(dr1)), (h.px(dx1), dk["y"], zrow(dr0)), (h.px(dx0), dk["y"], zrow(dr0))],
                                     [h.uv(dx0, dr1), h.uv(dx1, dr1), h.uv(dx1, dr0), h.uv(dx0, dr0)], 1)], ["0 1 0"])
        h.DECK_Z = (zrow(dr0), zrow(dr1))                 # back, front
        h.DECK_X1 = h.px(dx1)
        if dk.get("walk"):                                # only the floor inside the painted railings can be walked on
            wx1, wr0, wr1 = dk["walk"]
            h.DECK_Z, h.DECK_X1 = (zrow(wr0), zrow(wr1)), h.px(wx1)
        im = h.art.copy(); pxl = im.load()
        for y in range(dr0, dr1):
            for x in range(dx0, dx1):
                pxl[x, y] = (0, 0, 0, 0)
        h.roof_tex = h.key + "_facade_roof.png"
        im.save(os.path.join(h.out, h.roof_tex))

    # bits of the outside art kept on show upstairs (what holds up a balcony, say),
    # laid on a front plane just ahead of it: same place on screen, not cut away with the roof and front
    h.keep = []
    for ki, k in enumerate(sp.get("keep_inside", [])):
        kx0, kr0, kx1, kr1 = k["rect"]
        kp = h.plane(k.get("plane", 0))
        kz = kp["z"] + 0.02
        h.keep.append(h.obj("Keep%d" % ki, [([(h.px(kx0), h.y_on(kp, kr1), kz), (h.px(kx1), h.y_on(kp, kr1), kz), (h.px(kx1), h.y_on(kp, kr0), kz), (h.px(kx0), h.y_on(kp, kr0), kz)],
                                               [h.uv(kx0, kr1), h.uv(kx1, kr1), h.uv(kx1, kr0), h.uv(kx0, kr0)], 1)], ["0 0 1"]))

    h.roof_fn = h.obj("Roof", [([(XL, ye, ze), (XR, ye, ze), (XR, yt, -D), (XL, yt, -D)],
                                [h.uv(0, re), h.uv(h.iw, re), h.uv(h.iw, 0), h.uv(0, 0)], 1)],
                      ["0 %.4f %.4f" % (D / math.hypot(D, yt - ye), (yt - ye) / math.hypot(D, yt - ye))])
    # the volume behind (only for shadows and to close it): back wall and the two sides up to the roof
    solid = tuple(sp["solid_uv"])
    xw0, xw1 = h.xw0, h.xw1
    h.body_fn = h.obj("Body", [([(xw1, 0, -D), (xw0, 0, -D), (xw0, yt, -D), (xw1, yt, -D)], [solid] * 4, 1),
                               ([(xw0, 0, -D), (xw0, 0, ze), (xw0, ye, ze), (xw0, yt, -D)], [solid] * 4, 2),
                               ([(xw1, 0, ze), (xw1, 0, -D), (xw1, yt, -D), (xw1, ye, ze)], [solid] * 4, 3)],
                      ["0 0 -1", "-1 0 0", "1 0 0"])
