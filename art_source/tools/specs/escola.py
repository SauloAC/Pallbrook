# The school: Cainos House 08. A tall stone ground floor with the door and an open arch, a framed upper
# storey under a steep gable with the chimney on the left, and a wing set back on the right.
# Downstairs the entrance hall: a counter, benches to wait on in the wing, the fire in the hearth below
# the chimney. Stairs along the left wall, from just inside the door, to the schoolroom upstairs, which
# runs on into the wing: the pupils' desks, and in the wing the teacher's desk and the blackboard.
SPEC = {
    "name": "Escola", "facade": "art_source/facades/house08_noshadow.png",
    # the main front (its ground at the door, row 318) and the feet of its piers a little forward; the
    # wing's own front further back (its foot is 88 rows higher in the art), its ground floor (up to the top of
    # the beam under the framed storey, so upstairs it ends at the beam, not through the braces) and above
    "planes": [{"rect": (0, 165, 135, 318), "base": 318, "z": 0.0},
               {"rect": (0, 318, 135, 331), "base": 331, "z": 0.53},
               {"rect": (135, 147, 204, 230), "base": 230, "z": -3.59},
               {"rect": (135, 50, 204, 147), "base": 230, "z": -3.59}],
    "roof": {"on_plane": 0, "row": 165},
    "notch": {"x_px": 135, "z": -3.59},
    "depth": 6.6, "wall_px": (12, 196), "room_height": 6.9, "door_px": (25, 60),
    "solid_uv": (0.4, 0.12), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (25, 281, 60, 318), "hinge": "left"},
    "front_gaps": [{"px": (80, 118), "top_row": 282}],      # the open arch is a way in too
    "smoke_px": (31, 22),                                    # the chimney cap, top left
    # the upper floor is level with the jetty under the framed storey (row 230); upstairs the wing's
    # ground-floor wall comes back below it
    # the stairs start far enough back to walk past their foot from the door; the rail stops short of
    # the top, where one steps off sideways onto the schoolroom floor
    "upper": {"height": 4.28, "dir": "back", "width": 0.9, "start_z": -1.25, "run": 4.4, "steps": 20,
              "top_open": 1.0, "lower_front_plane": 0, "show_upstairs": [2], "fascia": [{"plane": 2, "px": (139, 199)}]},
    "blocks": [{"name": "Fireplace", "x0": -1.45, "x1": -0.55, "z_back": -6.3, "z_front": -5.6, "height": 2.09,
                "front_tex": "fireplace_front", "light": (-1.0, 0.4, -5.3), "flame": (-1.016, 0.47, -5.58, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room x -2.51..0.73 (and the wing x 1.03..2.64 behind z -3.59), back wall at z -6.3; door x -2.41..-1.31,
    # arch x -0.69..0.50; stairs x -2.51..-1.61 from z -1.25 to -5.65, the landing behind; upstairs the same, wing included
    # (townsfolk stay on the ground floor for now: behind the counter, on the benches, before the counter, by the arch;
    # every spot and the way to it keeps half a metre clear of walls and furniture, as the navigation mesh does)
    "npc": {"slots": [(0.1, -5.75), (1.75, -5.4), (2.25, -5.4), (-0.3, -4.3), (0.3, -1.8), (-0.9, -2.3),
                      (-0.2, -0.9)]},
    "furniture": [
        # the entrance hall: the counter toward the back, with room to walk past the wing's corner and
        # round it; the benches in the wing
        {"name": "Counter", "prop": "desk", "x": -0.3, "z": -4.85, "box": (-1.02, 0.42, -5.2, -4.85, 0.9)},
        {"name": "BenchBack", "prop": "pew", "x": 2.11, "z": -6.0, "box": (1.6, 2.62, -6.3, -6.0, 0.6)},
        {"name": "BenchFront", "prop": "pew", "x": 2.01, "z": -4.4, "box": (1.5, 2.52, -4.75, -4.4, 0.6)},
        # upstairs: the schoolroom
        {"name": "Blackboard", "prop": "blackboard", "upper": True, "x": -0.15, "z": -6.1, "box": (-0.85, 0.55, -6.3, -6.05, 1.6)},
        {"name": "Shelf", "prop": "bookshelf", "upper": True, "x": 1.45, "z": -6.05, "box": (1.0, 1.9, -6.3, -6.0, 1.9)},
        {"name": "TeacherDesk", "prop": "desk", "upper": True, "x": 1.9, "z": -4.4, "box": (1.2, 2.6, -4.75, -4.4, 0.9)},
        {"name": "DeskA1", "prop": "schooldesk", "upper": True, "x": -1.0, "z": -1.6, "box": (-1.4, -0.6, -1.9, -1.6, 0.7)},
        {"name": "DeskB1", "prop": "schooldesk", "upper": True, "x": 0.2, "z": -1.6, "box": (-0.2, 0.6, -1.9, -1.6, 0.7)},
        {"name": "DeskA2", "prop": "schooldesk", "upper": True, "x": -1.0, "z": -2.6, "box": (-1.4, -0.6, -2.9, -2.6, 0.7)},
        {"name": "DeskB2", "prop": "schooldesk", "upper": True, "x": 0.2, "z": -2.6, "box": (-0.2, 0.6, -2.9, -2.6, 0.7)},
        {"name": "DeskA3", "prop": "schooldesk", "upper": True, "x": -1.0, "z": -3.6, "box": (-1.4, -0.6, -3.9, -3.6, 0.7)},
        {"name": "DeskB3", "prop": "schooldesk", "upper": True, "x": 0.2, "z": -3.6, "box": (-0.2, 0.6, -3.9, -3.6, 0.7)},
        {"name": "DeskA4", "prop": "schooldesk", "upper": True, "x": -1.0, "z": -4.6, "box": (-1.4, -0.6, -4.9, -4.6, 0.7)},
        {"name": "DeskB4", "prop": "schooldesk", "upper": True, "x": 0.2, "z": -4.6, "box": (-0.2, 0.6, -4.9, -4.6, 0.7)},
    ],
}
