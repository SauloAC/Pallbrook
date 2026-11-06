# The library: Cainos House 11. On the left a deep stone wing with a timbered gable, standing forward to
# the street, its chimney on its west side; on the right a long timbered hall set a little back and less
# deep, its big double doors standing open. One floor. Inside, the wing is the library proper: a reading
# table at the front, two rows of stacks, and at the back the fire with a rug, a small table and shelves on
# the back wall; the hall is lined with shelves along its back wall, with Sophia's desk, a round table and a
# lectern by the door.
SPEC = {
    "name": "Biblioteca", "facade": "art_source/facades/house11_noshadow.png",
    # the wing's front with its gable (its foot at row 353), the hall's front with its roof (its foot 28 rows
    # higher in the art, set back), and the hall's two open door leaves, swung out in front of it
    "planes": [{"rect": (0, 255, 160, 354), "base": 353, "z": 0.0},
               {"rect": (160, 0, 386, 326), "base": 325, "z": -1.143},
               {"rect": (296, 280, 314, 336), "base": 334, "z": -0.78},
               {"rect": (345, 280, 363, 336), "base": 334, "z": -0.78}],
    # the roof slope carries only the wing's roof: the hall's is in its own front plane
    "roof": {"on_plane": 0, "row": 255, "x_px": (0, 160), "beyond_top_row": 192},
    # the wing is as deep as its long roof in the art; the hall only as deep as its own roof
    "notch": {"x_px": 160, "z": -1.143, "depth": 5.0},
    "door_in_notch": True,
    "depth": 10.0, "wall_px": (36, 381), "room_height": 3.2, "door_px": (314, 346),
    "solid_uv": (0.3, 0.05), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "smoke_px": (25, 8),                                     # the chimney's top, far left
    "blocks": [{"name": "Fireplace", "x0": -4.5, "x1": -3.6, "z_back": -9.7, "z_front": -9.0, "height": 2.09,
                "front_tex": "fireplace_front", "light": (-4.05, 0.4, -8.7), "flame": (-4.066, 0.47, -8.98, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room: the wing x -4.61..-1.33 from the front (z -0.15) back to z -9.7; the hall x -1.33..5.58 behind
    # its front (z -1.29) back to z -4.7; the doorway x 3.78..4.78
    # Sophia behind her desk first, then readers: at the reading table, in the stacks, by the fire, in the hall
    "npc": {"slots": [(1.6, -3.45), (-2.8, -0.95), (-3.8, -0.95), (-2.0, -5.3), (-2.0, -7.1), (-3.0, -8.6),
                      (0.75, -3.6), (3.3, -3.7), (4.6, -3.5)]},
    "furniture": [
        # the wing, at the front: the reading table with stools (the way past it on the east)
        {"name": "ReadingTable", "prop": "table_cloth", "flat": True, "y": 0.57, "x": -3.3, "z": -2.0, "box": (-4.2, -2.4, -2.35, -1.65, 0.8)},
        {"name": "StoolR1", "prop": "stool", "x": -3.8, "z": -1.35, "box": (-3.98, -3.62, -1.65, -1.35, 0.5)},
        {"name": "StoolR2", "prop": "stool", "x": -2.8, "z": -1.35, "box": (-2.98, -2.62, -1.65, -1.35, 0.5)},
        # two rows of stacks across the wing, the walk beside them on the east
        {"name": "StackA1", "prop": "bookshelf", "x": -4.15, "z": -4.3, "box": (-4.6, -3.7, -4.6, -4.3, 1.9)},
        {"name": "StackA2", "prop": "bookshelf", "x": -3.25, "z": -4.3, "box": (-3.7, -2.8, -4.6, -4.3, 1.9)},
        {"name": "StackB1", "prop": "bookshelf", "x": -4.15, "z": -6.1, "box": (-4.6, -3.7, -6.4, -6.1, 1.9)},
        {"name": "StackB2", "prop": "bookshelf", "x": -3.25, "z": -6.1, "box": (-3.7, -2.8, -6.4, -6.1, 1.9)},
        # at the back: the fire and its rug, a small table with stools, shelves on the back wall
        {"name": "Candle", "prop": "candlestand", "x": -3.4, "z": -9.4, "box": (-3.55, -3.25, -9.7, -9.4, 1.2), "flames": [(6, 1)]},
        {"name": "HearthRug", "prop": "rug", "flat": True, "y": 0.025, "x": -4.05, "z": -8.45},
        {"name": "FireTable", "prop": "table_round", "x": -2.2, "z": -7.9, "box": (-2.5, -1.9, -8.4, -7.9, 0.8)},
        {"name": "FireStool1", "prop": "stool", "x": -2.8, "z": -7.7, "box": (-2.98, -2.62, -8.0, -7.7, 0.5)},
        {"name": "FireStool2", "prop": "stool", "x": -1.6, "z": -7.7, "box": (-1.78, -1.42, -8.0, -7.7, 0.5)},
        {"name": "ShelfBack1", "prop": "bookshelf", "x": -2.75, "z": -9.4, "box": (-3.2, -2.3, -9.7, -9.4, 1.9)},
        {"name": "ShelfBack2", "prop": "bookshelf", "x": -1.83, "z": -9.4, "box": (-2.28, -1.38, -9.7, -9.4, 1.9)},
        # the hall: shelves all along its back wall, the ladder at one, a round table, Sophia's desk, a lectern
        {"name": "Shelf1", "prop": "bookshelf", "x": -0.6, "z": -4.4, "box": (-1.05, -0.15, -4.7, -4.4, 1.9)},
        {"name": "Shelf2", "prop": "bookshelf", "x": 0.35, "z": -4.4, "box": (-0.1, 0.8, -4.7, -4.4, 1.9)},
        {"name": "Shelf3", "prop": "bookshelf", "x": 1.3, "z": -4.4, "box": (0.85, 1.75, -4.7, -4.4, 1.9)},
        {"name": "Shelf4", "prop": "bookshelf", "x": 2.25, "z": -4.4, "box": (1.8, 2.7, -4.7, -4.4, 1.9)},
        {"name": "HallLadder", "prop": "ladder", "x": 2.95, "z": -4.35, "box": (2.7, 3.2, -4.7, -4.35, 1.5)},
        {"name": "Shelf5", "prop": "bookshelf", "x": 3.7, "z": -4.4, "box": (3.25, 4.15, -4.7, -4.4, 1.9)},
        {"name": "Shelf6", "prop": "bookshelf", "x": 4.65, "z": -4.4, "box": (4.2, 5.1, -4.7, -4.4, 1.9)},
        {"name": "TableH", "prop": "table_round", "x": -0.3, "z": -2.5, "box": (-0.6, 0.0, -3.0, -2.5, 0.8)},
        {"name": "StoolH1", "prop": "stool", "x": -0.9, "z": -2.3, "box": (-1.08, -0.72, -2.6, -2.3, 0.5)},
        {"name": "StoolH2", "prop": "stool", "x": 0.3, "z": -2.3, "box": (0.12, 0.48, -2.6, -2.3, 0.5)},
        {"name": "Desk", "prop": "desk", "x": 1.6, "z": -2.3, "box": (0.88, 2.32, -2.65, -2.3, 0.9)},
        {"name": "Lectern", "prop": "lectern", "x": 5.1, "z": -2.4, "box": (4.85, 5.35, -2.7, -2.4, 1.0)},
    ],
}
