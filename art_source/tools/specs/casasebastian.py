# Sebastian: Cainos House 06, a wooden house with its gable to the street
SPEC = {
    "name": "CasaSebastian", "facade": "art_source/facades/house06_noshadow.png",
    "planes": [{"rect": (0, 229, 142, 279), "base": 279, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 229},
    "depth": 5.6, "wall_px": (7, 135), "room_height": 2.43, "door_px": (26, 66),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_wood_wall.png",
    # room x -1.70..1.70, back wall at z -5.3
    "furniture": [
        {"name": "Bed", "prop": "bed", "flat": True, "x": 1.15, "z": -4.55, "box": (0.8, 1.5, -5.3, -3.85, 0.4)},
        {"name": "Table", "prop": "table_round", "x": -0.75, "z": -3.0, "box": (-1.05, -0.45, -3.5, -3.0, 0.8)},
        {"name": "StoolA", "prop": "stool", "x": -1.3, "z": -2.85, "box": (-1.48, -1.12, -3.15, -2.85, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": -0.2, "z": -2.85, "box": (-0.38, -0.02, -3.15, -2.85, 0.5)},
        {"name": "Pot", "prop": "pot", "x": -1.45, "z": -4.95, "box": (-1.65, -1.25, -5.3, -4.95, 0.6)},
        {"name": "Jar", "prop": "jar", "x": -1.0, "z": -4.95, "box": (-1.25, -0.75, -5.3, -4.95, 0.7)},
        {"name": "Crate", "prop": "crate", "x": -0.1, "z": -4.75, "box": (-0.45, 0.25, -5.3, -4.75, 0.9)},
    ],
}
