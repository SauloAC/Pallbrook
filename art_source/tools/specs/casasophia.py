# Sophia: Cainos House 10, a stone cottage with a wooden gable and a chimney on the right
SPEC = {
    "name": "CasaSophia", "facade": "art_source/facades/house10_noshadow.png",
    "planes": [{"rect": (0, 170, 178, 216), "base": 216, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 170},
    "depth": 4.4, "wall_px": (9, 173), "room_height": 2.23, "door_px": (52, 88),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (55, 172, 84, 212), "hinge": "left"},
    # the lean-to on the right is part of the room; its front wall stands back from the main front
    "notch": {"x_px": 130, "z": -1.88},
    "smoke_px": (143, 32),           # the hooded chimney cap in the facade art
    # the chimney rises from the back left of the lean-to: its fireplace inside, in that corner
    "blocks": [{"name": "Fireplace", "x0": 1.2, "x1": 2.1, "z_back": -4.1, "z_front": -3.4, "height": 2.23,
                "front_tex": "fireplace_front", "light": (1.65, 0.4, -3.1), "flame": (1.634, 0.47, -3.38, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -2.20..2.63 (the lean-to from x 1.28, behind z -1.88), back wall at z -4.1; door x -1.16..-0.03
    "npc": {"slots": [(-0.8, -2.6), (-0.6, -1.4), (0.4, -1.2)],  # by the table, mid-room, by the window
            "bed": (-1.7, 0.0, -2.72, 0.0)},
    "furniture": [
        {"name": "Bed", "prop": "cel_bed", "split": True, "x": -1.7, "z": -2.6, "box": (-2.05, -1.35, -4.0, -2.6, 0.4)},
        {"name": "Table", "prop": "table_round", "x": 0.3, "z": -2.4, "box": (0.0, 0.6, -2.9, -2.4, 0.8)},
        {"name": "StoolA", "prop": "stool", "x": -0.2, "z": -2.2, "box": (-0.38, -0.02, -2.5, -2.2, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.6, "z": -1.8, "box": (0.42, 0.78, -2.1, -1.8, 0.5)},
        {"name": "Pot", "prop": "pot", "x": 0.7, "z": -3.75, "box": (0.47, 0.93, -4.1, -3.75, 0.6)},
        {"name": "Crate", "prop": "crate", "x": -0.45, "z": -3.6, "box": (-0.8, -0.1, -4.1, -3.6, 0.9)},
        {"name": "Jar", "prop": "jar", "x": -1.95, "z": -1.0, "box": (-2.2, -1.7, -1.35, -1.0, 0.7)},
    ],
}
