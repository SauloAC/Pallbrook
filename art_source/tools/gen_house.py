# Builds a single-storey 2D-on-volume house (scene + meshes + textures) from a spec.
# Local units: the town scales each house node by 1.4. x east, y up, z south; z = 0 is the door's wall,
# x = 0 the middle of the facade art. Camera: orthographic, pitched 50 deg, no yaw; art at 32 px per unit.
# A point (y, z) on a front plane whose ground sits on image row `base` (plane at depth zf) is drawn
# on row  base - 32 * (y*cos50 + (zf - z)*sin50).
#   python3 gen_house.py <spec.py> <out_dir> <props_dir>
import math, os, sys, json, runpy
from PIL import Image

SPEC = runpy.run_path(sys.argv[1])["SPEC"]
OUT, PROPS_SRC = sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
COS, SIN = math.cos(math.radians(50)), math.sin(math.radians(50))
FURN = 1 / 1.4
NAME, KEY = SPEC["name"], SPEC["name"].lower()
R = "res://assets/buildings2d/"
RH = R + KEY + "/"

art = Image.open(SPEC["facade"]).convert("RGBA")
IW, IH = art.size
art.save(os.path.join(OUT, KEY + "_facade.png"))
W = IW / 32.0
XL = -W / 2
px = lambda p: XL + p / 32.0
D = SPEC["depth"]
xw0, xw1 = px(SPEC["wall_px"][0]), px(SPEC["wall_px"][1])
T = 0.3
XI0, XI1, ZB = xw0 + T, xw1 - T, -D + T
HIN = SPEC["room_height"]

def obj(name, faces, normals):
    L = ["# Pallbrook 2D building part: %s_%s" % (KEY, name), "o %s_%s" % (KEY, name)]
    V, U, F = [], [], []
    for vs, uvs, n in faces:
        b = len(V); V += vs; U += uvs
        F.append("f " + " ".join("%d/%d/%d" % (b + i + 1, b + i + 1, n) for i in range(len(vs))))
    L += ["v %.6f %.6f %.6f" % v for v in V] + ["vt %.6f %.6f" % u for u in U]
    L += ["vn %s" % n for n in normals] + ["s 0"] + F
    fn = "%s_%s.obj" % (KEY, name.lower())
    open(os.path.join(OUT, fn), "w").write("\n".join(L) + "\n")
    return fn

uv = lambda p, row: (p / IW, 1 - row / IH)
def y_on(plane, row):
    return (plane["base"] - row) / 32.0 / COS

# ---------- the outside: front planes and the roof ----------
fronts = []
for i, pl in enumerate(SPEC["planes"]):
    x0, r0, x1, r1 = pl["rect"]
    z = pl["z"]
    vs = [(px(x0), y_on(pl, r1), z), (px(x1), y_on(pl, r1), z), (px(x1), y_on(pl, r0), z), (px(x0), y_on(pl, r0), z)]
    uvs = [uv(x0, r1), uv(x1, r1), uv(x1, r0), uv(x0, r0)]
    tex = KEY + "_facade.png"
    if pl.get("keep_cols"):        # below keep_from, only these columns belong to this plane
        im = art.copy(); pxl = im.load()
        for y in range(pl["keep_from"], IH):
            for x in range(IW):
                if not any(a <= x < b for a, b in pl["keep_cols"]):
                    pxl[x, y] = (0, 0, 0, 0)
        tex = "%s_facade_%d.png" % (KEY, i)
        im.save(os.path.join(OUT, tex))
    fronts.append((obj("Front%d" % i, [(vs, uvs, 1)], ["0 0 1"]), tex))
