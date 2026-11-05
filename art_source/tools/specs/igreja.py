# The church: Cainos Chapel 01. A stone nave under a steep roof, the bell tower at the back, a little
# roof over the arched door and steps down to the street. Inside: pews either side of the aisle, the
# altar with its candles at the back, and Father Elias's lectern with the burial book.
SPEC = {
    "name": "Igreja", "facade": "art_source/facades/chapel01_noshadow.png",
    # the nave's front wall, from its foot to where the roofs come down; the steps lie on the ground in front
    "planes": [{"rect": (0, 205, 136, 283), "base": 283, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 205},
    "steps": {"rect": (34, 283, 102, 315), "z": (0.0, 1.305), "x_px": (34, 102)},
    "depth": 6.5, "wall_px": (8, 128), "room_height": 4.2, "door_px": (50, 84),
    "solid_uv": (0.15, 0.24), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "floor_tile": "tile_stone_floor.png",
    "door_art": {"rect": (53, 253, 84, 274), "hinge": "left"},   # the leaf only: the steps run on under it
    # room x -1.58..1.58, back wall at z -6.2; door x -0.56..0.50
    # the priest at the altar first, then beside the lectern and between the pews, then the aisle
    "npc": {"slots": [(0.0, -5.2), (-0.9, -4.5), (-1.0, -3.2), (1.0, -3.2), (-1.0, -2.3), (1.0, -2.3),
                      (0.0, -2.8), (0.0, -1.2)]},
    "door_rug": False,             # the red runner down the aisle instead
    "furniture": [
        {"name": "Runner", "prop": "runner", "flat": True, "y": 0.025, "x": -0.031, "z": -2.95},
        {"name": "Altar", "prop": "altar", "x": 0.0, "z": -5.7, "box": (-0.85, 0.85, -6.2, -5.7, 0.8),
         "flames": [(12, 1), (62, 1)], "glow": 0.9},
        {"name": "CandleW", "prop": "candlestand", "x": -1.3, "z": -5.85, "box": (-1.42, -1.18, -5.97, -5.73, 1.2),
         "flames": [(6, 1)]},
        {"name": "CandleE", "prop": "candlestand", "x": 1.3, "z": -5.85, "box": (1.18, 1.42, -5.97, -5.73, 1.2),
         "flames": [(6, 1)]},
        {"name": "Lectern", "prop": "lectern", "x": 1.1, "z": -4.95, "box": (0.85, 1.35, -5.25, -4.95, 1.0)},
        {"name": "PewW1", "prop": "pew", "x": -0.95, "z": -1.7, "box": (-1.46, -0.44, -2.05, -1.7, 0.6)},
        {"name": "PewE1", "prop": "pew", "x": 0.95, "z": -1.7, "box": (0.44, 1.46, -2.05, -1.7, 0.6)},
        {"name": "PewW2", "prop": "pew", "x": -0.95, "z": -2.6, "box": (-1.46, -0.44, -2.95, -2.6, 0.6)},
        {"name": "PewE2", "prop": "pew", "x": 0.95, "z": -2.6, "box": (0.44, 1.46, -2.95, -2.6, 0.6)},
        {"name": "PewW3", "prop": "pew", "x": -0.95, "z": -3.5, "box": (-1.46, -0.44, -3.85, -3.5, 0.6)},
        {"name": "PewE3", "prop": "pew", "x": 0.95, "z": -3.5, "box": (0.44, 1.46, -3.85, -3.5, 0.6)},
    ],
}
