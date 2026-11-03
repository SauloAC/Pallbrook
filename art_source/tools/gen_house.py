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
for a, b in ((xw0, XI0), (XI1, xw1)):
    tb.append(([(a, HIN, -0.015), (b, HIN, -0.015), (b, HIN, -D), (a, HIN, -D)],
               [(0, 0), (0, 1), (D / BW, 1), (D / BW, 0)], 1))
    tb.append(([(a, 0, -0.015), (b, 0, -0.015), (b, HIN, -0.015), (a, HIN, -0.015)],
               [(0, 0), (0, 1), (HIN / BW, 1), (HIN / BW, 0)], 2))
tb.append(([(XI0, HIN, ZB), (XI1, HIN, ZB), (XI1, HIN, -D), (XI0, HIN, -D)],
           [(XI0 / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), (XI0 / BW, 1)], 1))
timber_fn = obj("Timber", tb, ["0 1 0", "0 0 1"])

UP = SPEC.get("upper")
up_meshes, up_shapes, conv = {}, [], []
if UP:
    H = UP["height"]
    LAND_X = XI0 + UP.get("landing", 0.8)
    SF = ZB + UP.get("stair_depth", 1.0)           # front of the stairs = front of the stairwell
    RAMP_LOW = LAND_X + UP.get("run", 2.7)
    STEPS = UP.get("steps", 14)
    dx, dy = (RAMP_LOW - LAND_X) / STEPS, H / STEPS
    treads, side = [], []
    stw, sth = UP.get("stair_wall_tile_px", (tw, th))
    su2, sv2 = 32.0 / stw, 32.0 / sth
    STAIR_MT = "mt_stairwall" if UP.get("stair_wall_tile") else "mt_wall"
    for i in range(STEPS):
        xr, xl, y = RAMP_LOW - i * dx, RAMP_LOW - (i + 1) * dx, (i + 1) * dy
        treads.append(([(xl, y, SF), (xr, y, SF), (xr, y, ZB), (xl, y, ZB)], [(0, 0), (1, 0), (1, 1), (0, 1)], 1))
        side.append(([(xl, 0, SF), (xr, 0, SF), (xr, y, SF), (xl, y, SF)],
                     [(xl * su2, 0), (xr * su2, 0), (xr * su2, y * COS * sv2), (xl * su2, y * COS * sv2)], 1))
    up_meshes["stairtreads"] = (obj("StairTreads", treads, ["0 1 0"]), "mt_tread", "")
    up_meshes["stairside"] = (obj("StairSide", side, ["0 0 1"]), STAIR_MT, "")
    up_meshes["landingtop"] = (obj("LandingTop", [rect_floor(XI0, LAND_X, ZB, SF, H + 0.012)], ["0 1 0"]), "mt_floor", "")
    up_meshes["landingfront"] = (obj("LandingFront", [([(XI0, 0, SF), (LAND_X, 0, SF), (LAND_X, H, SF), (XI0, H, SF)],
        [(XI0 * su2, 0), (LAND_X * su2, 0), (LAND_X * su2, H * COS * sv2), (XI0 * su2, H * COS * sv2)], 1)], ["0 0 1"]), STAIR_MT, "")
    up_meshes["upperfloor"] = (obj("UpperFloor", [rect_floor(XI0, XI1, SF, 0.0, H + 0.01), rect_floor(RAMP_LOW, XI1, ZB, SF, H + 0.01)],
                                   ["0 1 0"]), "mt_floor", "Upper")
    RAIL_H = 0.9 / 1.4
    def beam(faces, xa, ya, xb, yb, zf, t=0.07, d=0.07):
        if xa > xb: xa, ya, xb, yb = xb, yb, xa, ya
        faces.append(([(xa, ya - t, zf), (xb, yb - t, zf), (xb, yb, zf), (xa, ya, zf)], [(0.25, 0.5)] * 4, 2))
        faces.append(([(xa, ya, zf), (xb, yb, zf), (xb, yb, zf - d), (xa, ya, zf - d)], [(0.75, 0.5)] * 4, 1))
    def post(faces, x, y0, y1, zf, w=0.07):
        beam(faces, x - w / 2, y1, x + w / 2, y1, zf, t=y1 - y0, d=w)
    line = lambda x: dy / 2 + H * (RAMP_LOW - x) / (RAMP_LOW - LAND_X)
    RZ = SF + 0.05
    rail = []
    beam(rail, RAMP_LOW - dx / 2, line(RAMP_LOW - dx / 2) + RAIL_H, LAND_X + dx / 2, line(LAND_X + dx / 2) + RAIL_H, RZ)
    for i in (0, STEPS // 2, STEPS - 1):
        x = RAMP_LOW - (i + 0.5) * dx
        post(rail, x, (i + 1) * dy, line(x) + RAIL_H, RZ)
    up_meshes["railing"] = (obj("Railing", rail, ["0 1 0", "0 0 1"]), "mt_rail", "")
    upr = []
    beam(upr, LAND_X + 0.3, H + RAIL_H, RAMP_LOW, H + RAIL_H, RZ)
    for x in (LAND_X + 0.3, (LAND_X + RAMP_LOW) / 2, RAMP_LOW):
        post(upr, x, H, H + RAIL_H, RZ)
    upr.append(([(RAMP_LOW - 0.035, H + RAIL_H, SF), (RAMP_LOW + 0.035, H + RAIL_H, SF), (RAMP_LOW + 0.035, H + RAIL_H, ZB),
                 (RAMP_LOW - 0.035, H + RAIL_H, ZB)], [(0.75, 0.5)] * 4, 1))
    up_meshes["upperrailing"] = (obj("UpperRailing", upr, ["0 1 0", "0 0 1"]), "mt_rail", "Upper")
    # upstairs the lower storey of the facade comes back over the shop below; a sill beam on top of it
    lp = SPEC["planes"][UP.get("lower_front_plane", 0)]
    rtop = lp["base"] - H * COS * 32
    up_meshes["lowerfront"] = (obj("LowerFront", [([(XL, 0, lp["z"] + 0.01), (-XL, 0, lp["z"] + 0.01), (-XL, H, lp["z"] + 0.01), (XL, H, lp["z"] + 0.01)],
        [uv(0, lp["base"]), uv(IW, lp["base"]), uv(IW, rtop), uv(0, rtop)], 1)], ["0 0 1"]), "FACADE", "Upper")
    ut = [([(xw0, H + 0.02, -0.005), (xw1, H + 0.02, -0.005), (xw1, H + 0.02, -0.33), (xw0, H + 0.02, -0.33)],
           [(xw0 / BW, 0), (xw1 / BW, 0), (xw1 / BW, 1), (xw0 / BW, 1)], 1)]
    up_meshes["uppertimber"] = (obj("UpperTimber", ut, ["0 1 0"]), "mt_beam", "Upper")
    # collision: the stairs as a solid wedge, rails, the upper floor round the stairwell
    prof = [(RAMP_LOW + dx / 2, 0), (LAND_X, 0), (LAND_X, H), (LAND_X + dx / 2, H)]
    conv.append(("Stairs", [(x, y, z) for z in (SF, ZB) for x, y in prof]))
    rp_ = [(RAMP_LOW, 0), (LAND_X, H), (LAND_X, H + 1.0), (RAMP_LOW, 1.0)]
    conv.append(("StairRail", [(x, y, z) for z in (SF - 0.02, SF + 0.08) for x, y in rp_]))
    up_shapes += [("Landing", XI0 - 0.05, LAND_X, 0, H, ZB, SF),
                  ("SlabA", XI0, XI1, H - 0.2, H, SF, 0), ("SlabB", RAMP_LOW, XI1, H - 0.2, H, ZB, SF),
                  ("Railing", LAND_X + 0.3, RAMP_LOW, H - 0.2, H + 1.0, SF, SF + 0.1),
                  ("RailingSide", RAMP_LOW, RAMP_LOW + 0.1, H - 0.2, H + 1.0, ZB, SF + 0.1)]
    info_up = {"H": H, "stairs_x": [round(LAND_X, 3), round(RAMP_LOW, 3)], "stairs_front": round(SF, 3)}

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
for nm, fn in (("roof", roof_fn), ("body", body_fn), ("floor", floor_fn), ("innerwall", wall_fn), ("timber", timber_fn)):
    E("ArrayMesh", RH + fn, "m_" + nm)
used = sorted(set(f["prop"] for f in SPEC["furniture"]))
for p in used:
    E("Texture2D", R + "props/prop_%s.png" % p, "tx_p_" + p)
    mat("mt_p_" + p, "sh_sprite", "tx_p_" + p)

N('[node name="%s2D" type="Node3D"]\n' % NAME)
N('[node name="%s_Front" type="Node3D" parent="."]\n' % NAME)
facade_mat = "mt_" + KEY + "_facade"
for i, (fn, tex) in enumerate(fronts):
    N('[node name="Plane%d" type="MeshInstance3D" parent="%s_Front"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
      % (i, NAME, i, tex.replace(".png", "")))
N('[node name="%s_Roof" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_roof")\nmaterial_override = SubResource("%s")\n' % (NAME, facade_mat))
N('[node name="%s" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_body")\nmaterial_override = SubResource("%s")\n' % ("Body", facade_mat))
# Everything inside is shown only while the doctor is in (InteriorCutaway): from outside it would show
# through the transparent parts of the art, above the lower roofs
INS = NAME + "_Inside"
N('[node name="%s" type="Node3D" parent="."]\n' % INS)
for nm, m, mt in (("Floor", "floor", "mt_floor"), ("InnerWall", "innerwall", "mt_wall"), ("Timber", "timber", "mt_beam")):
    N('[node name="%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("%s")\n' % (nm, INS, m, mt))
N('[node name="Furniture" type="Node3D" parent="%s"]\n' % INS)
if UP:
    N('[node name="%s_Upper" type="Node3D" parent="%s"]\n' % (NAME, INS))
    for nm, (fn, mt, parent) in up_meshes.items():
        mtn = facade_mat if mt == "FACADE" else mt
        par = (INS + "/" + NAME + "_Upper") if parent == "Upper" else INS
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("%s")\n' % (nm.title().replace("_", ""), par, nm, mtn))
    # front pieces standing out from the wall (a porch) come back upstairs with the lower facade
    for i in UP.get("show_upstairs", []):
        N('[node name="UpstairsPlane%d" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
          % (i, INS + "/" + NAME + "_Upper", i, fronts[i][1].replace(".png", "")))
for f in SPEC["furniture"]:
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
d0, d1 = px(SPEC["door_px"][0]), px(SPEC["door_px"][1])
shapes += [("Back", xw0, xw1, 0, WALL, -D, ZB), ("West", xw0, XI0, 0, WALL, 0.15, -D), ("East", XI1, xw1, 0, WALL, 0.15, -D),
           ("FrontLeft", xw0, d0, 0, WALL, 0.15, -0.15), ("FrontRight", d1, xw1, 0, WALL, 0.15, -0.15)]
if UP:
    shapes.append(("UpperDoor", d0, d1, UP["height"] + 0.5, WALL, 0.15, -0.15))
    shapes += up_shapes
for i, (a, b, za, zb) in enumerate(SPEC.get("posts", [])):
    shapes.append(("Post%d" % i, px(a), px(b), 0, 2.5, za, zb))
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
print(json.dumps(info))
