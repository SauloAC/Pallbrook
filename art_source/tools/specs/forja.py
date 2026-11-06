# Tomas's forge: Cainos Blacksmith 01. A long open shed on posts, its forge hearth on the left with the
# chimney going up through the roof, and standing out in front of it in the middle a small stone house
# with a gable, where Tomas lives. The shed is open to the street: on the left the hearth, and beside it
# the anvil and the quenching trough, Tomas's work; on the right the fuel, logs and a heap of coal. The house:
# one room, his table and a rack of finished tools at the front, his bed at the back, with a door straight
# out into the forge ("the anvil is louder at night"). The location is still "Casa2" (Tomas's home).
#
# Local units: the house's front wall (the door) at z 0; the shed's front, on its posts, at z -3.141 (the
# posts' feet 77 rows above the house's in the art); everything ends at the back at z -6.0 (the house's ridge
# runs back to the art's row 41, the shed's flat roof to row 68). The house x 0.42..2.77 (walls 0.25 thick),
# the shed x -4.73..4.70; inside, the shed's left part x -4.48..0.42, its right part x 2.77..4.45.
ZS = -3.141           # the shed's front
D = 6.0
ZB = D * -1 + 0.25    # inside face of the back wall
HIN = 2.1
SPEC = {
    "name": "Casa2", "facade": "art_source/facades/blacksmith01_noshadow.png",
    "planes": [
        # the house's front: its gable with the roof's eaves either side, the stone wall and the door
        {"rect": (165, 186, 253, 259), "base": 258, "z": 0.0},
        # the shed's front: its roof face (the chimney above it), the posts and the hearth under the eave;
        # the house's columns belong to the house's roof
        {"rect": (0, 0, 317, 182), "base": 181, "z": ZS, "keep_cols": [(0, 165), (253, 317)], "keep_from": 0},
        # the posts alone, standing on inside once the roof they hold is cut away
        {"rect": (0, 141, 317, 182), "base": 181, "z": ZS, "keep_cols": [(7, 15), (134, 142), (301, 309)], "keep_from": 141},
    ],
    "inside_planes": [2],
    # only the house's roof slopes back; the shed's roof is painted in its own front plane
    "roof": {"on_plane": 0, "row": 186, "x_px": (165, 253)},
    "depth": D, "wall_px": (7, 309), "wall_t": 0.25, "room_height": HIN, "door_px": (196, 224),
    "door_art": {"rect": (196, 221, 224, 258), "hinge": "left"},
    "solid_uv": (0.568, 0.073), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "smoke_px": (74, 3),                                     # the chimney's top, over the hearth
    "plan": {
        "floors": [
            # the shed's earth floor shows from the street, between the posts
            {"rect": (-4.734, 0.422, -D, ZS), "tile": "tile_dirt_floor.png", "outside": True},
            {"rect": (2.766, 4.703, -D, ZS), "tile": "tile_dirt_floor.png", "outside": True},
            {"rect": (0.422, 2.766, -D, 0.0)},                    # the house: boards
        ],
        "inner_walls": [(-4.484, 4.453, ZB)],
        # wall tops: the shed's ends and back at the room's height; the house's two walls, which stand inside
        # the shed, drawn low on the floor, so what is seen of them is where they block (a top at the room's
        # height shows 1.8 further back than the wall, across the door into the forge)
        "caps": [(-4.734, -4.484, ZS, -D), (4.453, 4.703, ZS, -D), (-4.734, 4.703, ZB, -D),
                 (0.422, 0.672, -0.015, -3.55, 0.03), (0.422, 0.672, -4.55, ZB, 0.03),
                 (2.516, 2.766, -0.015, ZB, 0.03)],
        "walls": [("Back", -4.734, 4.703, -D, ZB),
                  ("ShedWest", -4.734, -4.484, ZS + 0.15, -D), ("ShedEast", 4.453, 4.703, ZS + 0.15, -D),
                  ("PostMid", -0.766, -0.516, ZS + 0.12, ZS - 0.12, 0, 2.5),
                  ("WingWest", 0.422, 0.672, 0.15, -3.55), ("WingWestBack", 0.422, 0.672, -4.55, ZB),
                  ("WingEast", 2.516, 2.766, 0.15, ZB),
                  ("FrontLeft", 0.422, 1.172, 0.15, -0.15), ("FrontRight", 2.047, 2.766, 0.15, -0.15),
                  ("Lintel", 1.172, 2.047, 0.15, -0.15, 1.8, 3.2)],
        # the volume, for shadows: the shed under its flat roof, the house to its eaves
        "body": [(-4.734, 4.703, -D, ZS, 2.05), (0.422, 2.766, -D, 0.0, 1.85)],
    },
    # the hearth, against the back wall as in the art (its foot 14 rows behind the posts'): its front cut
    # from the art, the coals glowing in its mouth (the light is ForgeFire in Cidade.tscn, seen from the street too)
    "blocks": [{"name": "Hearth", "x0": -3.547, "x1": -1.703, "z_back": ZB, "z_front": -3.71, "height": 2.09,
                "front_tex": "forge_front", "flame": (-2.625, 0.5, -3.69, 0.62, 0.4),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # Tomas at the anvil first, then: before the anvil, at the hearth, in the front of the house, by his table,
    # among the fuel, by the door from the house
    "npc": {"slots": [(-1.15, -4.95), (-1.15, -3.65), (-2.6, -3.42), (1.95, -1.8), (1.0, -2.25), (3.6, -3.6), (0.05, -3.9)],
            "bed": (2.15, 0.0, -4.47, 0.0)},
    "furniture": [
        # the shed's things are seen from the street too, under the eave ("outside")
        # the forge: the anvil beside the hearth's corner (clear of the middle post on screen), the
        # quenching trough behind it on the back wall
        {"name": "Anvil", "outside": True, "prop": "anvil", "x": -1.15, "z": -4.3, "box": (-1.57, -0.73, -4.5, -4.2, 0.7)},
        {"name": "Trough", "outside": True, "prop": "trough", "x": -0.75, "z": -5.5, "box": (-1.45, -0.05, -5.75, -5.45, 0.6)},
        # beside the hearth on the left: a barrel of rods and a bucket
        {"name": "RodBarrel", "outside": True, "prop": "barrel_tools", "x": -4.0, "z": -5.4, "box": (-4.33, -3.67, -5.75, -5.3, 0.8)},
        {"name": "Bucket", "outside": True, "prop": "bucket", "x": -4.05, "z": -4.3, "box": (-4.33, -3.77, -4.5, -4.15, 0.6)},
        # the right of the shed: the fuel
        {"name": "Logs", "outside": True, "prop": "logs", "x": 3.7, "z": -5.4, "box": (3.15, 4.25, -5.75, -5.2, 1.0)},
        {"name": "Coal", "outside": True, "prop": "coal", "x": 3.35, "z": -4.45, "box": (2.95, 3.75, -4.7, -4.25, 0.6)},
        # the front of the room: the tools he has made, on a standing rack; his table and stool by the west
        # wall. The way from the door to the back stays clear (the doctor is 0.72 local wide).
        {"name": "ToolRack", "prop": "rack_tools", "x": 2.1, "z": -2.6, "box": (1.72, 2.5, -2.85, -2.55, 1.0)},
        {"name": "Table", "prop": "table_round", "x": 1.0, "z": -1.35, "box": (0.7, 1.3, -1.6, -1.1, 0.8)},
        {"name": "Stool", "prop": "stool", "x": 1.0, "z": -0.7, "box": (0.82, 1.18, -0.85, -0.55, 0.5)},
        # the back of the room: the bed along the east wall, a cabinet
        {"name": "Bed", "prop": "cel_bed", "split": True, "x": 2.15, "z": -4.35, "box": (1.8, 2.5, -5.75, -4.35, 0.4)},
        {"name": "Cabinet", "prop": "cabinet", "x": 1.05, "z": -5.55, "box": (0.7, 1.4, -5.75, -5.45, 1.6)},
    ],
}
