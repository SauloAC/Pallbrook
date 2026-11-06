"""The room: floor, the back wall seen from inside, timber on the cut walls, and solid blocks (a fireplace)."""
from .core import COS, BW, rect_floor


def build_plan(h):
    """the plan's own floors (each its tile, inside or always on show), back walls seen from inside and wall tops"""
    P, HIN, FY, su, sv = h.PLAN, h.HIN, h.FY, h.su, h.sv
    groups = {}
    for f in P["floors"]:
        x0, x1, zb, zf = f["rect"]
        groups.setdefault((f.get("tile"), bool(f.get("outside"))), []).append(rect_floor(x0, x1, zb, zf, FY + 0.02))
    h.plan_floors = []
    for i, ((tile, out), rects) in enumerate(groups.items()):
        h.plan_floors.append((h.obj("Floor%d" % i if i else "Floor", rects, ["0 1 0"]), tile, out))
    h.floor_fn = h.plan_floors[0][0]
    h.wall_fn = h.obj("InnerWall", [([(a, FY, z), (b, FY, z), (b, HIN, z), (a, HIN, z)],
                                     [(a * su, 0), (b * su, 0), (b * su, (HIN - FY) * COS * sv), (a * su, (HIN - FY) * COS * sv)], 1)
                                    for a, b, z in P["inner_walls"]], ["0 0 1"])
    tb = []
    for c in P["caps"]:            # (x0, x1, z0, z1) at the room's height, or with its own height
        a, b, z0, z1 = c[:4]
        y = c[4] if len(c) > 4 else HIN
        tb.append(([(a, y, z0), (b, y, z0), (b, y, z1), (a, y, z1)], [(0, 0), (0, 1), (-z1 / BW, 1), (-z0 / BW, 0)], 1))
    for a, b, z, hh in P.get("ends", []):     # a wall's end seen from the front
        tb.append(([(a, 0, z), (b, 0, z), (b, hh, z), (a, hh, z)], [(0, 0), (0, 1), (hh / BW, 1), (hh / BW, 0)], 2))
    h.timber_fn = h.obj("Timber", tb, ["0 1 0", "0 0 1"])
    h.timber_low_fn = h.timber_up_fn = None


