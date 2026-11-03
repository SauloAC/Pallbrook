"""2D-on-volume buildings for Pallbrook: painted Cainos art projected onto simple volumes, with a walk-in room.

    house = build_house(spec, out_dir, prop_sizes)   # writes the meshes, textures and <Name>2D.tscn
"""
import os
from .core import House
from . import outside, inside, upper, door, scene, layout


def build_house(spec, out_dir, prop_sizes):
    h = House(spec, out_dir, prop_sizes)
    outside.build(h)
    inside.build(h)
    upper.build(h)
    h.door = door.build(h)
    text = scene.build(h)
    open(os.path.join(out_dir, h.name + "2D.tscn"), "w").write(text)
    h.layout = layout.npc_layout(h)
    h.info = {"W": round(h.W, 3), "xw0": round(h.xw0, 3), "xw1": round(h.xw1, 3), "D": h.D, "eave": round(h.ye, 3),
              "ridge": round(h.yt, 3), "door_x": round(h.door_x, 3), "room": [round(h.XI0, 3), round(h.XI1, 3), round(h.ZB, 3)]}
    if h.UP:
        h.info["upper"] = h.info_up
    if h.NOTCH:
        h.info["notch"] = [round(h.xn, 3), h.zn, round(h.wt, 3)]
    if h.DECK:
        h.info["deck_z"] = [round(h.DECK_Z[0], 3), round(h.DECK_Z[1], 3)]
    return h