rp = SPEC["planes"][SPEC["roof"]["on_plane"]]
re = SPEC["roof"]["row"]
ye, ze = y_on(rp, re), rp["z"]
yt = (rp["base"] / 32.0 - (ze + D) * SIN) / COS
assert yt >= ye - 0.01, "roof would lean forward: make the house shallower (yt %.2f < eave %.2f)" % (yt, ye)
XR = -XL
DECK = SPEC.get("deck")
roof_tex = KEY + "_facade.png"
if DECK:
    dx0, dr0, dx1, dr1 = DECK["rect"]
    dpl = SPEC["planes"][DECK["plane"]]
    zrow = lambda r: dpl["z"] - ((dpl["base"] - r) / 32.0 - DECK["y"] * COS) / SIN
    deck_fn = obj("Deck", [([(px(dx0), DECK["y"], zrow(dr1)), (px(dx1), DECK["y"], zrow(dr1)), (px(dx1), DECK["y"], zrow(dr0)), (px(dx0), DECK["y"], zrow(dr0))],
                            [uv(dx0, dr1), uv(dx1, dr1), uv(dx1, dr0), uv(dx0, dr0)], 1)], ["0 1 0"])
    DECK_Z = (zrow(dr0), zrow(dr1))                 # back, front
    DECK_X1 = px(dx1)
    if DECK.get("walk"):                            # only the floor inside the painted railings can be walked on
        wx1, wr0, wr1 = DECK["walk"]
        DECK_Z, DECK_X1 = (zrow(wr0), zrow(wr1)), px(wx1)
    im = art.copy(); pxl = im.load()
    for y in range(dr0, dr1):
        for x in range(dx0, dx1):
            pxl[x, y] = (0, 0, 0, 0)
    roof_tex = KEY + "_facade_roof.png"
    im.save(os.path.join(OUT, roof_tex))
# bits of the outside art that stay drawn while the doctor is inside (what holds up a balcony, say),
# laid on a front plane just ahead of it: same place on screen, not cut away with the roof and front
KEEP = []
for ki, k in enumerate(SPEC.get("keep_inside", [])):
    kx0, kr0, kx1, kr1 = k["rect"]
    kp = SPEC["planes"][k.get("plane", 0)]
    kz = kp["z"] + 0.02
    KEEP.append(obj("Keep%d" % ki, [([(px(kx0), y_on(kp, kr1), kz), (px(kx1), y_on(kp, kr1), kz), (px(kx1), y_on(kp, kr0), kz), (px(kx0), y_on(kp, kr0), kz)],
                                      [uv(kx0, kr1), uv(kx1, kr1), uv(kx1, kr0), uv(kx0, kr0)], 1)], ["0 0 1"]))
roof_fn = obj("Roof", [([(XL, ye, ze), (XR, ye, ze), (XR, yt, -D), (XL, yt, -D)],
                        [uv(0, re), uv(IW, re), uv(IW, 0), uv(0, 0)], 1)],
              ["0 %.4f %.4f" % (D / math.hypot(D, yt - ye), (yt - ye) / math.hypot(D, yt - ye))])
# Body (only for shadows and to close the volume): back wall and the two sides up to the roof
solid = tuple(SPEC["solid_uv"])
body_fn = obj("Body", [([(xw1, 0, -D), (xw0, 0, -D), (xw0, yt, -D), (xw1, yt, -D)], [solid] * 4, 1),
                       ([(xw0, 0, -D), (xw0, 0, ze), (xw0, ye, ze), (xw0, yt, -D)], [solid] * 4, 2),
                       ([(xw1, 0, ze), (xw1, 0, -D), (xw1, yt, -D), (xw1, ye, ze)], [solid] * 4, 3)],
              ["0 0 -1", "-1 0 0", "1 0 0"])

# ---------- the inside ----------
def rect_floor(a, b, zb, zf, y, tile=3.0):
    return ([(a, y, zf), (b, y, zf), (b, y, zb), (a, y, zb)],
            [(a / tile, -zf / tile), (b / tile, -zf / tile), (b / tile, -zb / tile), (a / tile, -zb / tile)], 1)
floor_fn = obj("Floor", [rect_floor(xw0, xw1, -D, 0.0, 0.02)], ["0 1 0"])
# inner back wall, tiled: 1 unit wide, cos50 units tall per tile so its pixels stay square on screen
tw, th = SPEC.get("inner_wall_tile_px", (32, 32))
su, sv = 32.0 / tw, 32.0 / th
wall_fn = obj("InnerWall", [([(XI0, 0, ZB), (XI1, 0, ZB), (XI1, HIN, ZB), (XI0, HIN, ZB)],
                             [(XI0 * su, 0), (XI1 * su, 0), (XI1 * su, HIN * COS * sv), (XI0 * su, HIN * COS * sv)], 1)], ["0 0 1"])
