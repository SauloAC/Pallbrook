# The town hall: Cainos House 07. The hall is the stone hall with its door and the open arch beside it,
# and the ground floor of the clock tower (behind the covered gateway on posts). At the far left, under a
# lean-to roof, steps go up to a side door in the tower's west wall (out of sight at this angle): a third
# way in. Inside: the council table, the clerk's desk with the register, shelves of records, a fire in
# the hearth, a bench in the tower. (No upper floor; no chimney in the art.)
# (6 Nov) The record shelves are cel-shaded bookcases (art_source/tools/furniture/).
SPEC = {
    "name": "Prefeitura", "facade": "art_source/facades/house07_noshadow.png",
    # the hall's front (its ground at the door, row 230) and the feet of its piers a little forward, the
    # tower behind the gateway, the lean-to and its post, and the gateway's posts and roof out in front
    "planes": [{"rect": (145, 185, 335, 230), "base": 230, "z": 0.0},
               {"rect": (145, 230, 335, 241), "base": 241, "z": 0.449},
               {"rect": (45, 185, 145, 249), "base": 249, "z": 0.775},
               {"rect": (0, 185, 45, 236), "base": 236, "z": 0.245},
               {"rect": (0, 236, 45, 242), "base": 242, "z": 0.49},
               {"rect": (50, 160, 145, 391), "base": 391, "z": 6.572}],
    "roof": {"on_plane": 0, "row": 185},
    # the lean-to and its steps are outside the hall: on show while the doctor is in
    "stays": {"x_px": (0, 45), "planes": [3, 4]},
    # the side door at the top of the steps, in the tower's west wall
    "west_gaps": [(-0.35, -1.65)],
    "depth": 5.0, "wall_px": (45, 330), "room_height": 3.0, "door_px": (262, 294),
    "solid_uv": (0.6, 0.45), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (262, 192, 295, 229), "hinge": "left"},
    # the open arch beside the door is a way in too
    "front_gaps": [{"px": (170, 213), "top_row": 193}],
    # in front of the tower, behind its painted front; the gateway's two posts; the lean-to's post
    "posts": [(45, 145, 0.15, 0.775), (57, 69, 6.27, 6.572), (127, 139, 6.27, 6.572), (4, 12, 0.2, 0.49)],
    "blocks": [{"name": "Fireplace", "x0": 0.2, "x1": 1.1, "z_back": -4.7, "z_front": -4.0, "height": 2.09,
                "front_tex": "fireplace_front", "light": (0.65, 0.4, -3.7), "flame": (0.634, 0.47, -3.98, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -3.53..4.78, back wall at z -4.7; door x 2.95..3.95, arch x 0.0..1.33; the tower x -3.53..-0.7,
    # its side door in the west wall at z -0.35..-1.65
    # the mayor behind the clerk's desk first, then round the council table, the tower, by the door
    "npc": {"slots": [(3.9, -4.15), (0.0, -2.3), (2.8, -2.3), (1.4, -1.3), (3.9, -2.4), (-2.3, -3.6),
                      (-1.5, -2.0), (2.2, -0.9), (-2.0, -1.3)]},
    "furniture": [
        {"name": "Desk", "prop": "cel_desk", "x": 3.9, "z": -3.25, "box": (3.18, 4.62, -3.6, -3.25, 0.9)},   # room behind it for the mayor
        {"name": "ShelfA", "prop": "cel_bookshelf_c", "x": 1.85, "z": -4.45, "box": (1.4, 2.3, -4.7, -4.4, 1.9)},
        {"name": "ShelfB", "prop": "cel_bookshelf_a", "x": 2.8, "z": -4.45, "box": (2.35, 3.25, -4.7, -4.4, 1.9)},
        {"name": "Table", "prop": "table_cloth", "flat": True, "y": 0.57, "x": 1.4, "z": -2.3, "box": (0.5, 2.3, -2.65, -1.95, 0.7)},
        {"name": "StoolA", "prop": "stool", "x": 0.9, "z": -1.65, "box": (0.72, 1.08, -1.95, -1.65, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 1.9, "z": -1.65, "box": (1.72, 2.08, -1.95, -1.65, 0.5)},
        {"name": "Barrel", "prop": "barrel_a", "x": 4.45, "z": -0.6, "box": (4.15, 4.75, -1.0, -0.6, 0.8)},
        # the tower: a bench along its back wall and a rug
        {"name": "Bench", "prop": "cel_pew", "split": "seat", "x": -2.3, "z": -4.35, "box": (-2.81, -1.79, -4.7, -4.35, 0.6)},
        {"name": "SideRug", "prop": "rug_v", "flat": True, "y": 0.025, "x": -3.2, "z": -1.0},   # at the side door, along it
        {"name": "Crate", "prop": "crate", "x": -1.1, "z": -0.6, "box": (-1.45, -0.75, -1.1, -0.6, 0.9)},
    ],
}
