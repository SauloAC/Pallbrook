"""Puts a building together as a Godot scene: resources, the node tree the cutaway expects, and collision.

Node tree: <Name>2D / <Name>_Front (planes), <Name>_Roof, Body, <Name>_Inside (the room, shown only while the
doctor is in: Floor, InnerWall, Timber, Furniture, <Name>_Lower, <Name>_Upper), Walls; the chimney smoke goes with
the roof."""
import os
from .core import COS, SIN, FURN, RES as R, tf
from . import door as door_mod

SPLIT_HEAD_DEPTH = 1.37   # How far behind a split bed's foot its head stands (building units): as its picture was cut (furniture/finish.py)
SPLIT_BODY_Y = 0.36       # How high its body lies (building units: 0.5 m), under someone lying in it
SPLIT_SEAT_Y = 0.25       # A split pew's ("split": "seat") seat: under whoever sits on it (0.35 m)


def build(h):
    SPEC, UP, DECK, NAME, KEY = h.spec, h.UP, h.DECK, h.name, h.key
    RH, OUT, props = h.res, h.out, h.props_sizes
    DECK_Z, DECK_X1 = getattr(h, "DECK_Z", None), getattr(h, "DECK_X1", None)
    XI0, XI1, ZB, xw0, xw1, D, px = h.XI0, h.XI1, h.ZB, h.xw0, h.xw1, h.D, h.px
    re, ye, yt, ze = h.re, h.ye, h.yt, h.ze
    fronts, KEEP, deck_fn, roof_tex, roof_fn, body_fn = h.fronts, h.keep, h.deck_fn, h.roof_tex, h.roof_fn, h.body_fn
    floor_fn, wall_fn, timber_fn, timber_low_fn, timber_up_fn = h.floor_fn, h.wall_fn, h.timber_fn, h.timber_low_fn, h.timber_up_fn
    BLOCKS, up_meshes, up_shapes, conv = h.blocks, h.up_meshes, h.up_shapes, h.conv
    d0, d1 = h.d0, h.d1
    DOOR_Z, DOOR = h.DOOR_Z, h.door
    DN, ZBN = (h.DN, h.ZBN) if h.NOTCH else (h.D, h.ZB)     # the set-back part's own depth
    NOTCH = h.NOTCH
    PLAN, PLAN_FLOORS = h.PLAN, h.plan_floors     # (h is reused below for a prop's height)
    NL = h.NOTCH_L                     # a left wing set back (see core.House)
    XNL, ZNL, WTL = (h.xnl, h.znl, h.wt) if NL else (None, None, None)
    FY = h.FY
    PORCH = getattr(h, "PORCH", None)
    XN, ZN, WT = (h.xn, h.zn, h.wt) if NOTCH else (None, None, None)
    # ---------- props ----------
    ext, sub, nodes, shapes = [], [], [], []
    def E(kind, path, rid):
        if not any('id="%s"]' % rid in e for e in ext):       # each resource once (two doors share some)
            ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
    def S(t):
        if t.startswith("[sub_resource") and t.split("\n")[0] in [u.split("\n")[0] for u in sub]:
            return
        sub.append(t)
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
    GROUND_MT = "mt_floor"
    if SPEC.get("floor_tile"):          # the ground floor in its own material (packed earth in a stable)
        E("Texture2D", R + SPEC["floor_tile"], "tx_ground"); mat("mt_ground", "sh_tile", "tx_ground"); GROUND_MT = "mt_ground"
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
        E("ArrayMesh", RH + timber_low_fn, "m_timberlow")
    if timber_up_fn:
        E("ArrayMesh", RH + timber_up_fn, "m_timberupw")
    if DECK:
        E("ArrayMesh", RH + deck_fn, "m_deck"); E("Texture2D", RH + roof_tex, "tx_roof"); mat("mt_roof", "sh_sprite", "tx_roof")
    if h.porch_fn:
        E("ArrayMesh", RH + h.porch_fn, "m_porch")
    if h.steps_fn:
        E("ArrayMesh", RH + h.steps_fn, "m_steps")
    if h.roofstays_fn:
        E("ArrayMesh", RH + h.roofstays_fn, "m_roofstays")
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
    used = sorted(set(f["prop"] for f in SPEC["furniture"] if not f.get("split")) | ({"rug"} if SPEC.get("door_rug", True) else set())
                  | set(f["prop"] + "_" + part for f in SPEC["furniture"] if f.get("split")
                        for part in (("foot", "body") if f["split"] == "seat" else ("foot", "body", "head"))))
    for p in used:
        E("Texture2D", R + "props/prop_%s.png" % p, "tx_p_" + p)
        mat("mt_p_" + p, "sh_sprite", "tx_p_" + p)

    N('[node name="%s2D" type="Node3D"]\n' % NAME)
    N('[node name="%s_Front" type="Node3D" parent="."]\n' % NAME)
    facade_mat = "mt_" + KEY + "_facade"
    STAYS = SPEC.get("stays", {}).get("planes", []) + SPEC.get("inside_planes", [])
    for i, (fn, tex) in enumerate(fronts):
        if i in STAYS:
            continue
        N('[node name="Plane%d" type="MeshInstance3D" parent="%s_Front"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
          % (i, NAME, i, tex.replace(".png", "")))
    door_mod.scene_nodes(h, h.door, E, S, N, mat, NAME + "_Front")
    door_mod.scene_nodes(h, h.door2, E, S, N, mat, NAME + "_Front")
    N('[node name="%s_Roof" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_roof")\nmaterial_override = SubResource("%s")\n' % (NAME, "mt_roof" if DECK else facade_mat))
    if DECK:
        # outside the balcony goes with the roof it was cut from; upstairs a copy shows (below, in _Upper)
        N('[node name="Deck" type="MeshInstance3D" parent="%s_Roof"]' % NAME + '\nmesh = ExtResource("m_deck")\nmaterial_override = SubResource("%s")\n' % facade_mat)
    if SPEC.get("stays"):   # beside the room, on show inside and out: its planes and its strip of roof
        N('[node name="Stays" type="Node3D" parent="."]\n')
        for i in STAYS:
            N('[node name="Plane%d" type="MeshInstance3D" parent="Stays"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
              % (i, i, fronts[i][1].replace(".png", "")))
        N('[node name="Roof" type="MeshInstance3D" parent="Stays"]\nmesh = ExtResource("m_roofstays")\nmaterial_override = SubResource("%s")\n' % facade_mat)
    if h.porch_fn:     # outside, always on show: you walk on it to the door
        N('[node name="Porch" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_porch")\nmaterial_override = SubResource("%s")\n' % facade_mat)
    if h.steps_fn:
        N('[node name="Steps" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_steps")\nmaterial_override = SubResource("%s")\n' % facade_mat)
    N('[node name="%s" type="MeshInstance3D" parent="."]\nmesh = ExtResource("m_body")\nmaterial_override = SubResource("%s")\n' % ("Body", facade_mat))
    # Everything inside is shown only while the doctor is in (InteriorCutaway): from outside it would show
    # through the transparent parts of the art, above the lower roofs
    INS = NAME + "_Inside"
    N('[node name="%s" type="Node3D" parent="."]\n' % INS)
    for nm, m, mt in (("Floor", "floor", GROUND_MT), ("InnerWall", "innerwall", "mt_wall"), ("Timber", "timber", "mt_beam")):
        # an open-fronted building (a shed) shows its floor from outside too, through the opening
        par = "." if (nm == "Floor" and SPEC.get("floor_outside")) else INS
        if nm == "Floor" and PLAN_FLOORS:      # a plan's floors: each its own tile, some on show from outside
            for fi, (ffn, ftile, fout) in enumerate(PLAN_FLOORS):
                fmt = "mt_floor"
                if ftile:
                    fmt = "mt_fl_" + ftile.replace(".png", "")
                    E("Texture2D", R + ftile, "tx_fl_" + ftile.replace(".png", "")); mat(fmt, "sh_tile", "tx_fl_" + ftile.replace(".png", ""))
                if fi:
                    E("ArrayMesh", RH + ffn, "m_floor%d" % fi)
                N('[node name="Floor%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_floor%s")\nmaterial_override = SubResource("%s")\n'
                  % (fi or "", "." if fout else INS, fi or "", fmt))
            continue
        N('[node name="%s" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_%s")\nmaterial_override = SubResource("%s")\n' % (nm, par, m, mt))
    for i in SPEC.get("inside_planes", []):
        N('[node name="Plane%d" type="MeshInstance3D" parent="%s"]\nmesh = ExtResource("m_front%d")\nmaterial_override = SubResource("mt_%s")\n'
          % (i, INS, i, fronts[i][1].replace(".png", "")))
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
        shapes.append((b["name"], b["x0"], b["x1"], h.FY, h.FY + b["height"], b["z_back"], b["z_front"]))
        if b.get("flame"):
            fx_, fy_, fz_, fw_, fh_ = b["flame"]
            S('[sub_resource type="QuadMesh" id="q_flame%d"]\nsize = Vector2(%.4f, %.4f)\n' % (bi, fw_, fh_))
            N('[node name="%sFire" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_flame%d")\nsurface_material_override/0 = SubResource("mt_flame")\n'
              % (b["name"], INS, tf(fx_, fy_ + h.FY, fz_), bi))
        if b.get("light"):
            lx, ly, lz = b["light"]
            N('[node name="%sGlow" type="OmniLight3D" parent="%s"]\ntransform = %s\nlight_color = Color(1, 0.62, 0.3, 1)\nlight_energy = %s\nomni_range = %s\nshadow_enabled = false\n'
              % (b["name"], INS, tf(lx, ly + h.FY, lz), repr(float(b.get("light_energy", 0.9))), repr(float(b.get("light_range", 3.0)))))
    furniture = list(SPEC["furniture"])
    if SPEC.get("door_rug", True):
        furniture.append({"name": "DoorRug", "prop": "rug", "flat": True, "y": 0.025, "x": (d0 + d1) / 2, "z": DOOR_Z - 0.42})
    def kind(f):    # what a piece is: its prop's name, less the "cel_" of a cel-shaded one (../furniture/)
        return f["prop"][4:] if f["prop"].startswith("cel_") else f["prop"]
    TABLES = [g for g in furniture if g.get("box") and kind(g).startswith(("table", "desk", "schooldesk", "bar_counter"))]
    def seats_of(f):
        if f.get("outside") or f.get("seat") is False or kind(f) not in ("stool", "barstool", "pew") or not f.get("box"):
            return []
        bx0, bx1, bz0, bz1, _ = f["box"]
        cx, cz = (bx0 + bx1) / 2, (bz0 + bz1) / 2
        face = f.get("seat")
        if face is None and kind(f) in ("stool", "barstool"):
            near = [g for g in TABLES if bool(g.get("upper")) == bool(f.get("upper"))]
            if near:
                def centre(g):
                    return ((g["box"][0] + g["box"][1]) / 2, (g["box"][2] + g["box"][3]) / 2)
                tx, tz = min((centre(g) for g in near), key=lambda c: (c[0] - cx) ** 2 + (c[1] - cz) ** 2)
                dx, dz = tx - cx, tz - cz
                face = ("east" if dx > 0 else "west") if abs(dx) > abs(dz) else ("north" if dz < 0 else "south")
            else:
                face = "south"
        if face is None:        # a bench
            face = "south" if bz0 <= ZB + 0.05 else "north"
        if kind(f) == "pew":
            return [(cx - 0.25, cz, face), (cx + 0.25, cz, face)]
        return [(cx, cz, face)]
    for f in furniture:
        lift = UP["height"] if (UP and f.get("upper")) else FY
        fpar = (INS + "/" + NAME + "_Upper") if (UP and f.get("upper")) else (INS + "/Furniture")
        if f.get("outside"):       # out in front (the tavern's courtyard): always on show, on the ground
            lift, fpar = 0.0, "."
        w, h = props[f["prop"]]
        qw = w / 32.0 * FURN
        if f.get("split"):
            # a bed in three layers (../furniture/finish.py), so that someone lying in it shows between them:
            # its foot standing at the front of the footprint ("z"), its body flat SPLIT_BODY_Y over the
            # floor (under the sleeper: NPC.BED_HEIGHT), its head standing SPLIT_HEAD_DEPTH further back.
            # Each keeps its place on screen: the body's front edge comes forward as it rises, the head
            # stands sunk into the floor (only its upper rows have anything in them).
            zf = f["z"]
            qh = h / 32.0 / COS * FURN
            S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, qh))
            N('[node name="%sFoot" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s_foot")\n'
              % (f["name"], fpar, tf(f["x"], qh / 2 + lift, zf), f["name"], f["prop"]))
            if f["split"] != "seat":     # a pew ("seat"): its back stands at the front, its seat lies flat: no head
                N('[node name="%sHead" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s_head")\n'
                  % (f["name"], fpar, tf(f["x"], qh / 2 + lift - SIN / COS * SPLIT_HEAD_DEPTH, zf - SPLIT_HEAD_DEPTH), f["name"], f["prop"]))
            by = SPLIT_SEAT_Y if f["split"] == "seat" else SPLIT_BODY_Y
            fh = h / 32.0 / SIN * FURN
            S('[sub_resource type="QuadMesh" id="q_%sBody"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, fh))
            N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%sBody")\nsurface_material_override/0 = SubResource("mt_p_%s_body")\n'
              % (f["name"], fpar, tf(f["x"], by + lift, zf + COS / SIN * by - fh / 2, True), f["name"], f["prop"]))
        elif f.get("flat"):
            qh = h / 32.0 / SIN * FURN
            S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, qh))
            N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s")\n'
              % (f["name"], fpar, tf(f["x"], f.get("y", 0.36) + lift, f["z"], True), f["name"], f["prop"]))
        else:
            qh = h / 32.0 / COS * FURN
            S('[sub_resource type="QuadMesh" id="q_%s"]\nsize = Vector2(%.4f, %.4f)\n' % (f["name"], qw, qh))
            N('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_%s")\nsurface_material_override/0 = SubResource("mt_p_%s")\n'
              % (f["name"], fpar, tf(f["x"], qh / 2 + lift + f.get("hang", 0.0), f["z"]), f["name"], f["prop"]))
        if f.get("box"):
            bx0, bx1, bz0, bz1, bh = f["box"]
            shapes.append((f["name"], bx0, bx1, lift, lift + bh, bz0, bz1))
        # stools and benches are seats (scripts/world/Seat.gd): the doctor sits on them with E, and later
        # the townsfolk; a stool faces its table, a bench faces north (the altar, the room) unless it stands
        # against the back wall; "seat" in the spec says which way, or False for none
        for si, (sx_, sz_, sface) in enumerate(seats_of(f)):
            E("Script", "res://scripts/world/Seat.gd", "sc_seat")
            N('[node name="%sSeat%d" type="Marker3D" parent="%s"]\ntransform = %s\nscript = ExtResource("sc_seat")\nfacing = "%s"\nuse_range = 0.5\n'
              % (f["name"], si, fpar, tf(sx_, lift, sz_), sface)
              + ("raise = %r\n" % float(f["seat_raise"]) if f.get("seat_raise") else ""))
        # candles on a standing piece: a small flame at each wick (pixels of the prop's art) and,
        # with "glow", a warm light among them, seen inside only
        for ci, (cx_, cy_) in enumerate(f.get("flames", [])):
            if not any('id="sh_candle"' in e for e in ext):
                E("Shader", FX + "fx_candle.gdshader", "sh_candle")
                S('[sub_resource type="ShaderMaterial" id="mt_candle"]\nshader = ExtResource("sh_candle")\n')
                # 4 x 7 of the props' pixels, upright toward the camera
                S('[sub_resource type="QuadMesh" id="q_candle"]\nsize = Vector2(%.4f, %.4f)\n' % (4 / 32.0 * FURN, 7 / 32.0 / COS * FURN))
            fx_ = f["x"] + (cx_ - w / 2.0) / 32.0 * FURN
            fy_ = lift + qh - cy_ / 32.0 / COS * FURN + 3.5 / 32.0 / COS * FURN
            N('[node name="%sFlame%d" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_candle")\nsurface_material_override/0 = SubResource("mt_candle")\n'
              % (f["name"], ci, fpar, tf(fx_, fy_, f["z"] + 0.02)))
        if f.get("glow"):
            N('[node name="%sGlow" type="OmniLight3D" parent="%s"]\ntransform = %s\nlight_color = Color(1, 0.7, 0.38, 1)\nlight_energy = %.2f\nomni_range = 3.5\nshadow_enabled = false\n'
              % (f["name"], fpar, tf(f["x"], lift + qh * 0.8, f["z"] + 0.6), f["glow"]))

    # ---------- collision ----------
    WALL = max(5.4, UP["height"] + 2.4) if UP else 3.2      # a tall ground floor (the school) needs taller walls
    FZ_ = UP.get("front_z", 0.0) if UP else 0.0
    FH = UP["height"] if (UP and FZ_ > 0) else WALL      # height of the ground floor front
    if PLAN:       # the plan's walls: (name, x0, x1, z0, z1) full height, or with (y0, y1)
        for w_ in PLAN["walls"]:
            nm_, xa_, xb_, za_, zb_ = w_[:5]
            ya_, yb_ = w_[5:7] if len(w_) > 5 else (0, WALL)
            shapes.append((nm_, xa_, xb_, ya_, yb_, za_, zb_))
    elif NOTCH and DN < D - 0.01:     # a shallower set-back part: its own back wall, the main part's east wall behind it
        shapes += [("Back", xw0, XN, 0, WALL, -D, ZB), ("BackNotch", XN - WT, xw1, 0, WALL, -DN, ZBN),
                   ("WingEast", XN - WT, XN, 0, WALL, -D, ZBN)]
    else:
        shapes.append(("Back", xw0, xw1, 0, WALL, -D, ZB))
    DOOR_IN_NOTCH = DOOR_Z != 0.0
    if not PLAN:   # the box room's walls (a plan gives its own, above)
        # the west wall, open where a side door is (spec "west_gaps": z ranges, front first)
        wz = (ZNL + 0.15) if NL else max(0.15, FZ_ + 0.15)
        for gi, (ga_, gb_) in enumerate(SPEC.get("west_gaps", [])):
            shapes.append(("West%d" % gi, xw0, XI0, 0, WALL, wz, ga_))
            wz = gb_
        shapes.append(("West", xw0, XI0, 0, WALL, wz, -D))
        if NL:        # the left wing: its own front wall (thick outward only, so upstairs the walk in front of the stairs stays wide), and the main room's west wall in front of it
            shapes += [("NotchFront", xw0, XNL + WTL, 0, WALL, ZNL + 0.15, ZNL), ("NotchSide", XNL, XNL + WTL, 0, WALL, 0.15, ZNL)]
        # the front wall, open at the door and at any other openings in the art (arches); a lintel over each opening
        DOOR_IN_NOTCH = DOOR_Z != 0.0
        gaps = [] if DOOR_IN_NOTCH else [(d0, d1, None)]
        for gi, g in enumerate(SPEC.get("front_gaps", [])):
            gp = SPEC["planes"][g.get("plane", 0)]
            gaps.append((px(g["px"][0]), px(g["px"][1]), (gp["base"] - g["top_row"]) / 32.0 / COS))
        gaps.sort()
        fx = XNL if NL else xw0
        for gi, (ga_, gb_, gtop) in enumerate(gaps):
            nm_ = "FrontLeft" if gi == 0 else "Front%d" % gi
            shapes.append((nm_, fx, ga_, 0, FH, 0.15, -0.15))
            if gtop is not None:
                shapes.append(("Lintel%d" % gi, ga_, gb_, gtop, FH, 0.15, -0.15))
            fx = gb_
        shapes.append(("FrontRight", fx, XN if NOTCH else xw1, 0, FH, 0.15, -0.15))
        for pi, pt in enumerate(SPEC.get("partitions", [])):
            shapes.append(("Partition%d" % pi, pt["x"][0], pt["x"][1], 0, pt["height"], -0.15, ZB))
        if FY > 0:    # the raised floor is a solid slab; the porch in front of the door and the steps up to it
            shapes.append(("RaisedFloor", xw0, xw1, 0, FY, 0.15, -D))
            if PORCH:
                pa, pb, pz0, pz1 = PORCH
                shapes.append(("PorchFloor", pa, pb, 0, FY, pz1, min(pz0, 0.15)))
            if SPEC.get("steps"):
                sx0, sx1 = (px(v) for v in SPEC["steps"]["x_px"])
                st, sb = SPEC["steps"]["z"]          # where they meet the porch, where they reach the ground
                conv.append(("Steps", [(x, y, z) for x in (sx0, sx1) for y, z in ((FY, st - 0.05), (0.0, st - 0.05), (0.0, sb), (0.02, sb))]))
        if NOTCH:     # the lean-to: the main room's east wall up to it, and its own front wall
            shapes.append(("NotchSide", XN - WT, XN, 0, WALL, 0.15, ZN))
            if DOOR_IN_NOTCH:     # the door in it, a lintel over the door
                dtop = DOOR["yt"] if DOOR else 2.0
                shapes += [("NotchFront", XN - WT, d0, 0, WALL, ZN + 0.15, ZN - 0.15), ("NotchFront2", d1, xw1, 0, WALL, ZN + 0.15, ZN - 0.15),
                           ("NotchLintel", d0, d1, dtop, WALL, ZN + 0.15, ZN - 0.15)]
            else:
                shapes.append(("NotchFront", XN - WT, xw1, 0, WALL, ZN + 0.15, ZN - 0.15))
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
            shapes.append(("East", XI1, xw1, 0, WALL, ZN + 0.15 if NOTCH else max(0.15, FZ_ + 0.15), -DN))
    if UP:
        if FZ_ <= 0 and not DOOR_IN_NOTCH:
            shapes.append(("UpperDoor", d0, d1, UP["height"] + 0.5, WALL, 0.15, -0.15))
        shapes += up_shapes
    for i, (a, b, za, zb) in enumerate(SPEC.get("posts", [])):
        shapes.append(("Post%d" % i, px(a), px(b), 0, 2.5, za, zb))
    if SPEC.get("smoke_px"):
        sx, srow = SPEC["smoke_px"]
        t = (re - srow) / re
        sy, sz = ye + t * (yt - ye), ze + t * (-D - ze)
        S('[sub_resource type="QuadMesh" id="q_smoke"]\nsize = Vector2(0.9, 3.2)\n')
        # with the roof: seen only from outside (the roof is cut away while the doctor is in)
        N('[node name="ChimneySmoke" type="MeshInstance3D" parent="%s_Roof"]\ntransform = %s\nmesh = SubResource("q_smoke")\nsurface_material_override/0 = SubResource("mt_smoke")\n'
          % (NAME, tf(px(sx), sy + 1.6, sz + 0.05)))
    # lanterns in the art: a small flame behind the glass and a light that comes on at night
    if SPEC.get("lamps"):
        if not any('id="sh_flame"' in e for e in ext):
            E("Shader", FX + "fx_flame.gdshader", "sh_flame"); E("Texture2D", FX + "fx_flame.png", "tx_flame")
            S('[sub_resource type="ShaderMaterial" id="mt_flame"]\nshader = ExtResource("sh_flame")\nshader_parameter/frames = ExtResource("tx_flame")\n')
        E("Script", "res://scripts/world/NightLight.gd", "sc_nightlight")
        for li, lp_ in enumerate(SPEC["lamps"]):
            lx_px, lrow = lp_["px"]
            lpl = SPEC["planes"][lp_.get("plane", 0)]
            lx, ly, lz = px(lx_px), (lpl["base"] - lrow) / 32.0 / COS, lpl["z"] + 0.03
            fw_, fh_ = lp_.get("flame", (0.12, 0.16))
            S('[sub_resource type="QuadMesh" id="q_lamp%d"]\nsize = Vector2(%.4f, %.4f)\n' % (li, fw_, fh_))
            # the flame goes with the art it sits in: the front (hidden indoors), and upstairs too when
            # the lantern is one of the pieces of the outside kept on show there
            N('[node name="Lamp%dFlame" type="MeshInstance3D" parent="%s_Front"]\ntransform = %s\nmesh = SubResource("q_lamp%d")\nsurface_material_override/0 = SubResource("mt_flame")\n'
              % (li, NAME, tf(lx, ly, lz), li))
            if UP and any(k["rect"][0] <= lx_px < k["rect"][2] and k["rect"][1] <= lrow < k["rect"][3] for k in SPEC.get("keep_inside", [])):
                N('[node name="Lamp%dFlameUp" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("q_lamp%d")\nsurface_material_override/0 = SubResource("mt_flame")\n'
                  % (li, NAME + "_Inside/" + NAME + "_Upper", tf(lx, ly, lz), li))
            N('[node name="Lamp%dLight" type="OmniLight3D" parent="."]\ntransform = %s\nlight_color = Color(1, 0.72, 0.4, 1)\nlight_energy = 1.2\nomni_range = 4.0\nshadow_enabled = false\nscript = ExtResource("sc_nightlight")\n'
              % (li, tf(lx, ly, lz + 0.4)))
    N('[node name="Walls" type="StaticBody3D" parent="."]\n')
    for nm, xa, xb, ya, yb, za, zb in shapes:
        S('[sub_resource type="BoxShape3D" id="b_%s"]\nsize = Vector3(%.4f, %.4f, %.4f)\n' % (nm, abs(xb - xa), abs(yb - ya), abs(zb - za)))
        N('[node name="%s" type="CollisionShape3D" parent="Walls"]\ntransform = %s\nshape = SubResource("b_%s")\n'
          % (nm, tf((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), nm))

    for nm, pts in conv:
        S('[sub_resource type="ConvexPolygonShape3D" id="c_%s"]\npoints = PackedVector3Array(%s)\n' % (nm, ", ".join("%.4f, %.4f, %.4f" % p for p in pts)))
        N('[node name="%s" type="CollisionShape3D" parent="Walls"]\nshape = SubResource("c_%s")\n' % (nm, nm))
    text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes)
    return text