# cut walls: timber on the side and back wall tops and on the side wall front ends
BW = 0.5
tb = []
tb_low, tb_up = [], []                              # downstairs-only and upstairs-only timber (beside a balcony)
def wall_top(lst, a, b, z0_, z1_, yy):
    lst.append(([(a, yy, z0_), (b, yy, z0_), (b, yy, z1_), (a, yy, z1_)], [(0, 0), (0, 1), (-z1_ / BW, 1), (-z0_ / BW, 0)], 1))
def wall_end(lst, a, b, hh):
    lst.append(([(a, 0, -0.015), (b, 0, -0.015), (b, hh, -0.015), (a, hh, -0.015)], [(0, 0), (0, 1), (hh / BW, 1), (hh / BW, 0)], 2))
for a, b in ((xw0, XI0), (XI1, xw1)):
    if DECK and a == XI1:
        # downstairs the east wall stands whole; upstairs it is cut down to the balcony floor in front of it and opens on it
        wall_top(tb, a, b, DECK_Z[0], -D, HIN)
        wall_top(tb_low, a, b, -0.015, DECK_Z[0], HIN); wall_end(tb_low, a, b, HIN)
        wall_top(tb_up, a, b, -0.015, DECK_Z[1], DECK["y"] + 0.02); wall_end(tb_up, a, b, DECK["y"])
    else:
        wall_top(tb, a, b, -0.015, -D, HIN); wall_end(tb, a, b, HIN)
tb.append(([(XI0, HIN, ZB), (XI1, HIN, ZB), (XI1, HIN, -D), (XI0, HIN, -D)],
           [(XI0 / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), (XI0 / BW, 1)], 1))
timber_fn = obj("Timber", tb, ["0 1 0", "0 0 1"])
timber_low_fn = obj("TimberLower", tb_low, ["0 1 0", "0 0 1"]) if tb_low else None
timber_up_fn = obj("TimberUpperWall", tb_up, ["0 1 0", "0 0 1"]) if tb_up else None

