# The cel-shaded furniture

`assets/buildings2d/props/prop_cel_*.png`, placed by the building specs like any other prop
(`"prop": "cel_bed"`; the generator treats a `cel_` piece as the kind after the prefix, so a
`cel_stool` is still a seat and a `cel_table...` still a table).

The pieces are modelled in `render/render.gd` from plain boxes and cylinders (no outside assets) and
rendered the way the Cainos art is drawn: from the front and above, a pixel of height for every 1/32 m,
tops shortened to 0.6 of their depth. `render/ramp.gdshader` paints every part in four shades of one
material taken from the Cainos props (wood, dark wood, linen, the red blanket, glass...), by how the
face meets the light, with plank seams where a part asks for them. Each piece is rendered twice, in
colour and with each part in a flat colour of its own; `finish.py` uses the second to draw the dark
lines between parts and around the piece, then crops it.

    cd render
    godot --path . render.tscn -- <out dir> [piece ...]
    python3 ../finish.py <out dir> <out dir> [piece ...]     # writes prop_<piece>.png
    # then copy prop_<piece>.png to assets/buildings2d/props/prop_cel_<piece>.png

In use: `bed` and `cabinet` (the clinic); `bookshelf_a`, `_b`, `_c` (the same bookcase, filled three
ways: the library, the school, the town hall); `blackboard` (the school). `table_round`, `stool` and `crate` are modelled too, but the
Cainos ones were kept: sturdier. A piece's picture stands at its spec "z" with its foot on the floor:
give "z" as the front of its footprint.
(.gdignore: the render project is its own Godot project, not part of the game's)
