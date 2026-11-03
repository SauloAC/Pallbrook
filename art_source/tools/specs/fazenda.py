# Ada's farm: Cainos House 03. A stone ground floor with two arches (the stable, packed earth inside) and,
# in the narrow wing on the right, a door to a stair hall; Ada lives upstairs, in the timbered storey.
SPEC = {
    "name": "Fazenda", "facade": "art_source/facades/house03_noshadow.png",
    # the wall with the arches and the wing's door, and the stone piers standing out in front of it
    "planes": [{"rect": (0, 145, 320, 233), "base": 233, "z": 0.0},
               {"rect": (28, 175, 230, 252), "base": 250, "z": 0.69, "keep_from": 175,
                "keep_cols": [(33, 60), (108, 150), (196, 222)]}],
    "roof": {"on_plane": 0, "row": 145},
    "depth": 5.6, "wall_px": (33, 275), "room_height": 4.27, "door_px": (233, 262),
    "solid_uv": (0.406, 0.253), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "floor_tile": "tile_dirt_floor.png",
    "posts": [(33, 60, 0.0, 0.69), (108, 150, 0.0, 0.69), (196, 222, 0.0, 0.69)],   # the stone piers
    "door_art": {"rect": (234, 190, 262, 229), "hinge": "left"},
    # the two arches are open: the stable behind them
    "front_gaps": [{"px": (58, 109), "top_row": 193}, {"px": (149, 197), "top_row": 193}],
    # the stable and the stair hall are two rooms downstairs
    "partitions": [{"x": (2.0, 2.25), "height": 2.8}],
    # the stairs run up the hall along its right wall; upstairs is one room over both
    "upper": {"height": 2.8, "dir": "back", "side": "right", "width": 1.0, "start_z": -0.6, "run": 3.2, "steps": 16,
              "lower_front_plane": 0, "show_upstairs": [1], "stair_wall_tile": "tile_stone_light.png"},
    # stable x -3.67..2.00, hall x 2.25..3.29 (stairs x 2.29..3.29, z -0.6 to -3.8), back wall at z -5.3
    "npc": {"slots": [(-2.3, -2.6), (0.0, -3.0), (-1.2, -1.5)],   # tending the stable, by the feed, by the arches
            "bed": (-3.0, 2.8, -3.7, 0.0),
            "bed_approach": (-2.0, 2.8, -3.6)},
    "furniture": [
        # the stable: feed and stores along the back wall
        {"name": "SackA", "prop": "sack_a", "x": -3.3, "z": -4.95, "box": (-3.55, -3.05, -5.3, -4.95, 0.7)},
        {"name": "SackB", "prop": "sack_b", "x": -2.75, "z": -4.95, "box": (-3.0, -2.5, -5.3, -4.95, 0.7)},
        {"name": "BarrelStack", "prop": "barrel_stack", "x": -1.0, "z": -4.6, "box": (-1.65, -0.35, -5.3, -4.6, 1.0)},
        {"name": "FoodCrate", "prop": "foodcrate", "x": 0.5, "z": -5.0, "box": (0.15, 0.85, -5.3, -5.0, 0.6)},
        {"name": "Basket", "prop": "basket", "x": 1.4, "z": -4.95, "box": (1.1, 1.7, -5.3, -4.95, 0.6)},
        # Ada's room upstairs
        {"name": "Bed", "prop": "bed", "upper": True, "flat": True, "x": -3.0, "z": -4.5, "box": (-3.35, -2.65, -5.2, -3.8, 0.4)},
        {"name": "Table", "prop": "table_round", "upper": True, "x": -0.8, "z": -3.2, "box": (-1.1, -0.5, -3.7, -3.2, 0.8)},
        {"name": "StoolA", "prop": "stool", "upper": True, "x": -1.35, "z": -3.05, "box": (-1.53, -1.17, -3.35, -3.05, 0.5)},
        {"name": "StoolB", "prop": "stool", "upper": True, "x": -0.25, "z": -3.05, "box": (-0.43, -0.07, -3.35, -3.05, 0.5)},
        {"name": "UpCrate", "prop": "crate", "upper": True, "x": 0.9, "z": -4.8, "box": (0.55, 1.25, -5.3, -4.8, 0.9)},
        {"name": "UpJar", "prop": "jar", "upper": True, "x": 1.7, "z": -4.95, "box": (1.45, 1.95, -5.3, -4.95, 0.7)},
        {"name": "UpBasket", "prop": "basket", "upper": True, "x": -3.2, "z": -1.0, "box": (-3.5, -2.9, -1.35, -1.0, 0.6)},
    ],
}