BLOCKS = []
for bi, b in enumerate(SPEC.get("blocks", [])):
    x0, x1, zb, zf, h = b["x0"], b["x1"], b["z_back"], b["z_front"], b["height"]
    front = obj("Block%dFront" % bi, [([(x0, 0, zf), (x1, 0, zf), (x1, h, zf), (x0, h, zf)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1)], ["0 0 1"])
    btw, bth = b.get("top_tile_px", (tw, th))
    bu, bv = 32.0 / btw, 32.0 / bth
    top = obj("Block%dTop" % bi, [([(x0, h, zf), (x1, h, zf), (x1, h, zb), (x0, h, zb)],
                                   [(x0 * bu, -zf * bv), (x1 * bu, -zf * bv), (x1 * bu, -zb * bv), (x0 * bu, -zb * bv)], 1)], ["0 1 0"])
    BLOCKS.append((bi, b, front, top))

UP = SPEC.get("upper")
up_meshes, up_shapes, conv = {}, [], []
if UP:
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
        conv.append(("StairRail", [(x, y, z) for z in (SF - 0.02, SF + 0.08) for x, y in rp_]))
        up_shapes += [("SlabA", XI0, XI1, H - 0.2, H, SF, FZ), ("SlabB", RAMP_LOW, XI1, H - 0.2, H, ZB, SF),
                      ("Railing", LAND_X + 0.3, RAMP_LOW, H - 0.2, H + 1.0, SF, SF + 0.1),
                      ("RailingSide", RAMP_LOW, RAMP_LOW + 0.1, H - 0.2, H + 1.0, ZB, SF + 0.1)]
        info_up = {"H": H, "stairs_x": [round(LAND_X, 3), round(RAMP_LOW, 3)], "stairs_front": round(SF, 3)}
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
    up_shapes.append(("Landing", land[0] - 0.05, land[1], 0, H, land[2], land[3]))
    # upstairs the lower storey of the facade comes back over the room below; a sill beam on top of it
    LFP = UP.get("lower_front_plane", 0)
    lp = SPEC["planes"][LFP]
    rtop = lp["base"] - H * COS * 32
    up_meshes["lowerfront"] = (obj("LowerFront", [([(XL, 0, lp["z"] + 0.01), (-XL, 0, lp["z"] + 0.01), (-XL, H, lp["z"] + 0.01), (XL, H, lp["z"] + 0.01)],
        [uv(0, lp["base"]), uv(IW, lp["base"]), uv(IW, rtop), uv(0, rtop)], 1)], ["0 0 1"]), "PLANE%d" % LFP, "Upper")
    ut = [([(xw0, H + 0.02, FZ - 0.005), (xw1, H + 0.02, FZ - 0.005), (xw1, H + 0.02, FZ - 0.33), (xw0, H + 0.02, FZ - 0.33)],
           [(xw0 / BW, 0), (xw1 / BW, 0), (xw1 / BW, 1), (xw0 / BW, 1)], 1)]
    up_meshes["uppertimber"] = (obj("UpperTimber", ut + ut_extra, ["0 1 0", "0 0 1"]), "mt_beam", "Upper")

d0, d1 = px(SPEC["door_px"][0]), px(SPEC["door_px"][1])

# ---------- props ----------
props = json.load(open(os.path.join(PROPS_SRC, "prop_sizes_all.json")))
ext, sub, nodes, shapes = [], [], [], []
def E(kind, path, rid): ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
def S(t): sub.append(t)
def N(t): nodes.append(t)
def mat(rid, shader, tex):
    S('[sub_resource type="ShaderMaterial" id="%s"]\nshader = ExtResource("%s")\nshader_parameter/tex = ExtResource("%s")\n'
      'shader_parameter/lit_share = 0.5\nshader_parameter/own_light = 0.85\n' % (rid, shader, tex))
def tf(x, y, z, flat=False):
    b = "1, 0, 0, 0, 0, 1, 0, -1, 0" if flat else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return "Transform3D(%s, %.4f, %.4f, %.4f)" % (b, x, y, z)

E("Shader", R + "sprite_surface.gdshader", "sh_sprite")
E("Shader", R + "tile_surface.gdshader", "sh_tile")
E("Texture2D", R + "tile_wood_floor.png", "tx_floor")
E("Texture2D", R + SPEC["inner_wall_tile"], "tx_wall")
E("Texture2D", R + "tile_beam.png", "tx_beam")
mat("mt_floor", "sh_tile", "tx_floor"); mat("mt_wall", "sh_tile", "tx_wall"); mat("mt_beam", "sh_tile", "tx_beam")
if UP:
    E("Texture2D", R + "tile_stair_tread.png", "tx_tread"); E("Texture2D", R + "tile_rail_wood.png", "tx_rail")
    mat("mt_tread", "sh_sprite", "tx_tread"); mat("mt_rail", "sh_sprite", "tx_rail")
    if UP.get("stair_wall_tile"):
        E("Texture2D", R + UP["stair_wall_tile"], "tx_stairwall"); mat("mt_stairwall", "sh_tile", "tx_stairwall")
    for nm, (fn, mt, parent) in up_meshes.items():
        E("ArrayMesh", RH + fn, "m_" + nm)
for i, (fn, tex) in enumerate(fronts):
    E("ArrayMesh", RH + fn, "m_front%d" % i)
    if not any(('id="tx_%s"' % tex.replace(".png", "")) in e for e in ext):
        E("Texture2D", RH + tex, "tx_" + tex.replace(".png", ""))
        mat("mt_" + tex.replace(".png", ""), "sh_sprite", "tx_" + tex.replace(".png", ""))
for ki, kfn in enumerate(KEEP):
    E("ArrayMesh", RH + kfn, "m_keep%d" % ki)
if timber_low_fn:
    E("ArrayMesh", RH + timber_low_fn, "m_timberlow"); E("ArrayMesh", RH + timber_up_fn, "m_timberupw")
if DECK:
    E("ArrayMesh", RH + deck_fn, "m_deck"); E("Texture2D", RH + roof_tex, "tx_roof"); mat("mt_roof", "sh_sprite", "tx_roof")
for nm, fn in (("roof", roof_fn), ("body", body_fn), ("floor", floor_fn), ("innerwall", wall_fn), ("timber", timber_fn)):
    E("ArrayMesh", RH + fn, "m_" + nm)
FX = R + "fx/"
if SPEC.get("smoke_px") or any(b.get("flame") for b in SPEC.get("blocks", [])):
    E("Shader", FX + "fx_smoke.gdshader", "sh_smoke"); E("Shader", FX + "fx_flame.gdshader", "sh_flame")
    E("Texture2D", FX + "fx_smoke.png", "tx_smoke"); E("Texture2D", FX + "fx_smoke_ramp.png", "tx_smoke_ramp"); E("Texture2D", FX + "fx_flame.png", "tx_flame")
    S('[sub_resource type="ShaderMaterial" id="mt_smoke"]\nshader = ExtResource("sh_smoke")\nshader_parameter/smoke = ExtResource("tx_smoke")\nshader_parameter/ramp = ExtResource("tx_smoke_ramp")\n')
    S('[sub_resource type="ShaderMaterial" id="mt_flame"]\nshader = ExtResource("sh_flame")\nshader_parameter/frames = ExtResource("tx_flame")\n')
for bi, b, front, top in BLOCKS:
    E("ArrayMesh", RH + front, "m_block%df" % bi); E("ArrayMesh", RH + top, "m_block%dt" % bi)
    E("Texture2D", R + "props/prop_%s.png" % b["front_tex"], "tx_block%d" % bi); mat("mt_block%d" % bi, "sh_sprite", "tx_block%d" % bi)
    if b.get("top_tile"):
        E("Texture2D", R + b["top_tile"], "tx_block%dtop" % bi); mat("mt_block%dtop" % bi, "sh_tile", "tx_block%dtop" % bi)
used = sorted(set(f["prop"] for f in SPEC["furniture"]) | ({"rug"} if SPEC.get("door_rug", True) else set()))
for p in used:
    E("Texture2D", R + "props/prop_%s.png" % p, "tx_p_" + p)
    mat("mt_p_" + p, "sh_sprite", "tx_p_" + p)

N('[node name="%s2D" type="Node3D"]\n' % NAME)
N('[node name="%s_Front" type="Node3D" parent="."]\n' % NAME)
facade_mat = "mt_" + KEY + "_facade"
for i, (fn, tex) in enumerate(fronts):
    N('[node name="Plane%d" type="MeshInstance3D" parent="%s_Front"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
      % (i, NAME, i, tex.replace(".png", "")))
N('[node name="%s_Roof" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_roof")\nmaterial_override = SubResource("%s")\n' % (NAME, "mt_roof" if DECK else facade_mat))
if DECK:
    # outside the balcony goes with the roof it was cut from; upstairs a copy shows (below, in _Upper)
    N('[node name="Deck" type="MeshInstance3D" parent="%s_Roof"]' % NAME + '\nmesh = ExtResource("m_deck")\nmaterial_override = SubResource("%s")\n' % facade_mat)
N('[node name="%s" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_body")\nmaterial_override = SubResource("%s")\n' % ("Body", facade_mat))
# Everything inside is shown only while the doctor is in (InteriorCutaway): from outside it would show
# through the transparent parts of the art, above the lower roofs
INS = NAME + "_Inside"
N('[node name="%s" type="Node3D" parent="."]\n' % INS)
for nm, m, mt in (("Floor", "floor", "mt_floor"), ("InnerWall", "innerwall", "mt_wall"), ("Timber", "timber", "mt_beam")):
    N('[node name="%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("%s")\n' % (nm, INS, m, mt))
N('[node name="Furniture" type="Node3D" parent="%s"]\n' % INS)
if timber_low_fn:
    # <Name>_Lower: shown only while the doctor is inside downstairs (InteriorCutaway)
    N('[node name="%s_Lower" type="Node3D" parent="%s"]\n' % (NAME, INS))
    N('[node name="TimberLower" type="MeshInstance3D" parent="%s/%s_Lower"]\nmesh = ExtResource("m_timberlow")\nmaterial_override = SubResource("mt_beam")\n' % (INS, NAME))
if UP:
    N('[node name="%s_Upper" type="Node3D" parent="%s"]\n' % (NAME, INS))
    for nm, (fn, mt, parent) in up_meshes.items():
        mtn = ("mt_" + fronts[int(mt[5:])][1].replace(".png", "")) if mt.startswith("PLANE") else mt
        par = (INS + "/" + NAME + "_Upper") if parent == "Upper" else INS
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("%s")\n' % (nm.title().replace("_", ""), par, nm, mtn))
    # front pieces standing out from the wall (a porch) come back upstairs with the lower facade
    if timber_up_fn:
        N('[node name="TimberUpperWall" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_timberupw")\nmaterial_override = SubResource("mt_beam")\n' % (INS + "/" + NAME + "_Upper"))
    if DECK:
        N('[node name="DeckUp" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_deck")\nmaterial_override = SubResource("%s")\n' % (INS + "/" + NAME + "_Upper", facade_mat))
    for ki in range(len(KEEP)):
        N('[node name="Keep%d" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_keep%d")\nmaterial_override = SubResource("%s")\n' % (ki, INS + "/" + NAME + "_Upper", ki, facade_mat))
    for i in UP.get("show_upstairs", []):
        N('[node name="UpstairsPlane%d" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
          % (i, INS + "/" + NAME + "_Upper", i, fronts[i][1].replace(".png", "")))
for bi, b, front, top in BLOCKS:
    N('[node name="%sFront" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_block%df")\nmaterial_override = SubResource("mt_block%d")\n' % (b["name"], INS, bi, bi))
    N('[node name="%sTop" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_block%dt")\nmaterial_override = SubResource("%s")\n' % (b["name"], INS, bi, ("mt_block%dtop" % bi) if b.get("top_tile") else "mt_wall"))
    shapes.append((b["name"], b["x0"], b["x1"], 0, b["height"], b["z_back"], b["z_front"]))
    if b.get("flame"):
        fx_, fy_, fz_, fw_, fh_ = b["flame"]
        S('[sub_resource type="QuadMesh" id="q_flame%d"]\nsize = Vector2(%.4f, %.4f)\n' % (bi, fw_, fh_))
        N('[node name="%sFire" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_flame%d")\nsurface_material_override/0 = SubResource("mt_flame")\n'
          % (b["name"], INS, tf(fx_, fy_, fz_), bi))
    if b.get("light"):
        lx, ly, lz = b["light"]
        N('[node name="%sGlow" type="OmniLight3D" parent="%s"]\ntransform = %s\nlight_color = Color(1, 0.62, 0.3, 1)\nlight_energy = 0.9\nomni_range = 3.0\nshadow_enabled = false\n'
          % (b["name"], INS, tf(lx, ly, lz)))
furniture = list(SPEC["furniture"])
if SPEC.get("door_rug", True):
    furniture.append({"name": "DoorRug", "prop": "rug", "flat": True, "y": 0.025, "x": (d0 + d1) / 2, "z": -0.42})
for f in furniture:
    lift = UP["height"] if (UP and f.get("upper")) else 0.0
    fpar = (INS + "/" + NAME + "_Upper") if (UP and f.get("upper")) else (INS + "/Furniture")
    w, h = props[f["prop"]]
    qw = w / 32.0 * FURN
    if f.get("flat"):
        qh = h / 32.0 / SIN * FURN
        S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, qh))
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s")\n'
          % (f["name"], fpar, tf(f["x"], f.get("y", 0.36) + lift, f["z"], True), f["name"], f["prop"]))
    else:
        qh = h / 32.0 / COS * FURN
        S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, qh))
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s")\n'
          % (f["name"], fpar, tf(f["x"], qh / 2 + lift, f["z"]), f["name"], f["prop"]))
    if f.get("box"):
        bx0, bx1, bz0, bz1, bh = f["box"]
        shapes.append((f["name"], bx0, bx1, lift, lift + bh, bz0, bz1))

