# The farm's store: Cainos Warehouse 01, a timber shed. The left bay is boarded up in front; the right bay
# stands open, and through it you walk in among the sacks, barrels and crates.
SPEC = {
    "name": "Deposito", "facade": "art_source/facades/warehouse01_noshadow.png",
    "planes": [{"rect": (0, 115, 256, 162), "base": 160, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 115},
    "depth": 4.0, "wall_px": (34, 222), "room_height": 2.19,
    "door_px": (132, 216),           # the open bay
    "door_rug": False,
    "solid_uv": (0.3125, 0.27), "inner_wall_tile": "tile_wood_wall.png",
    "floor_tile": "tile_dirt_floor.png",
    "floor_outside": True,           # the earth floor shows through the open bay from outside
    # room x -2.64..2.64, back wall at z -3.7; the open bay x 0.13..2.75
    # where people stand (Ada sorting her goods at dawn): in the open bay, by the stores
    "npc": {"slots": [(1.3, -2.1), (-0.4, -2.5), (2.0, -2.4)]},
    "furniture": [
        # behind the boards: the stores
        {"name": "BarrelStack", "prop": "barrel_stack", "x": -1.9, "z": -3.0, "box": (-2.55, -1.25, -3.7, -3.0, 1.0)},
        {"name": "Crate", "prop": "crate", "x": -0.7, "z": -3.2, "box": (-1.05, -0.35, -3.7, -3.2, 0.9)},
        {"name": "SackA", "prop": "sack_a", "x": -2.3, "z": -1.4, "box": (-2.55, -2.05, -1.75, -1.4, 0.7)},
        {"name": "SackB", "prop": "sack_b", "x": -1.75, "z": -1.3, "box": (-2.0, -1.5, -1.65, -1.3, 0.7)},
        {"name": "FoodCrate", "prop": "foodcrate", "x": -0.7, "z": -1.6, "box": (-1.05, -0.35, -1.9, -1.6, 0.6)},
        # under the open bay
        {"name": "BayCrate", "prop": "crate", "x": 2.2, "z": -3.2, "box": (1.85, 2.55, -3.7, -3.2, 0.9)},
        {"name": "BayBarrel", "prop": "barrel_a", "x": 1.4, "z": -3.25, "box": (1.05, 1.75, -3.7, -3.25, 0.8)},
        {"name": "BaySack", "prop": "sack_b", "x": 0.6, "z": -3.35, "box": (0.35, 0.85, -3.7, -3.35, 0.7)},
        {"name": "BayBasket", "prop": "basket", "x": 2.25, "z": -1.2, "box": (1.95, 2.55, -1.55, -1.2, 0.6)},
    ],
}
