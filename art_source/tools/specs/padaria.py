# The bakery: Cainos House 09, widened 15%. The shop below (counter, barrels, sacks), Bruno's room above,
# stone stairs along the back wall rising to the left.
SPEC = {
    "name": "Padaria", "facade": "art_source/facades/house09_noshadow.png",
    "planes": [{"rect": (0, 108, 271, 205), "base": 205, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 108},
    "stretch_x": 1.15, "wall_t": 0.345,
    "depth": 4.066, "wall_px": (7, 260), "room_height": 4.66, "door_px": (22, 64),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "upper": {"height": 2.1, "landing": 1.3, "run": 2.4, "stair_depth": 1.0, "steps": 14, "lower_front_plane": 0},
    # room x -4.27..4.13, back wall at z -3.72; stairs x -2.97..-0.57, front at z -2.72
    "npc": {"slots": [(1.5, -2.5), (-0.8, -0.6), (1.2, -0.6), (-2.0, -1.0)],  # behind the counter, then the shop floor
            "bed": (3.6, 2.1, -2.34, 0.0),
            "bed_approach": (2.8, 2.1, -1.5)},
    "door_art": {"rect": (29, 160, 57, 203), "hinge": "left"},   # the painted door, which swings open
    "furniture": [
        {"name": "Counter", "prop": "table", "flat": True, "y": 0.57, "x": 1.6, "z": -1.4, "box": (0.7, 2.5, -1.75, -1.05, 0.7)},
        {"name": "BarrelStack", "prop": "barrel_stack", "x": 3.3, "z": -3.011, "box": (2.65, 3.95, -3.721, -3.011, 1.0)},
        {"name": "Barrel", "prop": "barrel_a", "x": 3.7, "z": -0.3, "box": (3.38, 4.02, -0.95, -0.3, 0.8)},
        {"name": "SackB", "prop": "sack_b", "x": 3.0, "z": -0.3, "box": (2.75, 3.25, -0.75, -0.3, 0.7)},
        {"name": "Bed", "prop": "cel_bed", "upper": True, "split": True, "x": 3.6, "z": -2.22, "box": (3.26, 3.94, -3.58, -2.22, 0.4)},
        {"name": "UpBarrel", "prop": "barrel_b", "upper": True, "x": 1.4, "z": -3.051, "box": (1.1, 1.7, -3.721, -3.051, 0.8)},
        {"name": "UpSack", "prop": "sack_a", "upper": True, "x": 2.3, "z": -3.221, "box": (2.05, 2.55, -3.721, -3.221, 0.7)},
    ],
}
