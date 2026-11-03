# Builds the 2D bakery (Padaria2D.tscn + its meshes) from one layout, in the building's local units.
# x is widened by KX against the facade art; the town scales the whole node by 1.4.
import math, os, sys
OUT = sys.argv[1]
SRC = os.path.join(OUT, "src_unscaled")
KX = 1.15
COS, SIN = math.cos(math.radians(50)), math.sin(math.radians(50))
H = 2.1                       # upper floor level (2.94 m in town)
X0, X1 = -4.015625 * KX, 3.890625 * KX
T = 0.3 * KX                  # side wall thickness
XI0, XI1 = X0 + T, X1 - T     # inside faces of the side walls
ZB = -3.721033                # inside face of the back wall
WALL_H = 4.66
LAND_X = -3.473               # landing (top of the stairs) runs XI0..LAND_X
FURN = 1 / 1.4                # furniture keeps its real size: the town scales the building by 1.4
STAIR_FRONT = ZB + 1.0        # the stairs run along the back wall, 1.4 m wide in town
LAND_Z = STAIR_FRONT          # landing / stairwell front, flush with the stairs
RAMP_LOW = LAND_X + 2.7       # foot of the stairs
STEPS = 14

def wobj(name, faces, normals):
    """faces: list of (verts[4], uvs[4], normal_index)"""
    L = ["# Pallbrook 2D building part: padaria_%s" % name, "o padaria_%s" % name]
    V, U, F = [], [], []
    for vs, uvs, n in faces:
        b = len(V)
        V += vs; U += uvs
        F.append("f " + " ".join("%d/%d/%d" % (b + i + 1, b + i + 1, n) for i in range(4)))
    L += ["v %.6f %.6f %.6f" % v for v in V] + ["vt %.6f %.6f" % u for u in U]
    L += ["vn %s" % n for n in normals] + ["s 0"] + F
    open(os.path.join(OUT, "padaria_%s.obj" % name.lower()), "w").write("\n".join(L) + "\n")

def stretch(name):
    out = []
    for line in open(os.path.join(SRC, "padaria_%s.obj" % name)):
        if line.startswith("v "):
            x, y, z = map(float, line.split()[1:])
            line = "v %.6f %.6f %.6f\n" % (x * KX, y, z)
        out.append(line)
    open(os.path.join(OUT, "padaria_%s.obj" % name), "w").write("".join(out))

for n in ("front", "roof", "body", "innerwall"):
    stretch(n)

def floor_rect(a, b, zb, zf, y):
    return ([(a, y, zf), (b, y, zf), (b, y, zb), (a, y, zb)],
            [(a / 3.0, -zf / 3.0), (b / 3.0, -zf / 3.0), (b / 3.0, -zb / 3.0), (a / 3.0, -zb / 3.0)], 1)

wobj("Floor", [floor_rect(X0, X1, -3.761033, 0.0, 0.02)], ["0 1 0"])
# Upper floor: the front part and the back strip right of the stairwell
wobj("UpperFloor", [floor_rect(XI0, XI1, LAND_Z, 0.0, H + 0.01),
                    floor_rect(RAMP_LOW, XI1, ZB, LAND_Z, H + 0.01)], ["0 1 0"])
# The landing at the top of the stairs: a wooden top and a stone front, always shown
wobj("LandingTop", [floor_rect(XI0, LAND_X, ZB, LAND_Z, H + 0.012)], ["0 1 0"])
lw = (LAND_X - XI0) * 32 / 253.0          # share of the wall texture's width
lh = H * COS * 32 / 97.0                  # share of its height
wobj("LandingFront", [([(XI0, 0, LAND_Z), (LAND_X, 0, LAND_Z), (LAND_X, H, LAND_Z), (XI0, H, LAND_Z)],
                       [(0, 1 - lh), (lw, 1 - lh), (lw, 1), (0, 1)], 1)], ["0 0 1"])
# The stairs, built as real steps: stone treads, and the stepped side facing the room
dx, dy = (RAMP_LOW - LAND_X) / STEPS, H / STEPS
treads, side = [], []
for i in range(STEPS):
    xr, xl, y = RAMP_LOW - i * dx, RAMP_LOW - (i + 1) * dx, (i + 1) * dy
    treads.append(([(xl, y, STAIR_FRONT), (xr, y, STAIR_FRONT), (xr, y, ZB), (xl, y, ZB)],
                   [(0, 0), (1, 0), (1, 1), (0, 1)], 1))
    u = lambda x: (x - X0) / (X1 - X0)
    side.append(([(xl, 0, STAIR_FRONT), (xr, 0, STAIR_FRONT), (xr, y, STAIR_FRONT), (xl, y, STAIR_FRONT)],
                 [(u(xl), 0), (u(xr), 0), (u(xr), y / WALL_H), (u(xl), y / WALL_H)], 1))
