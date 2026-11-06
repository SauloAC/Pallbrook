extends Node
# The interiors' furniture, modelled here from plain boxes and cylinders and rendered as the Cainos art
# draws it: from the front and above, a pixel of height for every 1/32 m and the tops shortened to
# DEPTH (the town's camera looks down at 50 degrees; the game stands these pictures up, 1/cos 50 tall,
# as it does the Cainos ones), cel-shaded in the Cainos art's own colours (ramp.gdshader). Each piece is rendered twice: in colour,
# and with every part in a flat colour of its own, from which ../finish.py draws the dark lines
# between the parts and around the piece.
#   godot --path render render.tscn -- <out dir> [piece ...]      (no pieces: all of them)

const PX := 1.0 / 32.0
const SIN50 := 0.76604444
const COS50 := 0.64278761
const SHADER := preload("res://ramp.gdshader")
const DEPTH := 0.6     # How long a top looks for its depth (the Cainos tables and crates: about this)

# Four shades each, dark to light, taken from the props already in the interiors
const RAMPS := {
	"wood": [Color8(75, 45, 24), Color8(92, 58, 34), Color8(116, 86, 54), Color8(148, 123, 86)],
	"wood_dark": [Color8(58, 34, 18), Color8(73, 45, 24), Color8(92, 62, 34), Color8(112, 85, 54)],
	"wood_mid": [Color8(58, 34, 18), Color8(73, 45, 24), Color8(92, 62, 34), Color8(124, 96, 62)],
	"shadow": [Color8(30, 18, 10), Color8(38, 23, 12), Color8(46, 28, 14), Color8(56, 34, 18)],
	"wood_end": [Color8(78, 46, 24), Color8(96, 64, 38), Color8(118, 88, 56), Color8(134, 106, 72)],
	"linen": [Color8(170, 160, 140), Color8(192, 184, 166), Color8(214, 206, 188), Color8(232, 226, 212)],
	"red": [Color8(84, 38, 32), Color8(104, 50, 41), Color8(124, 62, 51), Color8(146, 78, 63)],
	"iron": [Color8(40, 36, 42), Color8(56, 52, 58), Color8(74, 70, 76), Color8(96, 92, 98)],
	"glass_green": [Color8(40, 66, 38), Color8(58, 96, 54), Color8(80, 128, 70), Color8(126, 172, 104)],
	"glass_amber": [Color8(100, 64, 26), Color8(140, 94, 36), Color8(180, 126, 52), Color8(214, 166, 80)],
	"glass_blue": [Color8(48, 62, 92), Color8(64, 84, 118), Color8(86, 108, 142), Color8(128, 150, 178)],
	"glass_purple": [Color8(84, 40, 70), Color8(108, 54, 90), Color8(132, 70, 110), Color8(164, 100, 140)],
	"clay": [Color8(110, 64, 40), Color8(134, 82, 52), Color8(156, 100, 66), Color8(176, 122, 84)],
	"paper": [Color8(186, 172, 140), Color8(206, 194, 162), Color8(226, 214, 182), Color8(240, 230, 204)],
}

var id_mode := false
var planks := Vector4.ZERO   # The boards' planks for the parts that follow (see ramp.gdshader)
var next_id := 0
var piece_root: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "out"
	DirAccess.make_dir_recursive_absolute(out)
	var names: Array = Array(args.slice(1)) if args.size() > 1 else PIECES
	for name in names:
		for pass_id in [false, true]:
			id_mode = pass_id
			next_id = 0
			var vp := SubViewport.new()
			vp.transparent_bg = true
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			piece_root = Node3D.new()
			vp.add_child(piece_root)
			call("piece_" + name)
			piece_root.scale = Vector3(1.0, 1.0 / COS50, DEPTH / SIN50)
			var box := _bounds(piece_root)
			var rmin := INF
			var rmax := -INF
			for i in 8:
				var c := box.get_endpoint(i)
				var r := c.y * COS50 - c.z * SIN50   # how high on the screen
				rmin = minf(rmin, r)
				rmax = maxf(rmax, r)
			var wpx := int(ceil(box.size.x / PX)) + 4
			var hpx := int(ceil((rmax - rmin) / PX)) + 4
			vp.size = Vector2i(wpx, hpx)
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = hpx * PX
			cam.near = 0.05
			cam.far = 100.0
			var centre := box.get_center()
			var rc := (rmin + rmax) / 2.0
			var target := Vector3(centre.x, centre.y, -(rc - centre.y * COS50) / SIN50)
			cam.transform = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-50.0)), target + Vector3(0, SIN50, COS50) * 30.0)
			vp.add_child(cam)
			cam.current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/%s%s.png" % [out, name, "_id" if id_mode else ""])
			vp.queue_free()
		print("R ", name)
	get_tree().quit()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# ---------- Building blocks ----------
