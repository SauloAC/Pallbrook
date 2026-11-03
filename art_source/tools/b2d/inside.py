"""The room: floor, the back wall seen from inside, timber on the cut walls, and solid blocks (a fireplace)."""
from .core import COS, BW, rect_floor


def build(h):
    sp, D, HIN = h.spec, h.D, h.HIN
    XI0, XI1, ZB, xw0, xw1 = h.XI0, h.XI1, h.ZB, h.xw0, h.xw1
    if h.NOTCH:     # the floor stops at the lean-to's front wall
        h.floor_fn = h.obj("Floor", [rect_floor(xw0, h.xn, -D, 0.0, 0.02), rect_floor(h.xn, xw1, -D, h.zn, 0.02)], ["0 1 0"])
    else:
        h.floor_fn = h.obj("Floor", [rect_floor(xw0, xw1, -D, 0.0, 0.02)], ["0 1 0"])
    # inner back wall, tiled so its pixels stay square on screen
    su, sv = h.su, h.sv
    h.wall_fn = h.obj("InnerWall", [([(XI0, 0, ZB), (XI1, 0, ZB), (XI1, HIN, ZB), (XI0, HIN, ZB)],
                                     [(XI0 * su, 0), (XI1 * su, 0), (XI1 * su, HIN * COS * sv), (XI0 * su, HIN * COS * sv)], 1)], ["0 0 1"])

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
        elif h.NOTCH and a == XI1:
            # the lean-to's side wall starts at its own front; the main room's east wall stops there
            wall_top(tb, a, b, h.zn - 0.015, -D, HIN); wall_end(tb, a, b, HIN, h.zn - 0.015)
            # the wall between the front room and the lean-to's front is drawn only at floor level,
            # so its frame does not stand over the lean-to on screen
            wall_top(tb, h.xn - h.wt, h.xn, -0.015, h.zn, 0.03)
        else:
            wall_top(tb, a, b, -0.015, -D, HIN); wall_end(tb, a, b, HIN)
    tb.append(([(XI0, HIN, ZB), (XI1, HIN, ZB), (XI1, HIN, -D), (XI0, HIN, -D)],
               [(XI0 / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), (XI0 / BW, 1)], 1))
    h.timber_fn = h.obj("Timber", tb, ["0 1 0", "0 0 1"])
    h.timber_low_fn = h.obj("TimberLower", tb_low, ["0 1 0", "0 0 1"]) if tb_low else None
    h.timber_up_fn = h.obj("TimberUpperWall", tb_up, ["0 1 0", "0 0 1"]) if tb_up else None

    # solid blocks with a painted front (a fireplace): front and top meshes
    h.blocks = []
    for bi, b in enumerate(sp.get("blocks", [])):
        x0, x1, zb, zf, hh = b["x0"], b["x1"], b["z_back"], b["z_front"], b["height"]
        front = h.obj("Block%dFront" % bi, [([(x0, 0, zf), (x1, 0, zf), (x1, hh, zf), (x0, hh, zf)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1)], ["0 0 1"])
        btw, bth = b.get("top_tile_px", h.wall_tile)
        bu, bv = 32.0 / btw, 32.0 / bth
        top = h.obj("Block%dTop" % bi, [([(x0, hh, zf), (x1, hh, zf), (x1, hh, zb), (x0, hh, zb)],
                                         [(x0 * bu, -zf * bv), (x1 * bu, -zf * bv), (x1 * bu, -zb * bv), (x0 * bu, -zb * bv)], 1)], ["0 1 0"])
        h.blocks.append((bi, b, front, top))