wobj("StairTreads", treads, ["0 1 0"])
wobj("StairSide", side, ["0 0 1"])

# Railings: wooden beams and posts. tile_rail_wood.png is two pixels: dark wood (front faces), light (tops)
RAIL_H = 0.9 / 1.4            # a hand rail 0.9 m high in town
def beam(faces, xa, ya, xb, yb, zf, t=0.07, d=0.07):
    if xa > xb: xa, ya, xb, yb = xb, yb, xa, ya
    faces.append(([(xa, ya - t, zf), (xb, yb - t, zf), (xb, yb, zf), (xa, ya, zf)], [(0.25, 0.5)] * 4, 2))
    faces.append(([(xa, ya, zf), (xb, yb, zf), (xb, yb, zf - d), (xa, ya, zf - d)], [(0.75, 0.5)] * 4, 1))
def post(faces, x, y0, y1, zf, w=0.07):
    beam(faces, x - w / 2, y1, x + w / 2, y1, zf, t=y1 - y0, d=w)
def top_strip(faces, x, z0, z1, y, w=0.07):
    faces.append(([(x - w / 2, y, z0), (x + w / 2, y, z0), (x + w / 2, y, z1), (x - w / 2, y, z1)], [(0.75, 0.5)] * 4, 1))
line = lambda x: dy / 2 + H * (RAMP_LOW - x) / (RAMP_LOW - LAND_X)   # through the middle of the steps
RZ = STAIR_FRONT + 0.05
rail = []
beam(rail, RAMP_LOW - dx / 2, line(RAMP_LOW - dx / 2) + RAIL_H, LAND_X + dx / 2, line(LAND_X + dx / 2) + RAIL_H, RZ)
for i in (0, STEPS // 2, STEPS - 1):
    x = RAMP_LOW - (i + 0.5) * dx
    post(rail, x, (i + 1) * dy, line(x) + RAIL_H, RZ)
wobj("Railing", rail, ["0 1 0", "0 0 1"])
# Round the stairwell upstairs: along its front, and its right side (seen from above as a top rail)
up = []
beam(up, LAND_X + 0.3, H + RAIL_H, RAMP_LOW, H + RAIL_H, RZ)
for x in (LAND_X + 0.3, (LAND_X + RAMP_LOW) / 2, RAMP_LOW):
    post(up, x, H, H + RAIL_H, RZ)
top_strip(up, RAMP_LOW, STAIR_FRONT, ZB, H + RAIL_H)
wobj("UpperRailing", up, ["0 1 0", "0 0 1"])
# Upstairs the cut walls show timber, like the framed upper storey outside: beams on top of the side
# and back walls, the side wall ends above the floor, and the sill on top of the lower front wall.
# tile_beam.png repeats every 0.5 local units along a beam.
BW = 0.5
tb = []
def tq(vs, along):            # along: per vertex, distance along the beam
    tb.append((vs, [(a / BW, v) for a, v in along], 0))
for a, b in ((X0, XI0), (XI1, X1)):
    y = WALL_H + 0.005
    tb.append(([(a, y, -0.015), (b, y, -0.015), (b, y, ZB - 0.3), (a, y, ZB - 0.3)],
               [(0, 0), (0, 1), (-ZB / BW, 1), (-ZB / BW, 0)], 1))            # side wall top, grain along z
    tb.append(([(a, H, -0.015), (b, H, -0.015), (b, WALL_H, -0.015), (a, WALL_H, -0.015)],
               [(0, 0), (0, 1), ((WALL_H - H) / BW, 1), ((WALL_H - H) / BW, 0)], 2))  # end above the floor
y = WALL_H + 0.005
tb.append(([(XI0, y, ZB), (XI1, y, ZB), (XI1, y, ZB - 0.3), (XI0, y, ZB - 0.3)],
           [(XI0 / BW, 0), (XI1 / BW, 0), (XI1 / BW, 1), (XI0 / BW, 1)], 1))     # back wall top
tb.append(([(X0, H + 0.02, -0.005), (X1, H + 0.02, -0.005), (X1, H + 0.02, -0.33), (X0, H + 0.02, -0.33)],
           [(X0 / BW, 0), (X1 / BW, 0), (X1 / BW, 1), (X0 / BW, 1)], 1))         # sill on the lower front wall
for i, (vs, uvs, n) in enumerate(tb):
    if n == 0: tb[i] = (vs, uvs, 1)
wobj("Timber", tb, ["0 1 0", "0 0 1"])
# Upstairs, the lower storey of the facade comes back so the shop below doesn't show through
fv = 0.473171 * H / 4.715788
wobj("LowerFront", [([(X0, 0, 0.01), (X1, 0, 0.01), (X1, H, 0.01), (X0, H, 0.01)],
                     [(0.025830, 0), (0.959410, 0), (0.959410, fv), (0.025830, fv)], 1)], ["0 0 1"])
# Cut side walls seen from inside: stone tops and the front ends
cap_v = 9.6 / 97
sw = []
for a, b in ((X0, XI0), (XI1, X1)):
    sw.append(([(a, WALL_H, -0.02), (b, WALL_H, -0.02), (b, WALL_H, ZB), (a, WALL_H, ZB)],
               [(0, 1 - cap_v), (0, 1), (0.36, 1), (0.36, 1 - cap_v)], 1))
    sw.append(([(a, 0, -0.02), (b, 0, -0.02), (b, WALL_H, -0.02), (a, WALL_H, -0.02)],
               [(0.5, 0), (0.538, 0), (0.538, 0.98), (0.5, 0.98)], 2))
wobj("SideWalls", sw, ["0 1 0", "0 0 1"])

# ---------- the scene ----------
ext, sub, nodes = [], [], []
def E(kind, path, rid): ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
def S(text): sub.append(text)
def N(text): nodes.append(text)
def tf(x, y, z, flat=False):
    b = "1, 0, 0, 0, 0, 1, 0, -1, 0" if flat else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return "Transform3D(%s, %.4f, %.4f, %.4f)" % (b, x, y, z)

R = "res://assets/buildings2d/"
E("Shader", R + "sprite_surface.gdshader", "sh_sprite")
E("Shader", R + "tile_surface.gdshader", "sh_tile")
E("Texture2D", R + "padaria/padaria_facade.png", "tx_facade")
E("Texture2D", R + "tile_wood_floor.png", "tx_floor")
E("Texture2D", R + "padaria/padaria_innerwall.png", "tx_wall")
E("Texture2D", R + "tile_stair_tread.png", "tx_tread")
E("Texture2D", R + "tile_rail_wood.png", "tx_rail")
E("Texture2D", R + "tile_beam.png", "tx_beam")
for m in ("front", "roof", "body", "floor", "innerwall", "sidewalls", "upperfloor", "landingtop", "landingfront", "stairtreads", "stairside", "railing", "upperrailing", "lowerfront", "timber"):
    E("ArrayMesh", R + "padaria/padaria_%s.obj" % m, "m_" + m)

def mat(rid, shader, tex):
    S('[sub_resource type="ShaderMaterial" id="%s"]\nshader = ExtResource("%s")\nshader_parameter/tex = ExtResource("%s")\n'
      'shader_parameter/lit_share = 0.5\nshader_parameter/own_light = 0.85\n' % (rid, shader, tex))
mat("mt_facade", "sh_sprite", "tx_facade")
mat("mt_floor", "sh_tile", "tx_floor")
mat("mt_wall", "sh_sprite", "tx_wall")
mat("mt_tread", "sh_sprite", "tx_tread")
mat("mt_rail", "sh_sprite", "tx_rail")
mat("mt_beam", "sh_tile", "tx_beam")

PROPS = {  # name: (file, px w, px h)
    "table": ("prop_table.png", 82, 45), "bed": ("prop_bed_real.png", 32, 48),
    "stack": ("prop_barrel_stack.png", 60, 54), "barrel_a": ("prop_barrel_a.png", 30, 38),
    "barrel_b": ("prop_barrel_b.png", 30, 38), "sack_a": ("prop_sack_a.png", 23, 29),
    "sack_b": ("prop_sack_b.png", 24, 30), "rug": ("prop_rug.png", 38, 16),
}
for k, (f, w, h) in PROPS.items():
    E("Texture2D", R + "props/" + f, "tx_" + k)
    mat("mt_" + k, "sh_sprite", "tx_" + k)

def sprite(parent, name, prop, x, front_z, base_y=0.0, flat=False, flat_y=None, center_z=None):
    f, w, h = PROPS[prop]
    k = KX if prop == "stairs" else FURN
    qw = w / 32.0 * k
    if prop == "stairs":
        # Leaning from the foot of the front to the top of the back: it projects exactly like the upright
        # art, but anyone climbing in front of the back of the stairs is drawn in front of them
        dy, dz = H, ZB - front_z
        ln = math.hypot(dy, dz); uy, uz = dy / ln, dz / ln
        S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (name, qw, ln))
        basis = "1, 0, 0, 0, %.4f, %.4f, 0, %.4f, %.4f" % (uy, -uz, uz, uy)
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = Transform3D(%s, %.4f, %.4f, %.4f)\nmesh = SubResource("q_%s")\n'
          'surface_material_override/0 = SubResource("mt_%s")\n' % (name, parent, basis, x, H / 2, (front_z + ZB) / 2, name, prop))
        return
    if flat:
        qh = h / 32.0 / SIN * FURN
        S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (name, qw, qh))
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\n'
          'surface_material_override/0 = SubResource("mt_%s")\n' % (name, parent, tf(x, flat_y, center_z, True), name, prop))
    else:
        qh = h / 32.0 / COS * FURN
        S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (name, qw, qh))
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\n'
          'surface_material_override/0 = SubResource("mt_%s")\n' % (name, parent, tf(x, base_y + qh / 2, front_z), name, prop))

