"""The painted front door, made to swing: while anyone stands in the doorway its leaf folds toward the
hinge (as the Cainos door animations do) and shows the dark opening behind. Run by scripts/world/Door2D.gd."""
import os
from .core import tf

OPENING = "door_opening.png"       # a dark doorway, in assets/buildings2d


def build(h, key="door_art", suffix=""):
    """Writes the door leaf texture; returns what the scene needs, or None. A second door (a side
    entrance) is "door_art2", with suffix "2" on its files and nodes."""
    d = h.spec.get(key)
    if not d:
        return None
    x0, r0, x1, r1 = d["rect"]
    pl = h.plane(d.get("plane", 0))
    leaf = h.art.crop((x0, r0, x1, r1))
    fn = h.key + "_door%s.png" % suffix
    leaf.save(os.path.join(h.out, fn))
    xa, xb = h.px(x0), h.px(x1)
    yb, yt = h.y_on(pl, r1), h.y_on(pl, r0)
    return {"tex": fn, "xa": xa, "xb": xb, "yb": yb, "yt": yt, "z": pl["z"], "hinge": d.get("hinge", "left"), "sfx": suffix}


def scene_nodes(h, door, E, S, N, mat, parent):
    if not door:
        return
    x = door["sfx"]        # "" for the front door, "2" for a side door
    w, hh = door["xb"] - door["xa"], door["yt"] - door["yb"]
    E("Script", "res://scripts/world/Door2D.gd", "sc_door")
    E("Texture2D", h.res + door["tex"], "tx_door" + x); mat("mt_door" + x, "sh_sprite", "tx_door" + x)
    E("Texture2D", "res://assets/buildings2d/" + OPENING, "tx_opening"); mat("mt_opening", "sh_sprite", "tx_opening")
    S('[sub_resource type="QuadMesh" id="q_door%s"]\nsize = Vector2(%.4f, %.4f)\n' % (x, w, hh))
    S('[sub_resource type="BoxShape3D" id="b_doorway%s"]\nsize = Vector3(%.4f, 1.6, 0.8)\n' % (x, w + 0.3))
    left = door["hinge"] == "left"
    hx = door["xa"] if left else door["xb"]
    z = door["z"]
    D = "Door" + x
    N('[node name="%s" type="Node3D" parent="%s"]\nscript = ExtResource("sc_door")\n' % (D, parent))
    N('[node name="Opening" type="MeshInstance3D" parent="%s/%s"]\ntransform = %s\nmesh = SubResource("q_door%s")\nsurface_material_override/0 = SubResource("mt_opening")\n'
      % (parent, D, tf((door["xa"] + door["xb"]) / 2, door["yb"] + hh / 2, z + 0.012), x))
    N('[node name="Leaf" type="Node3D" parent="%s/%s"]\ntransform = %s\n' % (parent, D, tf(hx, door["yb"], z + 0.024)))
    N('[node name="Panel" type="MeshInstance3D" parent="%s/%s/Leaf"]\ntransform = %s\nmesh = SubResource("q_door%s")\nsurface_material_override/0 = SubResource("mt_door%s")\n'
      % (parent, D, tf(w / 2 if left else -w / 2, hh / 2, 0), x, x))
    # who is in the doorway: from just outside the door to just inside it (not the spot past it where people wait unseen)
    N('[node name="Doorway" type="Area3D" parent="%s/%s"]\ntransform = %s\ncollision_layer = 0\n' % (parent, D, tf((door["xa"] + door["xb"]) / 2, 0.8, z + 0.1)))
    N('[node name="Shape" type="CollisionShape3D" parent="%s/%s/Doorway"]\nshape = SubResource("b_doorway%s")\n' % (parent, D, x))