def build(h):
    sp, D, HIN = h.spec, h.D, h.HIN
    h.plan_floors = None
    if h.PLAN:
        build_plan(h)
        build_blocks(h)
        return
    XI0, XI1, ZB, xw0, xw1 = h.XI0, h.XI1, h.ZB, h.xw0, h.xw1
    if h.NOTCH:     # the floor stops at the lean-to's front wall
        h.floor_fn = h.obj("Floor", [rect_floor(xw0, h.xn, -D, 0.0, h.FY + 0.02), rect_floor(h.xn, xw1, -h.DN, h.zn, h.FY + 0.02)], ["0 1 0"])
    elif h.NOTCH_L:   # ...or at the left wing's
        h.floor_fn = h.obj("Floor", [rect_floor(xw0, h.xnl, -D, h.znl, h.FY + 0.02), rect_floor(h.xnl, xw1, -D, 0.0, h.FY + 0.02)], ["0 1 0"])
    else:
        h.floor_fn = h.obj("Floor", [rect_floor(xw0, xw1, -D, 0.0, h.FY + 0.02)], ["0 1 0"])
    # inner back wall, tiled so its pixels stay square on screen
    su, sv = h.su, h.sv
    FY = h.FY
    SHALLOW = h.NOTCH and h.DN < D - 0.01            # the set-back part ends before the main part does
    def back_wall(a, b, z):
        return ([(a, FY, z), (b, FY, z), (b, HIN, z), (a, HIN, z)],
                [(a * su, 0), (b * su, 0), (b * su, (HIN - FY) * COS * sv), (a * su, (HIN - FY) * COS * sv)], 1)
    if SHALLOW:
        h.wall_fn = h.obj("InnerWall", [back_wall(XI0, h.xn - h.wt, ZB), back_wall(h.xn - h.wt, XI1, h.ZBN)], ["0 0 1"])
    else:
        h.wall_fn = h.obj("InnerWall", [back_wall(XI0, XI1, ZB)], ["0 0 1"])

    # cut walls: timber on the side and back wall tops and on the side wall front ends
    tb, tb_low, tb_up = [], [], []           # always / downstairs only / upstairs only (beside a balcony)

    def wall_top(lst, a, b, z0, z1, y):
        lst.append(([(a, y, z0), (b, y, z0), (b, y, z1), (a, y, z1)], [(0, 0), (0, 1), (-z1 / BW, 1), (-z0 / BW, 0)], 1))

    def wall_end(lst, a, b, hh, z=-0.015):
        lst.append(([(a, 0, z), (b, 0, z), (b, hh, z), (a, hh, z)], [(0, 0), (0, 1), (hh / BW, 1), (hh / BW, 0)], 2))

    for a, b in ((xw0, XI0), (XI1, xw1)):
        if h.DECK and a == XI1:
            # downstairs the east wall stands whole; upstairs it is cut down to the balcony floor in front of it and opens on it
            wall_top(tb, a, b, h.DECK_Z[0], -D, HIN)
            wall_top(tb_low, a, b, -0.015, h.DECK_Z[0], HIN); wall_end(tb_low, a, b, HIN)
            wall_top(tb_up, a, b, -0.015, h.DECK_Z[1], h.DECK["y"] + 0.02); wall_end(tb_up, a, b, h.DECK["y"])
        elif h.NOTCH_L and a == xw0:
            # the wing's side wall starts at its own front; the main room's west wall stands in front of it
            wall_top(tb, a, b, h.znl - 0.015, -D, HIN); wall_end(tb, a, b, HIN, h.znl - 0.015)
            # the main block's west wall, beside the nook: framed at floor level downstairs, and upstairs at
            # the upper floor (a frame at the full height would stand over the wing on screen)
            if h.UP:
                wall_top(tb_low, h.xnl, h.xnl + h.wt, -0.015, h.znl, 0.03)
                wall_top(tb_up, h.xnl, h.xnl + h.wt, -0.015, h.znl, h.UP["height"] + 0.02); wall_end(tb_up, h.xnl, h.xnl + h.wt, h.UP["height"])
            else:
                wall_top(tb, h.xnl, h.xnl + h.wt, -0.015, h.znl, 0.03)
        elif h.NOTCH and a == XI1:
            # the lean-to's side wall starts at its own front; the main room's east wall stops there
            wall_top(tb, a, b, h.zn - 0.015, -h.DN, HIN); wall_end(tb, a, b, HIN, h.zn - 0.015)
            if SHALLOW:     # behind the shallower part, the main room's own east wall
                wall_top(tb, h.xn - h.wt, h.xn, h.ZBN, -D, HIN)
            # the wall between the front room and the lean-to's front is drawn only at floor level,
            # so its frame does not stand over the lean-to on screen
            wall_top(tb, h.xn - h.wt, h.xn, -0.015, h.zn, 0.03)
        else:
            wall_top(tb, a, b, -0.015, -D, HIN); wall_end(tb, a, b, HIN)
    # inner walls between ground-floor rooms (a stable and a stair hall): only downstairs, under the upper floor
    for pt in sp.get("partitions", []):
        pa, pb = pt["x"]
        wall_top(tb_low, pa, pb, -0.015, ZB, pt["height"]); wall_end(tb_low, pa, pb, pt["height"])
    if SHALLOW:
        tb.append(([(XI0, HIN, ZB), (h.xn - h.wt, HIN, ZB), (h.xn - h.wt, HIN, -D), (XI0, HIN, -D)],
                   [(XI0 / BW, 0), ((h.xn - h.wt) / BW, 0), ((h.xn - h.wt) / BW, 1), (XI0 / BW, 1)], 1))
        tb.append(([(h.xn - h.wt, HIN, h.ZBN), (XI1, HIN, h.ZBN), (XI1, HIN, -h.DN), (h.xn - h.wt, HIN, -h.DN)],
                   [((h.xn - h.wt) / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), ((h.xn - h.wt) / BW, 1)], 1))
    else:
        tb.append(([(XI0, HIN, ZB), (XI1, HIN, ZB), (XI1, HIN, -D), (XI0, HIN, -D)],
                   [(XI0 / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), (XI0 / BW, 1)], 1))
    h.timber_fn = h.obj("Timber", tb, ["0 1 0", "0 0 1"])
    h.timber_low_fn = h.obj("TimberLower", tb_low, ["0 1 0", "0 0 1"]) if tb_low else None
    h.timber_up_fn = h.obj("TimberUpperWall", tb_up, ["0 1 0", "0 0 1"]) if tb_up else None

    build_blocks(h)


def build_blocks(h):
    sp = h.spec
    # solid blocks with a painted front (a fireplace): front and top meshes
    h.blocks = []
    for bi, b in enumerate(sp.get("blocks", [])):
        x0, x1, zb, zf, hh = b["x0"], b["x1"], b["z_back"], b["z_front"], b["height"]
        y0 = h.FY                     # blocks stand on the floor
        hh = y0 + hh
        front = h.obj("Block%dFront" % bi, [([(x0, y0, zf), (x1, y0, zf), (x1, hh, zf), (x0, hh, zf)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1)], ["0 0 1"])
        btw, bth = b.get("top_tile_px", h.wall_tile)
        bu, bv = 32.0 / btw, 32.0 / bth
        top = h.obj("Block%dTop" % bi, [([(x0, hh, zf), (x1, hh, zf), (x1, hh, zb), (x0, hh, zb)],
                                         [(x0 * bu, -zf * bv), (x1 * bu, -zf * bv), (x1 * bu, -zb * bv), (x0 * bu, -zb * bv)], 1)], ["0 1 0"])
        h.blocks.append((bi, b, front, top))