# ---------- collision ----------
WALL = 5.4 if UP else 3.2
FZ_ = UP.get("front_z", 0.0) if UP else 0.0
FH = UP["height"] if (UP and FZ_ > 0) else WALL      # height of the ground floor front
shapes += [("Back", xw0, xw1, 0, WALL, -D, ZB), ("West", xw0, XI0, 0, WALL, max(0.15, FZ_ + 0.15), -D),
           ("FrontLeft", xw0, d0, 0, FH, 0.15, -0.15), ("FrontRight", d1, xw1, 0, FH, 0.15, -0.15)]
if FZ_ > 0:
    shapes.append(("UpperFront", xw0, xw1, UP["height"], WALL, FZ_ + 0.15, FZ_ - 0.15))
if DECK:
    # a door from the upper room out to the balcony through the east wall; the balcony's floor and rails
    ga, gb = DECK_Z[1], DECK_Z[0]                 # open all along the balcony
    H_ = DECK["y"]
    shapes += [("East", XI1, xw1, 0, H_, max(0.15, FZ_ + 0.15), -D),
               ("EastUpFront", XI1, xw1, H_, WALL, max(0.15, FZ_ + 0.15), ga), ("EastUpBack", XI1, xw1, H_, WALL, gb, -D),
               ("DeckFloor", xw1, DECK_X1, H_ - 0.2, H_, DECK_Z[0], DECK_Z[1]),
               ("DeckRailOut", DECK_X1 - 0.1, DECK_X1, H_, H_ + 1.0, DECK_Z[0], DECK_Z[1]),
               ("DeckRailFront", xw1, DECK_X1, H_, H_ + 1.0, DECK_Z[1] - 0.1, DECK_Z[1]),
               ("DeckRailBack", xw1, DECK_X1, H_, H_ + 1.0, DECK_Z[0], DECK_Z[0] + 0.1)]
