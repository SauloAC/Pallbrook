"""The painted front door, made to swing: while anyone stands in the doorway its leaf folds toward the
hinge (as the Cainos door animations do) and shows the dark opening behind. Run by scripts/world/Door2D.gd."""
import os
from .core import tf

OPENING = "door_opening.png"       # a dark doorway, in assets/buildings2d


def build(h):
    """Writes the door leaf texture; returns what the scene needs, or None"""
    d = h.spec.get("door_art")
    if not d:
        return None
    x0, r0, x1, r1 = d["rect"]
    pl = h.plane(d.get("plane", 0))
    leaf = h.art.crop((x0, r0, x1, r1))
    fn = h.key + "_door.png"
    leaf.save(os.path.join(h.out, fn))
    xa, xb = h.px(x0), h.px(x1)
    yb, yt = h.y_on(pl, r1), h.y_on(pl, r0)
    return {"tex": fn, "xa": xa, "xb": xb, "yb": yb, "yt": yt, "z": pl["z"], "hinge": d.get("hinge", "left")}


def scene_nodes(h, door, E, S, N, mat, parent):
    if not door:
        return
    w, hh = door["xb"] - door["xa"], door["yt"] - door["yb"]
    E("Script", "res://scripts/world/Door2D.gd", "sc_door")
    E("Texture2D", h.res + door["tex"], "tx_door"); mat("mt_door", "sh_sprite", "tx_door")
    E("Texture2D", "res://assets/buildings2d/" + OPENING, "tx_opening"); mat("mt_opening", "sh_sprite", "tx_opening")
    S('[sub_resource type="QuadMesh" id="q_door"]\nsize = Vector2(%.4f, %.4f)\n' % (w, hh))
    S('[sub_resource type="BoxShape3D" id="b_doorway"]\nsize = Vector3(%.4f, 1.6, 0.8)\n' % (w + 0.3))
    left = door["hinge"] == "left"
    hx = door["xa"] if left else door["xb"]
    z = door["z"]
    N('[node name="Door" type="Node3D" parent="%s"]\nscript = ExtResource("sc_door")\n' % parent)
    N('[node name="Opening" type="MeshInstance3D" parent="%s/Door"]\ntransform = %s\nmesh = SubResource("q_door")\nsurface_material_override/0 = SubResource("mt_opening")\n'
      % (parent, tf((door["xa"] + door["xb"]) / 2, door["yb"] + hh / 2, z + 0.012)))
    N('[node name="Leaf" type="Node3D" parent="%s/Door"]\ntransform = %s\n' % (parent, tf(hx, door["yb"], z + 0.024)))
    N('[node name="Panel" type="MeshInstance3D" parent="%s/Door/Leaf"]\ntransform = %s\nmesh = SubResource("q_door")\nsurface_material_override/0 = SubResource("mt_door")\n'
      % (parent, tf(w / 2 if left else -w / 2, hh / 2, 0)))
    # who is in the doorway: from just outside the door to just inside it (not the spot past it where people wait unseen)
    N('[node name="Doorway" type="Area3D" parent="%s/Door"]\ntransform = %s\ncollision_layer = 0\n' % (parent, tf((door["xa"] + door["xb"]) / 2, 0.8, z + 0.1)))
    N('[node name="Shape" type="CollisionShape3D" parent="%s/Door/Doorway"]\nshape = SubResource("b_doorway")\n' % parent)
