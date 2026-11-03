# John: Cainos House 05, on stilts; the door is in the stone wall set back under the upper floor
SPEC = {
    "name": "CasaJohn", "facade": "art_source/facades/house05_noshadow.png",
    "planes": [{"rect": (0, 245, 184, 345), "base": 345, "z": 1.1, "keep_from": 292,
                "keep_cols": [(9, 18), (68, 78), (127, 137)]},
               {"rect": (17, 288, 128, 318), "base": 317, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 245},
    "depth": 5.8, "wall_px": (9, 136), "room_height": 2.9, "door_px": (84, 124),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "posts": [(9, 17, 0.95, 1.25), (69, 77, 0.95, 1.25), (128, 136, 0.95, 1.25)],
    # room x -2.29..1.07, back wall at z -5.5
    "furniture": [
        {"name": "Bed", "prop": "bed", "flat": True, "x": 0.55, "z": -4.75, "box": (0.2, 0.9, -5.5, -4.05, 0.4)},
        {"name": "Table", "prop": "table", "flat": True, "y": 0.57, "x": -1.2, "z": -3.4, "box": (-2.05, -0.35, -3.75, -3.05, 0.7)},
        {"name": "StoolA", "prop": "stool", "x": -1.6, "z": -2.5, "box": (-1.78, -1.42, -2.8, -2.5, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": -0.8, "z": -2.5, "box": (-0.98, -0.62, -2.8, -2.5, 0.5)},
        {"name": "Barrel", "prop": "barrel_a", "x": -1.85, "z": -4.85, "box": (-2.2, -1.5, -5.5, -4.85, 0.8)},
        {"name": "FoodCrate", "prop": "foodcrate", "x": -1.1, "z": -5.0, "box": (-1.45, -0.75, -5.5, -5.0, 0.6)},
    ],
}
