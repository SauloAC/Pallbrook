"""Shared pieces for the 2D-on-volume buildings: the projection, the building's measurements, and writing meshes.

Local units: the town scales each building node by TOWN_SCALE. x east, y up, z south; z = 0 is the door's wall,
x = 0 the middle of the facade art. Camera: orthographic, pitched 50 deg, no yaw; art at 32 px per unit.
A point (y, z) on a front plane whose ground sits on image row `base` (plane at depth zf) is drawn
on row  base - 32 * (y*cos50 + (zf - z)*sin50).
"""
import math, os
from PIL import Image

COS, SIN = math.cos(math.radians(50)), math.sin(math.radians(50))
TOWN_SCALE = 1.4                 # every 2D building node is scaled by this in Cidade.tscn
FURN = 1 / TOWN_SCALE            # furniture keeps its real size inside the scaled building
BW = 0.5                         # tile_beam.png repeats every BW local units along a beam
RES = "res://assets/buildings2d/"


class House:
    """A building's spec turned into measurements, plus the mesh files written so far."""

    def __init__(self, spec, out_dir, props_sizes):
        self.spec, self.out = spec, out_dir
        os.makedirs(out_dir, exist_ok=True)
        self.name = spec["name"]
        self.key = self.name.lower()
        self.res = RES + self.key + "/"
        self.props_sizes = props_sizes
        self.art = Image.open(spec["facade"]).convert("RGBA")
        self.iw, self.ih = self.art.size
        self.art.save(os.path.join(out_dir, self.key + "_facade.png"))
        self.kx = spec.get("stretch_x", 1.0)          # widen the building against its art
        self.W = self.iw / 32.0
        self.XL = -self.W / 2
        self.D = spec["depth"]
        self.xw0, self.xw1 = self.px(spec["wall_px"][0]), self.px(spec["wall_px"][1])
        t = spec.get("wall_t", 0.3)
        self.XI0, self.XI1, self.ZB = self.xw0 + t, self.xw1 - t, -self.D + t
        self.HIN = spec["room_height"]
        self.UP = spec.get("upper")
        self.DECK = spec.get("deck")
        self.FY = spec.get("floor_y", 0.0)           # a raised floor (a house on posts), in local units
        # a set-back part on the right (a lean-to): its front wall stands behind the main front
        self.NOTCH = spec.get("notch")
        if self.NOTCH:
            assert not self.DECK, "a notch and a balcony on the same house are not supported"
            self.xn, self.zn, self.wt = self.px(self.NOTCH["x_px"]), self.NOTCH["z"], t
        self.d0, self.d1 = self.px(spec["door_px"][0]), self.px(spec["door_px"][1])
        self.door_x = (self.d0 + self.d1) / 2
        tw, th = spec.get("inner_wall_tile_px", (32, 32))
        self.wall_tile = (tw, th)
        self.su, self.sv = 32.0 / tw, 32.0 / th

    # projection helpers
    def px(self, p):
        """x of a column of the facade art"""
        return (self.XL + p / 32.0) * self.kx

    def uv(self, p, row):
        return (p / self.iw, 1 - row / self.ih)

    @staticmethod
    def y_on(plane, row):
        """height on a front plane of a row of the art"""
        return (plane["base"] - row) / 32.0 / COS

    def plane(self, i):
        return self.spec["planes"][i]

    # writing meshes
    def obj(self, name, faces, normals):
        """faces: (vertices, uvs, normal index); returns the file name"""
        L = ["# Pallbrook 2D building part: %s_%s" % (self.key, name), "o %s_%s" % (self.key, name)]
        V, U, F = [], [], []
        for vs, uvs, n in faces:
            b = len(V); V += vs; U += uvs
            F.append("f " + " ".join("%d/%d/%d" % (b + i + 1, b + i + 1, n) for i in range(len(vs))))
        L += ["v %.6f %.6f %.6f" % v for v in V] + ["vt %.6f %.6f" % u for u in U]
        L += ["vn %s" % n for n in normals] + ["s 0"] + F
        fn = "%s_%s.obj" % (self.key, name.lower())
        open(os.path.join(self.out, fn), "w").write("\n".join(L) + "\n")
        return fn


def rect_floor(a, b, zb, zf, y, tile=3.0):
    """a level rectangle facing up, tiled every `tile` units"""
    return ([(a, y, zf), (b, y, zf), (b, y, zb), (a, y, zb)],
            [(a / tile, -zf / tile), (b / tile, -zf / tile), (b / tile, -zb / tile), (a / tile, -zb / tile)], 1)


def tf(x, y, z, flat=False):
    b = "1, 0, 0, 0, 0, 1, 0, -1, 0" if flat else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return "Transform3D(%s, %.4f, %.4f, %.4f)" % (b, x, y, z)
