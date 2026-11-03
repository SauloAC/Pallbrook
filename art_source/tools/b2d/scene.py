"""Puts a building together as a Godot scene: resources, the node tree the cutaway expects, and collision.

Node tree: <Name>2D / <Name>_Front (planes), <Name>_Roof, Body, <Name>_Inside (the room, shown only while the
doctor is in: Floor, InnerWall, Timber, Furniture, <Name>_Lower, <Name>_Upper), ChimneySmoke, Walls."""
import os
from .core import COS, SIN, FURN, RES as R, tf
from . import door as door_mod


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
    # ---------- props ----------
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
    door_mod.scene_nodes(h, h.door, E, S, N, mat, NAME + "_Front")
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
    return text