# A part: its own flat colour in the id pass (one per call, or shared with "group")
func _material(ramp: String, group := -1) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var cols: Array = RAMPS[ramp]
	if id_mode:
		var id := group if group >= 0 else next_id
		if group < 0:
			next_id += 1
		var c := Color.from_hsv(fmod(id * 0.618034, 1.0), 0.6 + 0.4 * float(id % 2), 0.5 + 0.5 * float((id / 2) % 2))
		cols = [c, c, c, c]
	for i in 4:
		m.set_shader_parameter("c%d" % i, cols[i])
	if not id_mode:
		m.set_shader_parameter("planks", planks)
	return m


# A box from its corners: x0..x1 across, y0..y1 up, z0..z1 (z1 toward the camera)
func box(ramp: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, group := -1, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	mi.mesh = mesh
	mi.material_override = _material(ramp, group)
	mi.position = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	mi.rotation_degrees = rot
	piece_root.add_child(mi)
	return mi


# An upright cylinder standing at (x, y0, z)
func cyl(ramp: String, x: float, z: float, y0: float, h: float, r_top: float, r_bottom := -1.0, sides := 8, group := -1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_top if r_bottom < 0.0 else r_bottom
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = _material(ramp, group)
	mi.position = Vector3(x, y0 + h / 2.0, z)
	mi.rotation_degrees.y = 180.0 / sides   # a flat face toward the camera
	piece_root.add_child(mi)
	return mi


func _group() -> int:
	next_id += 1
	return next_id - 1


# A small bottle or jar on a shelf, its foot at (x, y, z)
func bottle(kind: String, glass: String, x: float, y: float, z: float, h: float, g := -1) -> void:
	if g < 0:
		g = _group()
	match kind:
		"bottle":
			cyl(glass, x, z, y, h * 0.62, 0.06, -1.0, 6, g)
			cyl(glass, x, z, y + h * 0.62, h * 0.38, 0.022, 0.04, 6, g)
			cyl("wood_end", x, z, y + h * 0.95, h * 0.1, 0.024, -1.0, 6, g)   # the cork
		"flask":
			cyl(glass, x, z, y, h * 0.5, 0.04, 0.075, 6, g)
			cyl(glass, x, z, y + h * 0.5, h * 0.5, 0.022, -1.0, 6, g)
		"jar":
			cyl("clay", x, z, y, h * 0.85, 0.075, 0.068, 8, g)
			cyl("linen", x, z, y + h * 0.85, h * 0.15, 0.08, -1.0, 8, g)    # the cloth tied over it


# ---------- The pieces ----------
# Sizes as the interiors' furniture has them (a little larger than life, like the Cainos pieces)
const PIECES := ["bed", "cabinet", "table_round", "stool", "crate"]


# A wooden bed, 1 m by 2: a red blanket over the linen, the pillow at the head (north, the wall)
func piece_bed() -> void:
	var w := 0.5      # half the width
	var back := -2.0
	var g := _group()
	for x in [-w, w - 0.08]:
		box("wood", x, x + 0.08, 0.0, 0.9, back, back + 0.08, g)           # head posts
		box("wood", x, x + 0.08, 0.0, 0.56, -0.08, 0.0, g)                 # foot posts
	planks = Vector4(1, 0, 0, 0.14)
	box("wood", -w + 0.04, w - 0.04, 0.4, 0.84, back + 0.01, back + 0.06, g)   # headboard
	planks = Vector4.ZERO
	box("wood", -w + 0.04, w - 0.04, 0.24, 0.5, -0.07, -0.02, g)               # footboard
	for x in [-w, w - 0.06]:
		box("wood", x, x + 0.06, 0.12, 0.3, back + 0.08, -0.08, g)         # side rails
	box("linen", -w + 0.06, w - 0.06, 0.26, 0.4, back + 0.08, -0.08)           # mattress
	box("linen", -w + 0.12, w - 0.12, 0.4, 0.52, back + 0.14, back + 0.52)     # pillow
	var b := _group()
	planks = Vector4(0, 0, 1, 0.16)                                             # quilted
	box("red", -w + 0.05, w - 0.05, 0.4, 0.47, -1.3, -0.07, b)                 # blanket
	box("red", -w + 0.03, -w + 0.05, 0.2, 0.47, -1.3, -0.07, b)                # hanging over the sides
	box("red", w - 0.05, w - 0.03, 0.2, 0.47, -1.3, -0.07, b)
	planks = Vector4.ZERO
	box("linen", -w + 0.05, w - 0.05, 0.42, 0.49, -1.44, -1.28)                # the sheet turned down


# The medicine cabinet: open shelves of bottles and jars over two closed doors
func piece_cabinet() -> void:
	var w := 0.5
	var d := -0.32
	var g := _group()
	planks = Vector4(1, 0, 0, 0.2)
	box("shadow", -w, w, 0.0, 1.5, d, d + 0.03, g)                               # back, in the shelves' shade
	planks = Vector4.ZERO
	for x in [-w, w - 0.06]:
		box("wood_mid", x, x + 0.06, 0.0, 1.5, d, 0.0, g)                      # sides
	box("wood_mid", -w - 0.02, w + 0.02, 1.5, 1.57, d - 0.01, 0.02, g)           # top
	box("wood_mid", -w, w, 0.0, 0.06, d, 0.0, g)                                 # plinth
	for y in [0.48, 0.82, 1.16]:
		box("wood_mid", -w + 0.06, w - 0.06, y, y + 0.04, d + 0.03, -0.01, g)    # shelves
	planks = Vector4(1, 0, 0, 0.11)
	box("wood_mid", -w + 0.06, -0.01, 0.07, 0.47, -0.05, -0.01)                  # doors
	box("wood_mid", 0.01, w - 0.06, 0.07, 0.47, -0.05, -0.01)
	planks = Vector4.ZERO
	box("iron", -0.08, -0.04, 0.25, 0.3, -0.01, 0.01)                            # knobs
	box("iron", 0.04, 0.08, 0.25, 0.3, -0.01, 0.01)
	# the bottles drawn without lines of their own: they read against the dark back
	var rows := [
		[["bottle", "glass_green", -0.32, 0.26], ["bottle", "glass_amber", -0.15, 0.22], ["jar", "", 0.04, 0.18],
		 ["bottle", "glass_purple", 0.2, 0.25], ["flask", "glass_blue", 0.35, 0.2]],
		[["jar", "", -0.31, 0.17], ["bottle", "glass_blue", -0.14, 0.26], ["bottle", "glass_amber", 0.02, 0.22],
		 ["flask", "glass_green", 0.18, 0.21], ["bottle", "glass_green", 0.34, 0.24]],
		[["bottle", "glass_amber", -0.33, 0.24], ["flask", "glass_purple", -0.16, 0.2], ["bottle", "glass_green", 0.0, 0.26],
		 ["jar", "", 0.17, 0.17], ["bottle", "glass_blue", 0.33, 0.23]],
	]
	for i in 3:
		var y: float = [0.52, 0.86, 1.2][i]
		for b in rows[i]:
			bottle(b[0], b[1], b[2], y, -0.14, b[3], g)


# A round table on one leg, like the Cainos one, eight-sided
func piece_table_round() -> void:
	var g := _group()
	planks = Vector4(0, 0, 1, 0.14)
	cyl("wood", 0.0, -0.48, 0.68, 0.07, 0.48, -1.0, 8, g)        # top, its boards across
	planks = Vector4.ZERO
	cyl("wood_mid", 0.0, -0.48, 0.0, 0.68, 0.09, -1.0, 6, g)     # leg
	box("wood_mid", -0.32, 0.32, 0.0, 0.06, -0.53, -0.43, g)     # feet, crossed
	box("wood_mid", -0.05, 0.05, 0.0, 0.06, -0.8, -0.16, g)


# A three-legged stool
func piece_stool() -> void:
	var g := _group()
	cyl("wood", 0.0, -0.32, 0.42, 0.07, 0.32, -1.0, 8, g)
	for a in [90.0, 210.0, 330.0]:
		var x := cos(deg_to_rad(a)) * 0.2
		var z := -0.32 + sin(deg_to_rad(a)) * 0.2
		cyl("wood_mid", x, z, 0.0, 0.42, 0.035, 0.045, 4, g)


# Two crates, one on the other, plank sides and a cross brace on the front
func piece_crate() -> void:
	_crate(-0.5, 0.5, 0.0, 0.62, -0.7, 0.0)
	_crate(-0.42, 0.42, 0.62, 1.12, -0.62, -0.08)


func _crate(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var g := _group()
	planks = Vector4(0, 1, 0, 0.22)
	box("wood_mid", x0 + 0.03, x1 - 0.03, y0 + 0.03, y1 - 0.03, z0 + 0.03, z1 - 0.03, g)    # the planks inside
	planks = Vector4.ZERO
	var t := 0.07
	for x in [x0, x1 - t]:
		for z in [z0, z1 - t]:
			box("wood", x, x + t, y0, y1, z, z + t, g)                       # corner posts
	for y in [y0, y1 - t]:
		box("wood", x0, x1, y, y + t, z1 - t, z1, g)                         # front frame
		box("wood", x0, x1, y, y + t, z0, z0 + t, g)
		for x in [x0, x1 - t]:
			box("wood", x, x + t, y, y + t, z0, z1, g)
	var diag := rad_to_deg(atan2(y1 - y0 - 2 * t, x1 - x0 - 2 * t))
	var ln := Vector2(x1 - x0 - 2 * t, y1 - y0 - 2 * t).length()
	var brace := box("wood", -ln / 2.0, ln / 2.0, -0.05, 0.05, z1 - 0.04, z1 - 0.01, g, Vector3(0, 0, diag))
	brace.position = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, z1 - 0.025)