boxes = []
def box(name, cx, cy, cz, sx, sy, sz, basis=None):
    S('[sub_resource type="BoxShape3D" id="b_%s"]\nsize = Vector3(%.4f, %.4f, %.4f)\n' % (name, sx, sy, sz))
    t = tf(cx, cy, cz) if basis is None else "Transform3D(%s, %.4f, %.4f, %.4f)" % (basis, cx, cy, cz)
    boxes.append('[node name="%s" type="CollisionShape3D" parent="Walls"]\ntransform = %s\nshape = SubResource("b_%s")\n' % (name, t, name))
def box_span(name, xa, xb, ya, yb, za, zb):
    box(name, (xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2, abs(xb - xa), abs(yb - ya), abs(zb - za))

N('[node name="Padaria2D" type="Node3D"]\n')
for n, m, mt in (("Padaria_Front", "front", "facade"), ("Padaria_Roof", "roof", "facade"), ("Body", "body", "facade"),
                 ("Floor", "floor", "floor"), ("InnerWall", "innerwall", "wall"), ("SideWalls", "sidewalls", "wall"),
                 ("LandingTop", "landingtop", "floor"), ("LandingFront", "landingfront", "wall"),
                 ("StairTreads", "stairtreads", "tread"), ("StairSide", "stairside", "wall"), ("Railing", "railing", "rail")):
    N('[node name="%s" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("mt_%s")\n' % (n, m, mt))

# Ground floor. Upright sprites stand at the front of their footprint; their art shows the depth behind it.
N('[node name="Furniture" type="Node3D" parent="."]\n')
sprite("Furniture", "Counter", "table", 1.6, None, flat=True, flat_y=0.57, center_z=-1.4)
sprite("Furniture", "BarrelStack", "stack", 3.3, ZB + 0.71)
sprite("Furniture", "Barrel", "barrel_a", 3.7, -0.3)
sprite("Furniture", "SackB", "sack_b", 3.0, -0.3)
sprite("Furniture", "DoorRug", "rug", -3.32, None, flat=True, flat_y=0.025, center_z=-0.42)   # marks the way out
# Upper floor, shown only while the doctor is up there
N('[node name="Padaria_Upper" type="Node3D" parent="."]\n')
N('[node name="UpperFloor" type="MeshInstance3D" parent="Padaria_Upper"]\nmesh = ExtResource("m_upperfloor")\nmaterial_override = SubResource("mt_floor")\n')
N('[node name="UpperRailing" type="MeshInstance3D" parent="Padaria_Upper"]\nmesh = ExtResource("m_upperrailing")\nmaterial_override = SubResource("mt_rail")\n')
N('[node name="Timber" type="MeshInstance3D" parent="Padaria_Upper"]\nmesh = ExtResource("m_timber")\nmaterial_override = SubResource("mt_beam")\n')
N('[node name="LowerFront" type="MeshInstance3D" parent="Padaria_Upper"]\nmesh = ExtResource("m_lowerfront")\nmaterial_override = SubResource("mt_facade")\n')
sprite("Padaria_Upper", "Bed", "bed", 3.6, None, flat=True, flat_y=H + 0.36, center_z=-2.9)
sprite("Padaria_Upper", "UpBarrel", "barrel_b", 1.4, ZB + 0.67, base_y=H)
sprite("Padaria_Upper", "UpSack", "sack_a", 2.3, ZB + 0.5, base_y=H)

# Collision
box_span("Back", X0, X1, 0, 5.4, ZB, ZB - 0.3)
box_span("West", X0, X0 + 0.3, 0, 5.4, 0.15, ZB - 0.3)
box_span("East", X1 - 0.3, X1, 0, 5.4, 0.15, ZB - 0.3)
DOOR_A, DOOR_B = -4.06, -2.58
box_span("FrontLeft", X0 - 0.02, DOOR_A, 0, 5.4, 0.15, -0.15)
box_span("FrontRight", DOOR_B, X1 + 0.02, 0, 5.4, 0.15, -0.15)
box_span("UpperDoor", DOOR_A, DOOR_B, 2.6, 5.4, 0.15, -0.15)
box_span("Counter", 0.7, 2.5, 0, 0.7, -1.05, -1.75)
box_span("Stack", 2.65, 3.95, 0, 1, ZB, ZB + 0.71)
box_span("Barrel", 3.38, 4.02, 0, 0.8, -0.3, -0.95)
box_span("SackB", 2.75, 3.25, 0, 0.7, -0.3, -0.75)
box_span("Landing", XI0 - 0.05, LAND_X, 0, H, ZB, LAND_Z)
# The stairs: a solid wedge whose slope runs through the middle of the steps
run = RAMP_LOW - LAND_X
th = math.atan2(H, run)
prof = [(RAMP_LOW + dx / 2, 0), (LAND_X, 0), (LAND_X, H), (LAND_X + dx / 2, H)]
pts = ", ".join("%.4f, %.4f, %.4f" % (x, y, z) for z in (STAIR_FRONT, ZB) for x, y in prof)
S('[sub_resource type="ConvexPolygonShape3D" id="c_Stairs"]\npoints = PackedVector3Array(%s)\n' % pts)
boxes.append('[node name="Stairs" type="CollisionShape3D" parent="Walls"]\nshape = SubResource("c_Stairs")\n')
box_span("Railing", LAND_X + 0.3, RAMP_LOW, H - 0.2, H + 1.0, STAIR_FRONT, STAIR_FRONT + 0.1)
box_span("RailingSide", RAMP_LOW, RAMP_LOW + 0.1, H - 0.2, H + 1.0, ZB, STAIR_FRONT + 0.1)
# Along the open side of the stairs, so nobody steps off them
rp = [(RAMP_LOW, 0), (LAND_X, H), (LAND_X, H + 1.0), (RAMP_LOW, 1.0)]
pts = ", ".join("%.4f, %.4f, %.4f" % (x, y, z) for z in (STAIR_FRONT - 0.02, STAIR_FRONT + 0.08) for x, y in rp)
S('[sub_resource type="ConvexPolygonShape3D" id="c_StairRail"]\npoints = PackedVector3Array(%s)\n' % pts)
boxes.append('[node name="StairRail" type="CollisionShape3D" parent="Walls"]\nshape = SubResource("c_StairRail")\n')
box_span("SlabA", XI0, XI1, H - 0.2, H, LAND_Z, 0)
box_span("SlabB", RAMP_LOW, XI1, H - 0.2, H, ZB, LAND_Z)
box_span("UpBed", 3.26, 3.94, H, H + 0.4, -3.58, -2.22)
box_span("UpBarrel", 1.1, 1.7, H, H + 0.8, ZB, ZB + 0.67)
box_span("UpSack", 2.05, 2.55, H, H + 0.7, ZB, ZB + 0.5)
N('[node name="Walls" type="StaticBody3D" parent="."]\n')

text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes) + "\n" + "\n".join(boxes)
open(os.path.join(OUT, "Padaria2D.tscn"), "w").write(text)
print("stairs %.1f deg, run %.2f, %d steps; ramp low %.3f, front %.3f" % (math.degrees(th), run, STEPS, RAMP_LOW, STAIR_FRONT))
