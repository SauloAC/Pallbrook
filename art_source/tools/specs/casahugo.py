# Father Elias (since 3 Nov; first built for Hugo): Cainos House 15, a wooden house raised on posts, the door up on a porch with two steps
SPEC = {
    "name": "CasaHugo", "facade": "art_source/facades/house15_noshadow.png",
    "floor_y": 0.3,                  # the floor sits on posts, level with the porch
    # the front wall with the door under the gable (its ground is below the porch floor, at row 211),
    # and the porch's edge, the posts and the steps in front
    "planes": [{"rect": (0, 162, 192, 205), "base": 211.17, "z": 0.0},
               {"rect": (0, 234, 192, 244), "base": 242.17, "z": 1.265}],
    "porch": {"rect": (22, 205, 170, 236), "plane": 0},
    "steps": {"x_px": (76, 119), "z": (1.265, 1.83), "rect": (72, 236, 123, 257)},   # the slope runs from the porch edge (row 236) to the ground (row 256)
    "roof": {"on_plane": 0, "row": 162},
    "depth": 4.6, "wall_px": (33, 160), "room_height": 2.39, "door_px": (79, 112),
    "solid_uv": (0.5, 0.24), "inner_wall_tile": "tile_wood_wall.png",
    "door_art": {"rect": (79, 168, 112, 205), "hinge": "left"},
    "smoke_px": (143, 52),           # the hooded chimney cap in the facade art
    # the chimney stands at the back right: its fireplace inside, in that corner
    "blocks": [{"name": "Fireplace", "x0": 0.75, "x1": 1.65, "z_back": -4.3, "z_front": -3.6, "height": 2.09,
                "front_tex": "fireplace_front", "light": (1.2, 0.4, -3.3), "flame": (1.184, 0.47, -3.58, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -1.67..1.70, back wall at z -4.3, floor 0.3 up; door x -0.53..0.50
    "npc": {"slots": [(0.0, -1.25), (-0.55, -1.1), (0.9, -1.5)],  # before the table, by the crate, by the jar
                                                                  # (behind the table is too narrow to walk to)
            "bed": (-1.27, 0.3, -3.02, 0.0)},
    "furniture": [
        {"name": "Bed", "prop": "cel_bed", "split": True, "x": -1.27, "z": -2.9, "box": (-1.62, -0.92, -4.3, -2.9, 0.4)},
        {"name": "Table", "prop": "table_cloth", "flat": True, "y": 0.57, "x": 0.0, "z": -2.4, "box": (-0.9, 0.9, -2.75, -2.05, 0.7)},
        {"name": "StoolA", "prop": "stool", "x": -0.4, "z": -1.75, "box": (-0.58, -0.22, -2.05, -1.75, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.4, "z": -1.75, "box": (0.22, 0.58, -2.05, -1.75, 0.5)},
        {"name": "Jar", "prop": "jar", "x": 1.45, "z": -0.9, "box": (1.22, 1.68, -1.25, -0.9, 0.7)},
        {"name": "Crate", "prop": "crate", "x": -1.3, "z": -0.8, "box": (-1.65, -0.95, -1.3, -0.8, 0.9)},
        {"name": "Basket", "prop": "basket", "x": 0.3, "z": -3.95, "box": (0.0, 0.6, -4.3, -3.95, 0.6)},
    ],
}
