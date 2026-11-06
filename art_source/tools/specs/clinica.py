# The clinic: Cainos House 01. A stone ground floor under a timbered upper storey and a tall gable, the
# door on the right; on the left a stone wing stands back from the front, and in it the stairs.
# Downstairs the consulting room: the medicine cabinet and the outbreak board on the back wall, a small
# table where patients sit. Upstairs the doctor's room, with his bed. The chimney smokes.
SPEC = {
    "name": "Clinica", "facade": "art_source/facades/house01_noshadow.png",
    # the main front, and the wing's wall further back (its foot is 67 rows higher in the art), up to the
    # upper floor's height: upstairs it closes the gap down to the stairs
    "planes": [{"rect": (58, 198, 193, 299), "base": 299, "z": 0.0},
               {"rect": (0, 183, 62, 232), "base": 232, "z": -2.733}],
    "roof": {"on_plane": 0, "row": 198},
    "depth": 4.6, "wall_px": (7, 185), "room_height": 4.9, "door_px": (136, 165),
    "solid_uv": (0.52, 0.06), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (137, 254, 164, 298), "hinge": "left"},
    # the wing is part of the room, behind its own front wall
    "notch_left": {"x_px": 60, "z": -2.733},
    "smoke_px": (86, 27),            # under the chimney's stone cap
    # stone stairs along the back wall, rising left to a landing in the wing's back corner
    "upper": {"height": 2.38, "landing": 0.8, "run": 2.4, "stair_depth": 0.78, "steps": 14, "lower_front_plane": 0,
              "stair_wall_tile": "tile_stone_light.png", "stair_wall_tile_px": (128, 40), "show_upstairs": [1]},
    # room x -2.50..2.47 (the wing x -2.50..-1.14, behind z -2.73), back wall at z -4.3; door x 1.23..2.14
    # stairs x -1.70..0.70 (landing x -2.50..-1.70), front at z -3.52; upstairs a walk in front of them along the wing
    "npc": {"slots": [(1.0, -2.3), (0.7, -1.4), (1.7, -2.1), (0.3, -3.0), (1.3, -1.0), (-0.2, -0.75),
                      (1.0, 1.0), (2.3, 1.3)]},   # inside around the consulting table, then two outside the door: a queue
    "furniture": [
        {"name": "Cabinet", "prop": "cabinet", "x": 2.05, "z": -4.0, "box": (1.65, 2.47, -4.3, -3.95, 1.6)},
        {"name": "Table", "prop": "table_round", "x": -0.35, "z": -1.75, "box": (-0.65, -0.05, -2.25, -1.75, 0.8)},
        {"name": "StoolA", "prop": "stool", "x": -0.75, "z": -1.5, "box": (-0.93, -0.57, -1.8, -1.5, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.15, "z": -1.3, "box": (-0.03, 0.33, -1.6, -1.3, 0.5), "seat": "west"},
        {"name": "Basket", "prop": "basket", "x": -0.85, "z": -0.55, "box": (-1.1, -0.6, -0.9, -0.55, 0.6)},
        # the doctor's room upstairs
        {"name": "Bed", "prop": "bed", "upper": True, "flat": True, "x": 1.9, "z": -3.6, "box": (1.55, 2.25, -4.3, -2.9, 0.4)},
        {"name": "UpTable", "prop": "table_round", "upper": True, "x": 0.3, "z": -1.4, "box": (0.0, 0.6, -1.9, -1.4, 0.8)},
        {"name": "UpStool", "prop": "stool", "upper": True, "x": -0.2, "z": -1.15, "box": (-0.38, -0.02, -1.45, -1.15, 0.5)},
        {"name": "UpCrate", "prop": "crate", "upper": True, "x": 2.1, "z": -1.0, "box": (1.75, 2.45, -1.55, -1.0, 0.9)},
    ],
}
