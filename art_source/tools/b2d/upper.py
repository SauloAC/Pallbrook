"""An upper floor: stairs (along the back wall rising left, or along the left wall rising back),
landing, railings, the upper floor itself, and the lower facade that comes back while the doctor is upstairs."""
from .core import COS, BW, rect_floor


def build(h):
    h.up_meshes, h.up_shapes, h.conv, h.info_up = {}, [], [], None
    UP = h.UP
    if not UP:
        return
    sp, DECK = h.spec, h.DECK
    DECK_Z = getattr(h, "DECK_Z", None)
    XI0, XI1, ZB, xw0, xw1, HIN = h.XI0, h.XI1, h.ZB, h.xw0, h.xw1, h.HIN
    tw, th = h.wall_tile
    obj, px, uv = h.obj, h.px, h.uv
    XLs = h.XL * h.kx
    up_meshes, up_shapes, conv = h.up_meshes, h.up_shapes, h.conv
    H = UP["height"]
    FZ = UP.get("front_z", 0.0)                    # the upper floor may overhang the ground floor (stilts)
    STEPS = UP.get("steps", 14)
    stw, sth = UP.get("stair_wall_tile_px", (tw, th))
    su2, sv2 = 32.0 / stw, 32.0 / sth
    STAIR_MT = "mt_stairwall" if UP.get("stair_wall_tile") else "mt_wall"
    RAIL_H = 0.9 / 1.4
    def beam(faces, xa, ya, xb, yb, zf, t=0.07, d=0.07):
        if xa > xb: xa, ya, xb, yb = xb, yb, xa, ya
        faces.append(([(xa, ya - t, zf), (xb, yb - t, zf), (xb, yb, zf), (xa, ya, zf)], [(0.25, 0.5)] * 4, 2))
        faces.append(([(xa, ya, zf), (xb, yb, zf), (xb, yb, zf - d), (xa, ya, zf - d)], [(0.75, 0.5)] * 4, 1))
    def post(faces, x, y0, y1, zf, w=0.07):
        beam(faces, x - w / 2, y1, x + w / 2, y1, zf, t=y1 - y0, d=w)
    def zrail(faces, x, z0, y0, z1, y1, w=0.07):      # a rail running back along z: only its top shows
        faces.append(([(x - w / 2, y0, z0), (x + w / 2, y0, z0), (x + w / 2, y1, z1), (x - w / 2, y1, z1)], [(0.75, 0.5)] * 4, 1))
    treads, side, rail, upr = [], [], [], []
    if UP.get("dir", "left") == "left":
        # along the back wall, rising to the left to a landing in the back left corner
        LAND_X = XI0 + UP.get("landing", 0.8)
        SF = ZB + UP.get("stair_depth", 1.0)           # front of the stairs = front of the stairwell
        RAMP_LOW = LAND_X + UP.get("run", 2.7)
        dx, dy = (RAMP_LOW - LAND_X) / STEPS, H / STEPS
        for i in range(STEPS):
            xr, xl, y = RAMP_LOW - i * dx, RAMP_LOW - (i + 1) * dx, (i + 1) * dy
            treads.append(([(xl, y, SF), (xr, y, SF), (xr, y, ZB), (xl, y, ZB)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1))
            side.append(([(xl, 0, SF), (xr, 0, SF), (xr, y, SF), (xl, y, SF)],
                         [(xl * su2, 0), (xr * su2, 0), (xr * su2, y * COS * sv2), (xl * su2, y * COS * sv2)], 1))
        land = (XI0, LAND_X, ZB, SF)
        up_meshes["landingfront"] = (obj("LandingFront", [([(XI0, 0, SF), (LAND_X, 0, SF), (LAND_X, H, SF), (XI0, H, SF)],
            [(XI0 * su2, 0), (LAND_X * su2, 0), (LAND_X * su2, H * COS * sv2), (XI0 * su2, H * COS * sv2)], 1)], ["0 0 1"]), STAIR_MT, "")
        floors = [rect_floor(XI0, XI1, SF, FZ, H + 0.01), rect_floor(RAMP_LOW, XI1, ZB, SF, H + 0.01)]
        if h.NOTCH_L:   # not over the nook in front of the left wing
            floors[0:1] = [rect_floor(XI0, h.xnl, SF, h.znl, H + 0.01), rect_floor(h.xnl, XI1, SF, FZ, H + 0.01)]
        line = lambda x: dy / 2 + H * (RAMP_LOW - x) / (RAMP_LOW - LAND_X)
        RZ = SF + 0.05
        beam(rail, RAMP_LOW - dx / 2, line(RAMP_LOW - dx / 2) + RAIL_H, LAND_X + dx / 2, line(LAND_X + dx / 2) + RAIL_H, RZ)
        for i in (0, STEPS // 2, STEPS - 1):
            x = RAMP_LOW - (i + 0.5) * dx
            post(rail, x, (i + 1) * dy, line(x) + RAIL_H, RZ)
        beam(upr, LAND_X + 0.3, H + RAIL_H, RAMP_LOW, H + RAIL_H, RZ)
        for x in (LAND_X + 0.3, (LAND_X + RAMP_LOW) / 2, RAMP_LOW):
            post(upr, x, H, H + RAIL_H, RZ)
        zrail(upr, RAMP_LOW, SF, H + RAIL_H, ZB, H + RAIL_H)
        prof = [(RAMP_LOW + dx / 2, 0), (LAND_X, 0), (LAND_X, H), (LAND_X + dx / 2, H)]
        conv.append(("Stairs", [(x, y, z) for z in (SF, ZB) for x, y in prof]))
        rp_ = [(RAMP_LOW, 0), (LAND_X, H), (LAND_X, H + 1.0), (RAMP_LOW, 1.0)]
        if h.NOTCH_L:
            # a shallow wing: the walk upstairs runs right beside the stairwell, so the rail's collider
            # stops where its top would reach the upper floor (higher up, the stairs are out of reach from below)
            yc = H - 1.05
            xc = RAMP_LOW - (RAMP_LOW - LAND_X) * yc / H
            rp_ = [(RAMP_LOW, 0), (xc, yc), (xc, yc + 1.0), (RAMP_LOW, 1.0)]
        conv.append(("StairRail", [(x, y, z) for z in (SF - 0.02, SF + 0.08) for x, y in rp_]))
        slab_a = [("SlabA", XI0, h.xnl, H - 0.2, H, SF, h.znl), ("SlabA2", h.xnl, XI1, H - 0.2, H, SF, FZ)] if h.NOTCH_L \
            else [("SlabA", XI0, XI1, H - 0.2, H, SF, FZ)]
        up_shapes += slab_a + [("SlabB", RAMP_LOW, XI1, H - 0.2, H, ZB, SF),
                      ("Railing", max(LAND_X + 0.3, h.xnl + h.wt + 0.35) if h.NOTCH_L else LAND_X + 0.3, RAMP_LOW, H - 0.2, H + 1.0, SF, SF + 0.1),
                      ("RailingSide", RAMP_LOW, RAMP_LOW + 0.1, H - 0.2, H + 1.0, ZB, SF + 0.1)]
        info_up = {"H": H, "stairs_x": [round(LAND_X, 3), round(RAMP_LOW, 3)], "stairs_front": round(SF, 3)}
    elif UP.get("side") == "right":
        # along the right wall, rising toward the back to a landing in the back right corner (a stair hall)
        SW = UP.get("width", 1.0)
        XS = XI1 - SW                                   # open side of the stairs
        ZLOW = UP["start_z"]
        ZTOP = ZLOW - UP["run"]
        dz, dy = (ZLOW - ZTOP) / STEPS, H / STEPS
        for i in range(STEPS):
            zf, zb, y = ZLOW - i * dz, ZLOW - (i + 1) * dz, (i + 1) * dy
            treads.append(([(XS, y, zf), (XI1, y, zf), (XI1, y, zb), (XS, y, zb)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1))
            side.append(([(XS, i * dy, zf), (XI1, i * dy, zf), (XI1, y, zf), (XS, y, zf)],
                         [(XS * su2, i * dy * COS * sv2), (XI1 * su2, i * dy * COS * sv2), (XI1 * su2, y * COS * sv2), (XS * su2, y * COS * sv2)], 1))
        land = (XS, XI1, ZB, ZTOP)
        floors = [rect_floor(XI0, XS, ZB, FZ, H + 0.01), rect_floor(XS, XI1, ZLOW, FZ, H + 0.01)]
        line = lambda z: dy / 2 + H * (ZLOW - z) / (ZLOW - ZTOP)
        RX = XS - 0.04
        zrail(rail, RX, ZLOW - dz / 2, line(ZLOW - dz / 2) + RAIL_H, ZTOP + dz / 2, line(ZTOP + dz / 2) + RAIL_H)
        for i in (0, STEPS // 2, STEPS - 1):
            z = ZLOW - (i + 0.5) * dz
            post(rail, RX, (i + 1) * dy, line(z) + RAIL_H, z)
        zrail(upr, RX, ZLOW, H + RAIL_H, ZTOP, H + RAIL_H)
        beam(upr, XS, H + RAIL_H, XI1, H + RAIL_H, ZLOW - 0.04)
        for z in (ZLOW, (ZLOW + ZTOP) / 2, ZTOP):
            post(upr, RX, H, H + RAIL_H, z)
        prof = [(ZLOW + dz / 2, 0), (ZTOP, 0), (ZTOP, H), (ZTOP + dz / 2, H)]
        conv.append(("Stairs", [(x, y, z) for x in (XS, XI1) for z, y in prof]))
        rp_ = [(ZLOW, 0), (ZTOP, H), (ZTOP, H + 1.0), (ZLOW, 1.0)]
        conv.append(("StairRail", [(x, y, z) for x in (XS - 0.08, XS) for z, y in rp_]))
        up_shapes += [("SlabA", XI0, XS, H - 0.2, H, ZB, FZ), ("SlabFront", XS, XI1, H - 0.2, H, ZLOW, FZ),
                      ("Railing", XS - 0.1, XS, H - 0.2, H + 1.0, ZLOW, ZTOP),
                      ("RailingFront", XS - 0.1, XI1, H - 0.2, H + 1.0, ZLOW - 0.1, ZLOW)]
        info_up = {"H": H, "stairs_x": [round(XS, 3), round(XI1, 3)], "stairs_z": [round(ZLOW, 3), round(ZTOP, 3)]}
    else:
        # along the left wall, rising toward the back to a landing in the back left corner; risers face the room
        SW = UP.get("width", 1.0)
        XS = XI0 + SW                                   # open side of the stairs
        ZLOW = UP["start_z"]
        ZTOP = ZLOW - UP["run"]
        dz, dy = (ZLOW - ZTOP) / STEPS, H / STEPS
        for i in range(STEPS):
            zf, zb, y = ZLOW - i * dz, ZLOW - (i + 1) * dz, (i + 1) * dy
            treads.append(([(XI0, y, zf), (XS, y, zf), (XS, y, zb), (XI0, y, zb)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1))
            side.append(([(XI0, i * dy, zf), (XS, i * dy, zf), (XS, y, zf), (XI0, y, zf)],
                         [(XI0 * su2, i * dy * COS * sv2), (XS * su2, i * dy * COS * sv2), (XS * su2, y * COS * sv2), (XI0 * su2, y * COS * sv2)], 1))
        land = (XI0, XS, ZB, ZTOP)
        floors = [rect_floor(XS, XI1, ZB, FZ, H + 0.01), rect_floor(XI0, XS, ZLOW, FZ, H + 0.01)]
        line = lambda z: dy / 2 + H * (ZLOW - z) / (ZLOW - ZTOP)
        RX = XS + 0.04
        zrail(rail, RX, ZLOW - dz / 2, line(ZLOW - dz / 2) + RAIL_H, ZTOP + dz / 2, line(ZTOP + dz / 2) + RAIL_H)
        for i in (0, STEPS // 2, STEPS - 1):
            z = ZLOW - (i + 0.5) * dz
            post(rail, RX, (i + 1) * dy, line(z) + RAIL_H, z)
        zrail(upr, RX, ZLOW, H + RAIL_H, ZTOP, H + RAIL_H)
        beam(upr, XI0, H + RAIL_H, XS, H + RAIL_H, ZLOW - 0.04)
        for z in (ZLOW, (ZLOW + ZTOP) / 2, ZTOP):
            post(upr, RX, H, H + RAIL_H, z)
        prof = [(ZLOW + dz / 2, 0), (ZTOP, 0), (ZTOP, H), (ZTOP + dz / 2, H)]
        conv.append(("Stairs", [(x, y, z) for x in (XI0, XS) for z, y in prof]))
        rp_ = [(ZLOW, 0), (ZTOP, H), (ZTOP, H + 1.0), (ZLOW, 1.0)]
        conv.append(("StairRail", [(x, y, z) for x in (XS, XS + 0.08) for z, y in rp_]))
        up_shapes += [("SlabA", XS, XI1, H - 0.2, H, ZB, FZ), ("SlabFront", XI0, XS, H - 0.2, H, ZLOW, FZ),
                      ("Railing", XS, XS + 0.1, H - 0.2, H + 1.0, ZLOW, ZTOP),
                      ("RailingFront", XI0, XS + 0.1, H - 0.2, H + 1.0, ZLOW - 0.1, ZLOW)]
        info_up = {"H": H, "stairs_x": [round(XI0, 3), round(XS, 3)], "stairs_z": [round(ZLOW, 3), round(ZTOP, 3)]}
    up_meshes["stairtreads"] = (obj("StairTreads", treads, ["0 1 0"]), "mt_tread", "")
    up_meshes["stairside"] = (obj("StairSide", side, ["0 0 1"]), STAIR_MT, "")
    up_meshes["landingtop"] = (obj("LandingTop", [rect_floor(land[0], land[1], land[2], land[3], H + 0.012)], ["0 1 0"]), "mt_floor", "")
    if DECK:
        # the upper floor runs out over the cut east wall to the balcony, edged with timber
        floors.append(rect_floor(XI1 - 0.02, px(DECK["rect"][0]) + 0.02, DECK_Z[0], DECK_Z[1], H + 0.012))
        # beside the solid parts of the east wall, the floor still reaches the painted balcony at its back and front
        zr0, zr1 = h.DECK_ZR
        if zr0 < DECK_Z[0] - 0.01:
            floors.append(rect_floor(xw1 - 0.02, px(DECK["rect"][0]) + 0.02, zr0, DECK_Z[0], H + 0.012))
        if zr1 > DECK_Z[1] + 0.01:
            floors.append(rect_floor(xw1 - 0.02, px(DECK["rect"][0]) + 0.02, DECK_Z[1], zr1, H + 0.012))
        ut_extra = [([(XI1, H + 0.02, DECK_Z[1]), (px(DECK["rect"][0]) + 0.02, H + 0.02, DECK_Z[1]),
                      (px(DECK["rect"][0]) + 0.02, H + 0.02, DECK_Z[1] - 0.1), (XI1, H + 0.02, DECK_Z[1] - 0.1)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1),
                    ([(XI1, H + 0.02, DECK_Z[0] + 0.1), (px(DECK["rect"][0]) + 0.02, H + 0.02, DECK_Z[0] + 0.1),
                      (px(DECK["rect"][0]) + 0.02, H + 0.02, DECK_Z[0]), (XI1, H + 0.02, DECK_Z[0])], [(0, 0), (1, 0), (1, 1), (0, 1)], 1),
                    ([(XI1, H, DECK_Z[0]), (xw1, H, DECK_Z[0]), (xw1, HIN, DECK_Z[0]), (XI1, HIN, DECK_Z[0])],
                     [(0, 0), (0, 1), ((HIN - H) / BW, 1), ((HIN - H) / BW, 0)], 2)]
    else:
        ut_extra = []
    up_meshes["upperfloor"] = (obj("UpperFloor", floors, ["0 1 0"]), "mt_floor", "Upper")
    up_meshes["railing"] = (obj("Railing", rail, ["0 1 0", "0 0 1"]), "mt_rail", "")
    up_meshes["upperrailing"] = (obj("UpperRailing", upr, ["0 1 0", "0 0 1"]), "mt_rail", "Upper")
    up_shapes.append(("Landing", land[0] - (0.0 if UP.get("side") == "right" else 0.05), land[1] + (0.05 if UP.get("side") == "right" else 0.0), 0, H, land[2], land[3]))
    # upstairs the lower storey of the facade comes back over the room below; a sill beam on top of it
    LFP = UP.get("lower_front_plane", 0)
    lp = sp["planes"][LFP]
    rtop = lp["base"] - H * COS * 32
    up_meshes["lowerfront"] = (obj("LowerFront", [([(XLs, 0, lp["z"] + 0.01), (-XLs, 0, lp["z"] + 0.01), (-XLs, H, lp["z"] + 0.01), (XLs, H, lp["z"] + 0.01)],
        [uv(0, lp["base"]), uv(h.iw, lp["base"]), uv(h.iw, rtop), uv(0, rtop)], 1)], ["0 0 1"]), "PLANE%d" % LFP, "Upper")
    sx0 = h.xnl if h.NOTCH_L else xw0        # the sill beam runs along the front wall (behind a left wing's nook, along the wing's)
    ut = [([(sx0, H + 0.02, FZ - 0.005), (xw1, H + 0.02, FZ - 0.005), (xw1, H + 0.02, FZ - 0.33), (sx0, H + 0.02, FZ - 0.33)],
           [(sx0 / BW, 0), (xw1 / BW, 0), (xw1 / BW, 1), (sx0 / BW, 1)], 1)]
    if h.NOTCH_L:
        zw = h.znl
        ut.append(([(xw0, H + 0.02, zw - 0.005), (h.xnl, H + 0.02, zw - 0.005), (h.xnl, H + 0.02, zw - 0.33), (xw0, H + 0.02, zw - 0.33)],
                   [(xw0 / BW, 0), (h.xnl / BW, 0), (h.xnl / BW, 1), (xw0 / BW, 1)], 1))
    up_meshes["uppertimber"] = (obj("UpperTimber", ut + ut_extra, ["0 1 0", "0 0 1"]), "mt_beam", "Upper")
    h.info_up = info_up
    h.H, h.FZ = H, FZ
