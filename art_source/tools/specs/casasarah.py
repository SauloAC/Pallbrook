# Sarah: Cainos House 02, a framed upper storey over a stone ground floor, a balcony on the right.
# The art had no front door: its stone wall was carried left to the post and a door painted in
# (art_source/facades/house02_door.png, the door from the bakery's stone front).
SPEC = {
    "name": "CasaSarah", "facade": "art_source/facades/house02_door.png",
    "planes": [{"rect": (0, 240, 181, 343), "base": 343, "z": 0.0}],
    "roof": {"on_plane": 0, "row": 240},
    "depth": 5.7, "wall_px": (15, 131), "room_height": 5.0, "door_px": (15, 56),
    "solid_uv": (0.5, 0.97), "inner_wall_tile": "tile_stone_wall.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (21, 298, 48, 341), "hinge": "left"},
    # two floors: stairs along the left wall from just inside the door, rising to the back
    "upper": {"height": 2.43, "dir": "back", "width": 1.0, "start_z": -1.3, "run": 2.8, "steps": 14,
              "lower_front_plane": 0},
    # the balcony on the right, at the level of the upper floor, reached through the east wall
    "deck": {"rect": (136, 126, 181, 265), "plane": 0, "y": 2.43, "walk": (166, 165, 254),
             "fill_rows": (141, 265)},
    # seen from upstairs, the balcony keeps its brace and the hanging lantern below it
    "keep_inside": [{"rect": (130, 262, 181, 296)}],
    "lamps": [{"px": (168, 281)}],   # the lantern hanging under the balcony
    "smoke_px": (69, 24),             # the chimney cap in the facade art
    # the chimney rises from the middle of the roof: its fireplace against the back wall below it
    "blocks": [{"name": "Fireplace", "x0": -1.0, "x1": -0.1, "z_back": -5.4, "z_front": -4.7, "height": 2.43,
                "front_tex": "fireplace_front", "light": (-0.55, 0.4, -4.4), "flame": (-0.566, 0.51, -4.68, 0.36, 0.48),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -2.06..0.97, back wall at z -5.4; stairs x -2.06..-1.06 from z -1.3 to -4.1
    "npc": {"slots": [(0.2, -2.3), (-0.5, -1.0), (0.5, -1.6)],  # at the table, by the door, mid-room
            "bed": (0.4, 2.43, -4.02, 0.0),
            "bed_approach": (-0.4, 2.43, -3.6)},
    "furniture": [
        {"name": "Table", "prop": "table_round", "x": 0.2, "z": -3.0, "box": (-0.1, 0.5, -3.5, -3.0, 0.8)},
        {"name": "StoolA", "prop": "stool", "x": -0.35, "z": -2.85, "box": (-0.53, -0.17, -3.15, -2.85, 0.5)},
        {"name": "StoolB", "prop": "stool", "x": 0.72, "z": -2.85, "box": (0.54, 0.9, -3.15, -2.85, 0.5)},
        {"name": "Barrel", "prop": "barrel_a", "x": 0.55, "z": -4.75, "box": (0.2, 0.9, -5.4, -4.75, 0.8)},
        {"name": "Crate", "prop": "crate", "x": -1.55, "z": -4.85, "box": (-1.9, -1.2, -5.4, -4.85, 0.9)},
        {"name": "Bed", "prop": "cel_bed", "upper": True, "split": True, "x": 0.4, "z": -3.9, "box": (0.05, 0.75, -5.3, -3.9, 0.4)},
        {"name": "UpBasket", "prop": "basket", "upper": True, "x": 0.3, "z": -1.4, "box": (0.0, 0.6, -1.75, -1.4, 0.6)},
    ],
}
