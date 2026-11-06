# Clara: Cainos House 13, two storeys with a porch roof on posts and a side room with the door
SPEC = {
    "name": "CasaClara", "facade": "art_source/facades/house13_noshadow.png",
    "planes": [{"rect": (0, 88, 189, 185), "base": 185, "z": 0.0},
               {"rect": (0, 126, 90, 229), "base": 229, "z": 1.8}],
    "roof": {"on_plane": 0, "row": 88},
    "depth": 3.4, "wall_px": (3, 183), "room_height": 4.71, "door_px": (135, 175),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_wood_wall.png",
    "posts": [(5, 14, 1.65, 1.95), (72, 79, 1.65, 1.95)],
    # two floors: her workshop below, her room above, stone stairs along the back wall (rising to the left)
    "upper": {"height": 2.1, "landing": 1.3, "run": 2.4, "stair_depth": 1.0, "lower_front_plane": 0,
              "stair_wall_tile": "tile_stone_light.png", "stair_wall_tile_px": (128, 40),
              "show_upstairs": [1]},
    # room x -2.56..2.47, back wall at z -3.1; stairs x -1.26..1.14, front at z -2.1
    # where people stand indoors (x, z; the first is the owner's own spot) and sleep (x, y, z, head angle)
    "npc": {"slots": [(0.298, -1.85), (0.598, -0.8), (1.598, -1.2)],  # at her sewing table, mid-workshop, by the door
            "bed": (1.748, 2.1, -1.77, 0.0),
            "bed_approach": (0.998, 2.1, -1.2)},
    "door_art": {"rect": (141, 145, 169, 182), "hinge": "left"},   # the painted door, which swings open
    "furniture": [
        {"name": "SewingTable", "prop": "table_cloth", "flat": True, "y": 0.57, "x": -0.9, "z": -1.05, "box": (-1.8, 0.0, -1.4, -0.7, 0.7)},
        {"name": "Stool", "prop": "stool", "x": -0.9, "z": -1.75, "box": (-1.08, -0.72, -2.05, -1.75, 0.5)},
        {"name": "Basket", "prop": "basket", "x": -2.15, "z": -0.6, "box": (-2.45, -1.85, -0.95, -0.6, 0.6)},
        {"name": "Pot", "prop": "pot2", "x": 2.2, "z": -2.75, "box": (1.97, 2.43, -3.1, -2.75, 0.6)},
        {"name": "Crate", "prop": "crate", "x": -2.2, "z": -1.55, "box": (-2.53, -1.87, -2.1, -1.55, 0.9)},
        {"name": "Bed", "prop": "cel_bed", "upper": True, "split": True, "x": 1.75, "z": -1.65, "box": (1.4, 2.1, -3.05, -1.65, 0.4)},
        {"name": "UpBasket", "prop": "basket", "upper": True, "x": 0.0, "z": -1.6, "box": (-0.3, 0.3, -1.95, -1.6, 0.6)},
    ],
}
