# The parish house (Father Elias): Cainos House 14, a long low house with a gabled porch on posts on the left
SPEC = {
    "name": "Casa1", "facade": "art_source/facades/house14_noshadow.png",
    "planes": [{"rect": (0, 101, 223, 143), "base": 143, "z": 0.0},
               {"rect": (25, 101, 112, 190), "base": 190, "z": 1.917}],
    "roof": {"on_plane": 0, "row": 101},
    "depth": 4.0, "wall_px": (5, 219), "room_height": 2.04, "door_px": (158, 198),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_wood_wall.png",
    "posts": [(31, 38, 1.77, 2.07), (98, 106, 1.77, 2.07)],
    "door_art": {"rect": (164, 104, 189, 142), "hinge": "left"},
    # room x -3.03..3.06, back wall at z -3.7; door x 1.45..2.70
    "npc": {"slots": [(0.5, -1.4), (-1.6, -1.2), (1.4, -1.8)],  # mid-room, by the table, by the prayer table
            "bed": (-2.5, 0.0, -2.1, 0.0)},
    "furniture": [
        {"name": "Bed", "prop": "bed", "flat": True, "x": -2.5, "z": -2.9, "box": (-2.85, -2.15, -3.6, -2.2, 0.4)},
        {"name": "Table", "prop": "table", "flat": True, "y": 0.57, "x": -0.4, "z": -2.3, "box": (-1.3, 0.5, -2.65, -1.95, 0.7)},
        {"name": "StoolA", "prop": "stool", "x": -0.8, "z": -1.5, "box": (-0.98, -0.62, -1.8, -1.5, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.0, "z": -1.5, "box": (-0.18, 0.18, -1.8, -1.5, 0.5)},
        {"name": "PrayerTable", "prop": "table_cloth", "flat": True, "y": 0.57, "x": 1.9, "z": -3.0, "box": (1.0, 2.8, -3.35, -2.65, 0.7)},
        {"name": "Crate", "prop": "crate", "x": -2.6, "z": -0.6, "box": (-2.95, -2.25, -1.15, -0.6, 0.9)},
        {"name": "Jar", "prop": "jar", "x": 2.75, "z": -1.4, "box": (2.5, 3.0, -1.75, -1.4, 0.7)},
    ],
}
