# John: Cainos House 05, on stilts; the door is in the stone wall set back under the upper floor
SPEC = {
    "name": "CasaJohn", "facade": "art_source/facades/house05_noshadow.png",
    "planes": [{"rect": (0, 245, 184, 345), "base": 345, "z": 1.1, "keep_from": 292,
                "keep_cols": [(9, 18), (68, 78), (127, 137)]},
               {"rect": (17, 288, 128, 318), "base": 317, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 245},
    "depth": 5.8, "wall_px": (9, 136), "room_height": 4.86, "door_px": (84, 124),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "posts": [(9, 17, 0.95, 1.25), (69, 77, 0.95, 1.25), (128, 136, 0.95, 1.25)],
    # two floors: the stone room below, John's room above at the level of the beam over the stilts.
    # The stairs run along the left wall toward the back; upstairs the stilts and the stone wall come back.
    "upper": {"height": 2.77, "dir": "back", "width": 1.0, "start_z": -1.0, "run": 3.2, "steps": 16,
              "lower_front_plane": 0, "show_upstairs": [1], "front_z": 1.1},
    # the balcony on the right, at the level of the upper floor, reached through the east wall
    "deck": {"rect": (141, 138, 184, 238), "plane": 0, "y": 2.77, "walk": (170, 152, 226)},
    # seen from inside, the balcony keeps its brace and a roof tile above and below where it meets the house
    "keep_inside": [{"rect": (136, 238, 172, 263)}, {"rect": (130, 224, 144, 250)}, {"rect": (130, 136, 144, 152)}],
    # room x -2.29..1.07, back wall at z -5.5; stairs x -2.29..-1.29 from z -1.0 to -4.2
    # where people stand indoors (x, z; the first is the owner's own spot) and sleep (x, y, z, head angle)
    "npc": {"slots": [(0.404, -1.2), (-0.904, -2.0), (0.804, -2.2)],  # by the door, by the stairs, at the table
            "bed": (0.554, 2.771, -3.92, 0.0),
            "bed_approach": (-0.504, 2.771, -3.6)},
    "door_art": {"rect": (88, 291, 116, 317), "plane": 1, "hinge": "left"},   # the painted door, which swings open
    "furniture": [
        {"name": "Table", "prop": "table", "flat": True, "y": 0.57, "x": 0.0, "z": -3.4, "box": (-0.9, 0.9, -3.75, -3.05, 0.7)},
        {"name": "StoolA", "prop": "stool", "x": -0.5, "z": -2.5, "box": (-0.68, -0.32, -2.8, -2.5, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.5, "z": -2.5, "box": (0.32, 0.68, -2.8, -2.5, 0.5)},
        {"name": "Barrel", "prop": "barrel_a", "x": 0.65, "z": -4.85, "box": (0.3, 1.0, -5.5, -4.85, 0.8)},
        {"name": "FoodCrate", "prop": "foodcrate", "x": -0.4, "z": -5.0, "box": (-0.75, -0.05, -5.5, -5.0, 0.6)},
        {"name": "Bed", "prop": "cel_bed", "upper": True, "split": True, "x": 0.55, "z": -3.8, "box": (0.2, 0.9, -5.2, -3.8, 0.4)},
        {"name": "UpBasket", "prop": "basket", "upper": True, "x": -0.6, "z": -0.6, "box": (-0.9, -0.3, -0.95, -0.6, 0.6)},
    ],
}
