# The cemetery's painted pieces

`assets/environment2d/props/cem_*.png`, laid out in town by `scripts/world/Cemetery2D.gd`.

- The graves, the statue, the pillars and the bench are crops of the Cainos
  "Pixel Art Top Down - Basic" pack (`Texture/TX Props.png`).
- The pieces that pack lacks come from KayKit Halloween Bits (Kay Lousberg, CC0):
  the crypt, the iron fence and its arch, the dead trees, the lanterns, the road's gate and the
  fresh graves' wooden cross.
  1. `render/` is a tiny Godot project. Copy the pack's `Assets/gltf/*` into `render/m/`, run it once
     with `--import`, then render with the town's camera (50 degrees down, orthographic, one pixel per
     0.04375 m, toon-shaded, transparent background):
     `MODELS="crypt=crypt:0.47:0.47:0.36:0,fence_n=fence:0.875:0.75:0.75:0,..." OUT=<dir> godot --path render render.tscn`
     (`out=model:scale x:scale y:scale z:yaw`; the scales used are in `make_props.py`'s notes below).
  2. `cainosify.py` maps each material of a render (stone, slate roof, iron, wood, planks) onto the
     Cainos pack's own colour ramps by its shade, and draws the pack's dark outline.
  3. `make_props.py` crops the Cainos pieces, cainosifies the renders and writes `cem_*.png`
     (its paths point at a working folder: change SP).

Renders used: crypt=crypt:0.47:0.47:0.36:0, fence_n=fence:0.875:0.75:0.75:0, fence_s=fence:0.733:0.75:0.75:0,
fence_side=fence:0.75:0.75:0.75:90, arch=arch:0.5:0.5:0.5:0, tree_dead_l=tree_dead_large:1:1:1:0,
tree_dead_m=tree_dead_medium:1:1:1:30, post_lantern=post_lantern:0.6:0.6:0.6:0,
gate_side=fence_gate:0.95:0.75:0.75:90, lantern=lantern_hanging:0.6:0.6:0.6:0, marker=gravemarker_A:1:1:1:0.

The cemetery's ground (darker grass inside the fence, the paved walks, the old graves' plots) is painted
by `../env2d/bake.py` (CEM, CEM_WALKS, CEM_OLD: the same places as Cemetery2D.gd).
(.gdignore: the render project is its own Godot project, not part of the game's)
