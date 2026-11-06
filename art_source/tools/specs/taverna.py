# The tavern: Cainos House 04. An L: on the left a wing standing forward to the street, stone below and
# a timbered storey above; on the right the main house set back behind a courtyard, its door on the
# courtyard. The chimney on the left wing. Downstairs the tavern hall through both: round tables in the
# wing, the fire on its back wall with a rug before it, Marta's bar in the main house with the bottles and
# barrels behind it and stools before it, the stairs beside the door. Upstairs, in the wing, a corridor with
# three rooms off it (Marta's at the back, two for guests); over the main house a small landing hall.
# Lunch is out in the courtyard (its tables are town props).
SPEC = {
    "name": "Taverna", "facade": "art_source/facades/house04_noshadow.png",
    # the wing's front (its foot at row 319), the main house's ground floor (its foot 99 rows higher in the
    # art, set back), and above it the main house's timbered storey with its roof
    "planes": [{"rect": (0, 218, 137, 319), "base": 319, "z": 0.0},
               {"rect": (137, 163, 277, 220), "base": 220, "z": -4.039},
               {"rect": (137, 0, 277, 163), "base": 220, "z": -4.039}],
    # the roof slope carries only the wing's roof: the main house's is in its own front plane
    "roof": {"on_plane": 0, "row": 218, "x_px": (0, 137)},
    "notch": {"x_px": 137, "z": -4.039},
    "door_in_notch": True,
    "depth": 8.8, "wall_px": (9, 266), "room_height": 5.0, "door_px": (204, 230),
    "solid_uv": (0.22, 0.06), "inner_wall_tile": "tile_stone_light.png", "inner_wall_tile_px": (128, 40),
    "door_art": {"rect": (204, 180, 230, 217), "plane": 1, "hinge": "left"},
    "smoke_px": (32, 30),                                    # the chimney cap, top left
    # the stairs along the east wall, from a little inside the door (room to turn in) up toward the back;
    # the landing is shallow, so the rail stops short of the top and one steps off to the left
    "upper": {"height": 2.77, "dir": "back", "side": "right", "width": 0.85, "start_z": -5.2, "run": 2.9,
              "steps": 16, "top_open": 0.9, "lower_front_plane": 0, "show_upstairs": [1],
              # the rooms in the wing: the corridor's wall (a door into each room) and the walls between them
              "walls": [{"x": (-1.65, -1.45), "z": (-0.15, -8.5), "gaps": [(-0.9, -1.85), (-3.7, -4.65), (-6.55, -7.5)]},
                        {"x": (-3.75, -1.45), "z": (-2.8, -3.0)},
                        {"x": (-3.75, -1.45), "z": (-5.6, -5.8)}]},
    "blocks": [{"name": "Fireplace", "x0": -3.65, "x1": -2.75, "z_back": -8.5, "z_front": -7.8, "height": 2.09,
                "front_tex": "fireplace_front", "light": (-3.2, 0.4, -7.5), "flame": (-3.216, 0.47, -7.78, 0.36, 0.44),
                "top_tile": "tile_stone_wall.png", "top_tile_px": (128, 40)}],
    # room: the wing x -3.75..-0.35 from the front (z -0.15) back to z -8.5; the main house x -0.35..3.68
    # behind its front (z -4.19); door x 2.05..2.86; stairs x 2.83..3.68 from z -5.2 to -8.1
    # Marta behind the bar first, then about the hall; then out in the courtyard on the benches and by the
    # round tables, where lunch is (see NPC.gd)
    "npc": {"slots": [(1.2, -7.35), (-1.0, -2.9), (-0.9, -5.3), (1.2, -5.2),
                      (0.9, -3.0), (1.55, -3.0), (2.2, -1.0), (0.35, -1.3),
                      (0.93, -1.3), (1.5, -1.3), (4.2, -1.65), (2.4, -0.3)],
            "bed": (-3.4, 2.77, -7.16, 0.0),
            "bed_approach": (-2.4, 2.77, -7.0)},
    "furniture": [
        # the bar: the counter with three stools before it, the bottles and the barrels behind it
        {"name": "Bar", "prop": "table", "flat": True, "y": 0.57, "x": 1.2, "z": -6.5, "box": (0.3, 2.1, -6.85, -6.15, 0.9)},
        {"name": "BarStool1", "prop": "stool", "x": 0.6, "z": -5.65, "box": (0.42, 0.78, -5.95, -5.65, 0.5)},
        {"name": "BarStool2", "prop": "stool", "x": 1.2, "z": -5.65, "box": (1.02, 1.38, -5.95, -5.65, 0.5)},
        {"name": "BarStool3", "prop": "stool", "x": 1.8, "z": -5.65, "box": (1.62, 1.98, -5.95, -5.65, 0.5)},
        {"name": "Bottles", "prop": "cel_cabinet", "x": 0.25, "z": -8.15, "box": (-0.05, 0.55, -8.5, -8.15, 1.6)},
        {"name": "Bottles2", "prop": "cel_cabinet", "x": 0.9, "z": -8.15, "box": (0.6, 1.2, -8.5, -8.15, 1.6)},
        {"name": "BarrelStack", "prop": "barrel_stack", "x": 1.95, "z": -7.79, "box": (1.3, 2.6, -8.5, -7.79, 1.0)},
        # the hall in the wing: round tables, the rug before the fire, barrels and a crate in the corners
        {"name": "TableA", "prop": "table_round", "x": -2.3, "z": -1.7, "box": (-2.6, -2.0, -2.2, -1.7, 0.8)},
        {"name": "StoolA1", "prop": "stool", "x": -2.9, "z": -1.5, "box": (-3.08, -2.72, -1.8, -1.5, 0.5)},
        {"name": "StoolA2", "prop": "stool", "x": -1.7, "z": -1.5, "box": (-1.88, -1.52, -1.8, -1.5, 0.5)},
        {"name": "TableB", "prop": "table_round", "x": -2.3, "z": -4.2, "box": (-2.6, -2.0, -4.7, -4.2, 0.8)},
        {"name": "StoolB1", "prop": "stool", "x": -2.9, "z": -4.0, "box": (-3.08, -2.72, -4.3, -4.0, 0.5)},
        {"name": "StoolB2", "prop": "stool", "x": -1.7, "z": -4.0, "box": (-1.88, -1.52, -4.3, -4.0, 0.5)},
        {"name": "TableC", "prop": "table_round", "x": -1.5, "z": -6.3, "box": (-1.8, -1.2, -6.8, -6.3, 0.8)},
        {"name": "StoolC1", "prop": "stool", "x": -2.1, "z": -6.1, "box": (-2.28, -1.92, -6.4, -6.1, 0.5)},
        {"name": "StoolC2", "prop": "stool", "x": -0.9, "z": -6.1, "box": (-1.08, -0.72, -6.4, -6.1, 0.5)},
        {"name": "HearthRug", "prop": "rug", "flat": True, "y": 0.025, "x": -3.0, "z": -7.35},
        {"name": "Barrel", "prop": "barrel_a", "x": -3.4, "z": -0.55, "box": (-3.72, -3.08, -1.2, -0.55, 0.8)},
        {"name": "Crate", "prop": "crate", "x": -0.75, "z": -0.6, "box": (-1.05, -0.45, -1.1, -0.6, 0.9)},
        {"name": "Sack", "prop": "sack_a", "x": -0.1, "z": -8.0, "box": (-0.32, 0.12, -8.5, -8.0, 0.7)},
        # out in the courtyard, at the scale of the house: a long table with a bench either side, and two
        # round tables with a stool either side (the bench behind the long table stands far enough back to show
        # over it, as the pack draws them); the benches and stools are seats (Seat markers in
        # Cidade.tscn), so they have no collision. The way from the street to the door runs between them.
        {"name": "YardBenchBack", "prop": "bench_h", "outside": True, "x": 0.93, "z": -2.9},
        {"name": "YardTable", "prop": "table", "outside": True, "x": 0.93, "z": -1.6, "box": (0.03, 1.83, -2.2, -1.6, 0.8)},
        {"name": "YardBenchFront", "prop": "bench_h", "outside": True, "x": 0.93, "z": -1.2},
        {"name": "YardRoundA", "prop": "table_round", "outside": True, "x": 3.55, "z": -2.6, "box": (3.25, 3.85, -3.1, -2.6, 0.8)},
        {"name": "YardStoolA1", "prop": "stool", "outside": True, "x": 2.95, "z": -2.3},
        {"name": "YardStoolA2", "prop": "stool", "outside": True, "x": 4.15, "z": -2.3},
        {"name": "YardRoundB", "prop": "table_round", "outside": True, "x": 3.55, "z": -0.8, "box": (3.25, 3.85, -1.3, -0.8, 0.8)},
        {"name": "YardStoolB1", "prop": "stool", "outside": True, "x": 2.95, "z": -0.5},
        {"name": "YardStoolB2", "prop": "stool", "outside": True, "x": 4.15, "z": -0.5},
        # upstairs, the rooms off the corridor: a guest's at the front with a table, a guest's in the middle
        # with a crate, Marta's at the back with her chest of drawers
        {"name": "GuestBed", "prop": "cel_bed", "upper": True, "split": True, "x": -3.4, "z": -1.39, "box": (-3.74, -3.06, -2.75, -1.39, 0.4)},
        {"name": "GuestTable", "prop": "table_round", "upper": True, "x": -2.3, "z": -0.7, "box": (-2.6, -2.0, -1.2, -0.7, 0.8)},
        {"name": "GuestBed2", "prop": "cel_bed", "upper": True, "split": True, "x": -3.4, "z": -4.24, "box": (-3.74, -3.06, -5.6, -4.24, 0.4)},
        {"name": "GuestCrate", "prop": "crate", "upper": True, "x": -2.3, "z": -3.6, "box": (-2.6, -2.0, -4.1, -3.6, 0.9)},
        {"name": "Bed", "prop": "cel_bed", "upper": True, "split": True, "x": -3.4, "z": -7.04, "box": (-3.74, -3.06, -8.4, -7.04, 0.4)},
        {"name": "Cabinet", "prop": "cel_cabinet", "upper": True, "x": -2.4, "z": -8.15, "box": (-2.7, -2.1, -8.5, -8.15, 1.6)},
        # the landing hall over the main house: a table and a stool, a barrel
        {"name": "HallTable", "prop": "table_round", "upper": True, "x": 0.9, "z": -5.3, "box": (0.6, 1.2, -5.8, -5.3, 0.8)},
        {"name": "HallStool", "prop": "stool", "upper": True, "x": 0.3, "z": -5.1, "box": (0.12, 0.48, -5.4, -5.1, 0.5)},
        {"name": "HallBarrel", "prop": "barrel_b", "upper": True, "x": 2.3, "z": -4.85, "box": (2.0, 2.6, -5.5, -4.85, 0.8)},
    ],
}