else:
    shapes.append(("East", XI1, xw1, 0, WALL, max(0.15, FZ_ + 0.15), -D))
if UP:
    if FZ_ <= 0:
        shapes.append(("UpperDoor", d0, d1, UP["height"] + 0.5, WALL, 0.15, -0.15))
    shapes += up_shapes
for i, (a, b, za, zb) in enumerate(SPEC.get("posts", [])):
    shapes.append(("Post%d" % i, px(a), px(b), 0, 2.5, za, zb))
if SPEC.get("smoke_px"):
    sx, srow = SPEC["smoke_px"]
    t = (re - srow) / re
    sy, sz = ye + t * (yt - ye), ze + t * (-D - ze)
    S('[sub_resource type="QuadMesh" id="q_smoke"]\nsize = Vector2(0.9, 3.2)\n')
    N('[node name="ChimneySmoke" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = SubResource("q_smoke")\nsurface_material_override/0 = SubResource("mt_smoke")\n'
      % tf(px(sx), sy + 1.6, sz + 0.05))
N('[node name="Walls" type="StaticBody3D" parent="."]\n')
for nm, xa, xb, ya, yb, za, zb in shapes:
    S('[sub_resource type="BoxShape3D" id="b_%s"]\nsize = Vector3(%.4f, %.4f, %.4f)\n' % (nm, abs(xb - xa), abs(yb - ya), abs(zb - za)))
    N('[node name="%s" type="CollisionShape3D" parent="Walls"]\ntransform = %s\nshape = SubResource("b_%s")\n'
      % (nm, tf((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), nm))

for nm, pts in conv:
    S('[sub_resource type="ConvexPolygonShape3D" id="c_%s"]\npoints = PackedVector3Array(%s)\n' % (nm, ", ".join("%.4f, %.4f, %.4f" % p for p in pts)))
    N('[node name="%s" type="CollisionShape3D" parent="Walls"]\nshape = SubResource("c_%s")\n' % (nm, nm))
text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes)
open(os.path.join(OUT, NAME + "2D.tscn"), "w").write(text)
door_x = (d0 + d1) / 2
info = {"W": round(W, 3), "xw0": round(xw0, 3), "xw1": round(xw1, 3), "D": D, "eave": round(ye, 3), "ridge": round(yt, 3),
        "door_x": round(door_x, 3), "room": [round(XI0, 3), round(XI1, 3), round(ZB, 3)]}
if UP: info["upper"] = info_up
if DECK: info["deck_z"] = [round(DECK_Z[0], 3), round(DECK_Z[1], 3)]
print(json.dumps(info))
