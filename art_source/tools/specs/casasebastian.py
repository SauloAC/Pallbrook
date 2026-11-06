# Sebastian: Cainos House 06, a wooden house with its gable to the street
SPEC = {
    "name": "CasaSebastian", "facade": "art_source/facades/house06_noshadow.png",
    "planes": [{"rect": (0, 229, 142, 279), "base": 279, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 229},
    "depth": 5.6, "wall_px": (7, 135), "room_height": 2.43, "door_px": (26, 66),
    "solid_uv": (0.5, 0.97),
    "inner_wall_tile": "tile_wood_wall.png",
    "smoke_px": (28, 21),            # the chimney cap in the facade art
    # the chimney outside is at the back left: its fireplace inside, in that corner
    "blocks": [{"name": "Fireplace", "x0": -1.7, "x1": -0.8, "z_back": -5.3, "z_front": -4.6, "height": 2.43,
                "front_tex": "fireplace_front", "light": (-1.25, 0.4, -4.3), "flame": (-1.266, 0.51, -4.58, 0.36, 0.48),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -1.70..1.70, back wall at z -5.3
    # where people stand indoors (x, z; the first is the owner's own spot) and sleep (x, y, z, head angle)
    "npc": {"slots": [(-0.752, -2.3), (0.598, -2.0), (0.398, -3.3)],  # at the table, mid-room, by the bed
            "bed": (1.148, 0.0, -3.97, 0.0)},
    "door_art": {"rect": (32, 237, 62, 277), "hinge": "left"},   # the painted door, which swings open
    "furniture": [
        {"name": "Bed", "prop": "cel_bed", "split": True, "x": 1.15, "z": -3.85, "box": (0.8, 1.5, -5.3, -3.85, 0.4)},
        {"name": "Table", "prop": "table_round", "x": -0.75, "z": -3.0, "box": (-1.05, -0.45, -3.5, -3.0, 0.8)},
        {"name": "StoolA", "prop": "stool", "x": -1.3, "z": -2.85, "box": (-1.48, -1.12, -3.15, -2.85, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": -0.2, "z": -2.85, "box": (-0.38, -0.02, -3.15, -2.85, 0.5)},
        {"name": "Pot", "prop": "pot", "x": 1.4, "z": -3.5, "box": (1.2, 1.6, -3.8, -3.5, 0.6)},
        {"name": "Jar", "prop": "jar", "x": 0.5, "z": -4.95, "box": (0.27, 0.73, -5.3, -4.95, 0.7)},
        {"name": "Crate", "prop": "crate", "x": -0.1, "z": -4.75, "box": (-0.45, 0.25, -5.3, -4.75, 0.9)},
    ],
}
