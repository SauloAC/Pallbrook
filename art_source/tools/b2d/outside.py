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
        # how far the floor beside the east wall reaches: the painted balcony's back railing and front edge
        h.DECK_ZR = (zrow(dk["fill_rows"][0]), zrow(dk["fill_rows"][1])) if dk.get("fill_rows") else h.DECK_Z
        h.DECK_X1 = h.px(dx1)
        if dk.get("walk"):                                # only the floor inside the painted railings can be walked on
            wx1, wr0, wr1 = dk["walk"]
            h.DECK_Z, h.DECK_X1 = (zrow(wr0), zrow(wr1)), h.px(wx1)
        im = h.art.copy(); pxl = im.load()
        # cut a little less than the balcony out of the roof: the two overlap by a couple of pixels,
        # so no seam of ground shows between them where the textures are filtered
        for y in range(dr0, dr1):
            for x in range(dx0 + 2, dx1):
                pxl[x, y] = (0, 0, 0, 0)
        h.roof_tex = h.key + "_facade_roof.png"
        im.save(os.path.join(h.out, h.roof_tex))

    # a raised porch in the art: a floor at the house's floor level, in front of the door
    h.porch_fn = None
    if sp.get("porch"):
        pk = sp["porch"]
        px0, pr0, px1, pr1 = pk["rect"]
        ppl = h.plane(pk.get("plane", 0))
        prow = lambda r: ppl["z"] - ((ppl["base"] - r) / 32.0 - h.FY * COS) / SIN
        h.PORCH = (h.px(px0), h.px(px1), prow(pr0), prow(pr1))       # x0, x1, z back, z front
        h.porch_fn = h.obj("Porch", [([(h.px(px0), h.FY, prow(pr1)), (h.px(px1), h.FY, prow(pr1)), (h.px(px1), h.FY, prow(pr0)), (h.px(px0), h.FY, prow(pr0))],
                                       [h.uv(px0, pr1), h.uv(px1, pr1), h.uv(px1, pr0), h.uv(px0, pr0)], 1)], ["0 1 0"])

    # steps up to the porch: a slope from the porch edge down to the ground, painted with the steps in the art
    h.steps_fn = None
    st_ = sp.get("steps")
    if st_ and st_.get("rect"):
        sx0, sr0, sx1, sr1 = st_["rect"]
        zt, zb = st_["z"]
        # on level ground (no raised floor) they lie just above the street, which would otherwise hide them
        y0, y1 = (0.0, h.FY) if h.FY > 0 else (0.03, 0.03)
        h.steps_fn = h.obj("Steps", [([(h.px(sx0), y0, zb), (h.px(sx1), y0, zb), (h.px(sx1), y1, zt), (h.px(sx0), y1, zt)],
                                       [h.uv(sx0, sr1), h.uv(sx1, sr1), h.uv(sx1, sr0), h.uv(sx0, sr0)], 1)],
                           ["0 %.4f %.4f" % ((zb - zt) / math.hypot(zb - zt, h.FY), h.FY / math.hypot(zb - zt, h.FY))])

    # bits of the outside art kept on show upstairs (what holds up a balcony, say),
    # laid on a front plane just ahead of it: same place on screen, not cut away with the roof and front
    h.keep = []
    for ki, k in enumerate(sp.get("keep_inside", [])):
        kx0, kr0, kx1, kr1 = k["rect"]
        kp = h.plane(k.get("plane", 0))
        kz = kp["z"] + 0.02
        h.keep.append(h.obj("Keep%d" % ki, [([(h.px(kx0), h.y_on(kp, kr1), kz), (h.px(kx1), h.y_on(kp, kr1), kz), (h.px(kx1), h.y_on(kp, kr0), kz), (h.px(kx0), h.y_on(kp, kr0), kz)],
                                               [h.uv(kx0, kr1), h.uv(kx1, kr1), h.uv(kx1, kr0), h.uv(kx0, kr0)], 1)], ["0 0 1"]))

    # a part beside the room that stays on show while the doctor is in (a tower, a gateway): its strip of
    # the roof is a mesh of its own, kept out of the roof that is cut away
    rn = ["0 %.4f %.4f" % (D / math.hypot(D, yt - ye), (yt - ye) / math.hypot(D, yt - ye))]
    h.roofstays_fn = None
    xr0 = XL
    if sp.get("stays"):
        c1 = sp["stays"]["x_px"][1]
        xs = h.px(c1)
        h.roofstays_fn = h.obj("RoofStays", [([(XL, ye, ze), (xs, ye, ze), (xs, yt, -D), (XL, yt, -D)],
                                              [h.uv(0, re), h.uv(c1, re), h.uv(c1, 0), h.uv(0, 0)], 1)], rn)
        xr0, c0 = xs, c1
    else:
        c0 = 0
        # ...or start at one (the forge: only the house's roof slopes; the shed's is in its own front plane)
        if sp["roof"].get("x_px", (0, h.iw))[0] > 0:
            c0 = sp["roof"]["x_px"][0]
            xr0 = h.px(c0)
    # the roof may stop at a column: beyond it a set-back part's own front plane carries its roof (the tavern)
    cr = sp["roof"].get("x_px", (0, h.iw))[1]
    if cr < h.iw:
        XR = h.px(cr)
    h.roof_fn = h.obj("Roof", [([(xr0, ye, ze), (XR, ye, ze), (XR, yt, -D), (xr0, yt, -D)],
                                [h.uv(c0, re), h.uv(cr, re), h.uv(cr, 0), h.uv(c0, 0)], 1)], rn)
    # the volume behind (only for shadows and to close it): back wall and the two sides up to the roof
    solid = tuple(sp["solid_uv"])
    if h.PLAN:      # boxes given by the plan: (x0, x1, z back, z front, height)
        faces = []
        for x0, x1, zb, zf, hh in h.PLAN["body"]:
            faces += [([(x1, 0, zb), (x0, 0, zb), (x0, hh, zb), (x1, hh, zb)], [solid] * 4, 1),
                      ([(x0, 0, zb), (x0, 0, zf), (x0, hh, zf), (x0, hh, zb)], [solid] * 4, 2),
                      ([(x1, 0, zf), (x1, 0, zb), (x1, hh, zb), (x1, hh, zf)], [solid] * 4, 3)]
        h.body_fn = h.obj("Body", faces, ["0 0 -1", "-1 0 0", "1 0 0"])
        return
    xw0, xw1 = h.xw0, h.xw1
    # where the roof stops short (spec roof "x_px"), the part beyond it is lower: its back wall only rises
    # as high as keeps its top under the art's top row there (spec roof "beyond_top_row"), so it never
    # shows above that part's own roof on screen
    if cr < h.iw and sp["roof"].get("beyond_top_row") is not None:
        DN = h.DN if h.NOTCH else D
        hb = max(0.5, (rp["base"] / 32.0 - sp["roof"]["beyond_top_row"] / 32.0 - (ze + DN) * SIN) / COS)
        back = [([(XR, 0, -D), (xw0, 0, -D), (xw0, yt, -D), (XR, yt, -D)], [solid] * 4, 1),
                ([(xw1, 0, -DN), (XR, 0, -DN), (XR, hb, -DN), (xw1, hb, -DN)], [solid] * 4, 1)]
        if DN < D - 0.01:       # the main part's east side, behind the shallower part
            back.append(([(XR, 0, -DN), (XR, 0, -D), (XR, yt, -D), (XR, ye, -DN)], [solid] * 4, 3))
        east = ([(xw1, 0, h.zn if h.NOTCH else ze), (xw1, 0, -DN), (xw1, hb, -DN), (xw1, hb, h.zn if h.NOTCH else ze)], [solid] * 4, 3)
    else:
        back = [([(xw1, 0, -D), (xw0, 0, -D), (xw0, yt, -D), (xw1, yt, -D)], [solid] * 4, 1)]
        east = ([(xw1, 0, h.zn if h.NOTCH else ze), (xw1, 0, -D), (xw1, yt, -D), (xw1, ye, h.zn if h.NOTCH else ze)], [solid] * 4, 3)
    h.body_fn = h.obj("Body", back + [([(xw0, 0, -D), (xw0, 0, h.znl if h.NOTCH_L else ze), (xw0, ye, h.znl if h.NOTCH_L else ze), (xw0, yt, -D)], [solid] * 4, 2),
                               east],
                      ["0 0 -1", "-1 0 0", "1 0 0"])
