# The cel-shaded furniture

`assets/buildings2d/props/prop_cel_*.png`, placed by the building specs like any other prop
(`"prop": "cel_bed"`; the generator treats a `cel_` piece as the kind after the prefix, so a
`cel_stool` is still a seat and a `cel_table...` still a table).

The pieces are modelled in `render/render.gd` from plain boxes and cylinders (no outside assets) and
rendered the way the Cainos art is drawn: from the front and above, a pixel of height for every 1/32 m,
tops shortened to 0.6 of their depth. `render/ramp.gdshader` paints them as pixel art is painted (after
Saulo's references, 6 Nov): four shades of each material, hue-shifted (shades toward red and purple,
lights toward orange; between the references' saturated wood and the browner Cainos art), picked by how
a face meets the light; every board bevelled, its top edge or front lip a pixel lighter and its foot a
pixel darker; planks with a dark seam and a lit edge, a little lighter or darker each; a grain of short
dark streaks along the wood. The outline and the lines between parts are a dark red-purple.

Each piece also casts a shadow, down and right as the references draw them: rendered pressed flat onto
the floor (its footprint), `finish.py` makes `prop_<piece>_shadow.png` of it, SHADOW_PAD px larger, and
the generator lays it flat just over the floor under any piece that has one, in
`assets/buildings2d/prop_shadow.gdshader` (a soft dark purple). Each piece is rendered twice, in
colour and with each part in a flat colour of its own; `finish.py` uses the second to draw the dark
lines between parts and around the piece, then crops it.

    cd render
    godot --path . render.tscn -- <out dir> [piece ...]
    python3 ../finish.py <out dir> <out dir> [piece ...]     # writes prop_<piece>.png
    # then copy prop_<piece>.png to assets/buildings2d/props/prop_cel_<piece>.png

A bed is rendered a third time, each part in the colour of its layer, and `finish.py` also writes it
in three layers (`prop_bed_foot`, `_body`, `_head`, each the size of the whole picture). With
`"split": True` in a spec the generator stands the foot at the front of the footprint ("z"), lays the
body flat half a metre up and stands the head 1.37 further back, each where its pixels stay in place on
screen: someone lying in the bed (NPC.BED_HEIGHT) shows over the blanket, the footboard over their feet.
The sleeper's spot (the spec's "bed") is just behind the footboard.

In use: `bed` (split, in every home and the clinic); `cabinet` (the clinic, the forge, the tavern);
`bookshelf_a`, `_b`, `_c` (the same bookcase, filled three ways: the library, the school, the town hall);
`blackboard` (the school); `pew` (the church, the school: its back toward the camera, as
whoever sits on it faces north; in two layers, `"split": "seat"`: its back standing at the front, its seat
lying under the sitter) and `pew_s` (the same turned about, for a bench against the back wall: whoever sits
on it faces south, in front of all of it, so one picture: the school's back bench, the town hall's tower); `schooldesk`, `desk`, `teacherdesk` (the school's upstairs: its plain front toward the room, the
drawers on the teacher's side), `lectern`; `bar_counter`, `bar_back` and `barstool` (the tavern's bar: a bar stool's seat is high, so the spec's
`"seat_raise"` lifts whoever sits on it, Seat.raise); `tavern_table` (a candle burning on it) and `chair_e` / `chair_w` (turned half toward the
table to their east / west, their backs to the camera; plain, no grain; in two layers like a pew) in the
tavern. A seat's back (`"split": "seat"`) stands a little in front of the seat, so whoever sits there
shows behind it; and a chair's spec gives `"seat_raise"` and `"seat_fwd"` (the sitter lifted and moved
toward the table, their hips landing on the seat); `altar` and `candlestand` (the church).
Stools (the Cainos `stool` too) and pews need no such numbers: the generator fits whoever sits on them
(`b2d/scene.py`, SEAT_PX): their hips land that many pixels over the foot of the seat's picture, and on a
seat in one picture they sit a little in front of it in depth (lifted as much as keeps them in place on
screen), so that it never covers them; on a split pew they stay behind its back.
A piece with candles (`flame()`) has finish.py print where they burn, for the spec's "flames".
`table_round`, `stool` and `crate` are modelled too, but the
Cainos ones were kept: sturdier. A piece's picture stands at its spec "z" with its foot on the floor:
give "z" as the front of its footprint.
(.gdignore: the render project is its own Godot project, not part of the game's)
