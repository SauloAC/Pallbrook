extends Node
# The interiors' furniture, modelled here from plain boxes and cylinders and rendered as the Cainos art
# draws it: from the front and above, a pixel of height for every 1/32 m and the tops shortened to
# DEPTH (the town's camera looks down at 50 degrees; the game stands these pictures up, 1/cos 50 tall,
# as it does the Cainos ones), cel-shaded in the Cainos art's own colours (ramp.gdshader). Each piece is rendered twice: in colour,
# and with every part in a flat colour of its own, from which ../finish.py draws the dark lines
# between the parts and around the piece. A bed is rendered a third time, each part in the colour of
# the layer it goes to (its foot, its body, its head: see finish.py), so that the game can stand the
# three apart and someone lying in it shows between them.
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
	"book_red": [Color8(78, 30, 24), Color8(96, 38, 30), Color8(116, 48, 36), Color8(140, 64, 48)],
	"book_blue": [Color8(36, 48, 76), Color8(46, 60, 92), Color8(56, 74, 110), Color8(76, 96, 134)],
	"book_green": [Color8(40, 62, 40), Color8(50, 78, 50), Color8(62, 92, 60), Color8(84, 116, 78)],
	"book_ochre": [Color8(110, 74, 30), Color8(132, 90, 36), Color8(154, 106, 42), Color8(180, 132, 60)],
	"book_brown": [Color8(66, 40, 24), Color8(82, 52, 30), Color8(100, 66, 40), Color8(122, 86, 54)],
	"slate": [Color8(34, 42, 37), Color8(40, 50, 44), Color8(47, 59, 51), Color8(58, 72, 63)],
	"stone": [Color8(104, 102, 108), Color8(132, 130, 134), Color8(160, 158, 158), Color8(184, 182, 178)],
	"gold": [Color8(140, 100, 28), Color8(180, 136, 40), Color8(214, 172, 64), Color8(238, 206, 106)],
	"wax": [Color8(190, 178, 146), Color8(212, 202, 170), Color8(230, 222, 194), Color8(244, 238, 214)],
	"pewter": [Color8(84, 88, 96), Color8(108, 112, 120), Color8(136, 140, 146), Color8(170, 174, 178)],
	"apple": [Color8(110, 30, 26), Color8(140, 40, 32), Color8(170, 54, 40), Color8(200, 80, 60)],
	"chalk": [Color8(170, 172, 160), Color8(188, 190, 178), Color8(206, 206, 194), Color8(222, 222, 210)],
}

var id_mode := false
var layer_mode := false
var layer := Color.BLACK     # The layer of the parts that follow, in a layered piece
const FOOT := Color(1, 0, 0)
const BODY := Color(0, 1, 0)
const HEAD := Color(0, 0, 1)
const LAYERED := ["bed", "pew"]
var planks := Vector4.ZERO   # The boards' planks for the parts that follow (see ramp.gdshader)
var next_id := 0
var piece_root: Node3D
var flames: Array = []       # Where a piece's candles burn (see flame()): written beside its picture


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "out"
	DirAccess.make_dir_recursive_absolute(out)
	var names: Array = Array(args.slice(1)) if args.size() > 1 else PIECES
	for name in names:
		for pass_id in ([0, 1, 2] if name in LAYERED else [0, 1]):
			id_mode = pass_id == 1
			layer_mode = pass_id == 2
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
			vp.get_texture().get_image().save_png("%s/%s%s.png" % [out, name, ["", "_id", "_layers"][pass_id]])
			if pass_id == 0 and not flames.is_empty():
				var at := []
				for f in flames:
					var px := cam.unproject_position(piece_root.to_global(f))
					at.append([px.x, px.y])
				var file := FileAccess.open("%s/%s_flames.json" % [out, name], FileAccess.WRITE)
				file.store_string(JSON.stringify(at))
			flames = []
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
	elif layer_mode:
		cols = [layer, layer, layer, layer]
	for i in 4:
		m.set_shader_parameter("c%d" % i, cols[i])
	if not id_mode and not layer_mode:
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
const PIECES := ["bed", "cabinet", "table_round", "stool", "crate", "bookshelf_a", "bookshelf_b", "bookshelf_c", "blackboard",
	"pew", "schooldesk", "desk", "lectern", "altar", "candlestand", "teacherdesk", "bar_counter", "bar_back", "barstool"]


# A wooden bed, 1 m by 2: a red blanket over the linen, the pillow at the head (north, the wall)
func piece_bed() -> void:
	var w := 0.5      # half the width
	var back := -2.0
	var g := _group()
	for x in [-w, w - 0.08]:
		layer = HEAD
		box("wood", x, x + 0.08, 0.0, 0.9, back, back + 0.08, g)           # head posts
		layer = FOOT
		box("wood", x, x + 0.08, 0.0, 0.56, -0.08, 0.0, g)                 # foot posts
	layer = HEAD
	planks = Vector4(1, 0, 0, 0.14)
	box("wood", -w + 0.04, w - 0.04, 0.4, 0.84, back + 0.01, back + 0.06, g)   # headboard
	planks = Vector4.ZERO
	layer = FOOT
	box("wood", -w + 0.04, w - 0.04, 0.24, 0.5, -0.07, -0.02, g)               # footboard
	layer = BODY
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


# A tall bookcase, four shelves of books: three of them (a, b, c), filled differently, so that a row of
# them (the library's) doesn't repeat
func piece_bookshelf_a() -> void:
	_bookshelf(11)


func piece_bookshelf_b() -> void:
	_bookshelf(23)


func piece_bookshelf_c() -> void:
	_bookshelf(37)


const BOOKS := ["book_red", "book_blue", "book_green", "book_ochre", "book_brown", "book_red", "book_blue", "paper"]


func _bookshelf(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := 0.62
	var d := -0.3
	var g := _group()
	planks = Vector4(1, 0, 0, 0.2)
	box("shadow", -w, w, 0.0, 1.62, d, d + 0.03, g)                              # back
	planks = Vector4.ZERO
	for x in [-w, w - 0.07]:
		box("wood_mid", x, x + 0.07, 0.0, 1.62, d, 0.0, g)                     # sides
	box("wood_mid", -w - 0.03, w + 0.03, 1.62, 1.7, d - 0.02, 0.03, g)           # top
	box("wood_mid", -w, w, 0.0, 0.08, d, 0.0, g)                                 # plinth
	var shelves := [0.08, 0.46, 0.84, 1.22]
	for y in shelves.slice(1):
		box("wood_mid", -w + 0.07, w - 0.07, y, y + 0.04, d + 0.03, -0.01, g)    # shelves
	# the books: upright, now and then one leaning, a gap, or a few lying in a pile
	for y0 in shelves:
		var y: float = y0 + (0.04 if y0 > 0.1 else 0.0)
		var x := -w + 0.08
		while x < w - 0.1:
			var roll := rng.randf()
			if roll < 0.06:
				x += rng.randf_range(0.08, 0.16)                 # a gap
				continue
			if roll < 0.12 and x < w - 0.35:                     # a pile lying down
				var px := x
				var py := y
				for k in rng.randi_range(2, 4):
					var bw := rng.randf_range(0.2, 0.26)
					box(BOOKS[rng.randi() % BOOKS.size()], px + 0.01 * k, px + bw, py, py + 0.05, d + 0.05, -0.05, g)
					py += 0.05
				x += 0.28
				continue
			var bw := rng.randf_range(0.065, 0.11)
			var bh := rng.randf_range(0.22, 0.3)
			var col: String = BOOKS[rng.randi() % BOOKS.size()]
			if roll > 0.93 and x < w - 0.25:                     # leaning on its neighbour
				var lean := box(col, -bw / 2.0, bw / 2.0, -bh / 2.0, bh / 2.0, d + 0.06, -0.05, g, Vector3(0, 0, -18))
				lean.position = Vector3(x + bh * 0.3 + bw / 2.0, y + bh * 0.95 / 2.0, (d - 0.05) / 2.0 + 0.0)
				x += bh * 0.3 + bw + 0.02
				continue
			box(col, x, x + bw, y, y + bh, d + 0.04 + rng.randf_range(0.0, 0.04), -0.03, g)
			x += bw + 0.005


# The schoolroom's blackboard on its two legs, a few lines of chalk on it and the chalk on its ledge
func piece_blackboard() -> void:
	var w := 0.9
	var g := _group()
	for x in [-w - 0.1, w]:
		box("wood_mid", x, x + 0.1, 0.0, 1.66, -0.22, -0.12, g)                # legs, either side of the board
		box("wood_mid", x - 0.02, x + 0.12, 0.0, 0.07, -0.4, 0.0, g)           # their feet
	box("wood", -w, w, 0.58, 1.58, -0.2, -0.15, g)                               # frame
	var b := _group()
	box("slate", -w + 0.07, w - 0.07, 0.64, 1.52, -0.16, -0.14, b)               # the board
	var lines := [[-0.76, -0.1, 1.38], [0.05, 0.62, 1.38], [-0.76, 0.3, 1.25], [-0.76, -0.3, 1.12], [-0.15, 0.4, 1.12],
		[-0.76, 0.1, 0.98], [0.3, 0.74, 0.98], [-0.76, -0.4, 0.84]]
	for l in lines:
		box("chalk", l[0], l[1], l[2], l[2] + 0.03, -0.141, -0.136, b)         # the lesson, in chalk
	box("chalk", 0.5, 0.7, 0.8, 0.83, -0.141, -0.136, b)                        # a sum: a plus
	box("chalk", 0.585, 0.615, 0.72, 0.91, -0.141, -0.136, b)
	box("wood", -w, w, 0.54, 0.6, -0.2, -0.06, g)                                # the ledge
	box("chalk", -0.4, -0.3, 0.6, 0.625, -0.13, -0.1)                            # a stick of chalk
	box("paper", 0.3, 0.46, 0.6, 0.645, -0.14, -0.09)                            # the duster



# A candle's flame, where the game lights it (the spec's "flames": the picture's pixel at the wick)
func flame(x: float, y: float, z: float) -> void:
	if not id_mode and not layer_mode:
		flames.append(Vector3(x, y, z))


# A candle standing at (x, y, z): the wax, the wick
func candle(x: float, y: float, z: float, h: float, g := -1) -> void:
	cyl("wax", x, z, y, h, 0.055, -1.0, 6, g)
	flame(x, y + h, z + 0.05)


# A pew, its back toward the camera: whoever sits on it faces north (the altar, the teacher), and its
# low back hides them only to the waist. Two seats (the generator's). In two layers, like a bed: the back
# standing at the front, the seat lying under whoever sits on it.
func piece_pew() -> void:
	var w := 0.72
	var g := _group()
	layer = FOOT
	for x in [-w, w - 0.07]:
		box("wood_mid", x, x + 0.07, 0.0, 0.44, -0.42, 0.0, g)                  # the ends
	layer = BODY
	box("wood", -w + 0.07, w - 0.07, 0.3, 0.34, -0.42, -0.06, g)                 # seat
	layer = FOOT
	planks = Vector4(0, 1, 0, 0.23)
	box("wood", -w + 0.07, w - 0.07, 0.1, 0.4, -0.06, 0.0, g)                    # back, two boards
	planks = Vector4.ZERO
	box("wood_mid", -w - 0.02, w + 0.02, 0.4, 0.45, -0.08, 0.02, g)              # its top rail


# A pupil's desk: a sloping lid on four legs, a slate and a book on it
func piece_schooldesk() -> void:
	var w := 0.54
	var g := _group()
	for x in [-w, w - 0.06]:
		for z in [-0.44, -0.06]:
			box("wood_mid", x, x + 0.06, 0.0, 0.56, z, z + 0.06, g)            # legs
	box("wood_mid", -w, w, 0.44, 0.56, -0.44, 0.0, g)                            # the box under the lid
	var lid := box("wood", -w - 0.02, w + 0.02, -0.025, 0.025, -0.25, 0.25, g, Vector3(12, 0, 0))
	lid.position = Vector3(0.0, 0.62, -0.22)                                     # the lid, sloping toward the pupil
	var b := _group()
	var slate := box("slate", -0.38, -0.06, -0.01, 0.01, -0.13, 0.13, b, Vector3(12, 0, 0))
	slate.position = Vector3(-0.22, 0.655, -0.24)
	box("wood_end", -0.4, -0.04, -0.012, 0.012, -0.15, 0.15, b, Vector3(12, 0, 0)).position = Vector3(-0.22, 0.648, -0.24)
	var book := box("book_red", 0.08, 0.36, -0.02, 0.02, -0.11, 0.11, -1, Vector3(12, 0, 0))
	book.position = Vector3(0.24, 0.665, -0.2)


# The writing desk (the library's, the school's, the mayor's): drawers either side, papers, the ink,
# a candle
func piece_desk() -> void:
	var w := 1.0
	var d := -0.62
	var g := _group()
	planks = Vector4(1, 0, 0, 0.2)
	box("wood", -w - 0.03, w + 0.03, 0.74, 0.8, d - 0.03, 0.03, g)              # top
	planks = Vector4.ZERO
	for x0 in [-w, w - 0.55]:
		box("wood_mid", x0, x0 + 0.55, 0.0, 0.74, d, 0.0, g)                    # the drawers' cases
		for y in [0.08, 0.4]:
			box("wood", x0 + 0.05, x0 + 0.5, y, y + 0.28, -0.02, 0.005)          # drawers
			box("iron", x0 + 0.24, x0 + 0.31, y + 0.12, y + 0.16, 0.0, 0.02, g)
	box("shadow", -w + 0.55, w - 0.55, 0.0, 0.74, d + 0.02, d + 0.05, g)         # the knee-hole, in shade
	box("paper", -0.62, -0.2, 0.8, 0.81, -0.46, -0.14)                           # papers
	box("paper", -0.5, -0.1, 0.81, 0.82, -0.42, -0.18).rotation_degrees.y = 8.0
	box("book_brown", 0.05, 0.4, 0.8, 0.86, -0.5, -0.24)                         # a book, shut
	cyl("iron", 0.62, -0.3, 0.8, 0.07, 0.05, -1.0, 6)                            # the inkwell
	box("paper", 0.6, 0.62, 0.84, 1.0, -0.31, -0.29)                             # its quill
	var c := _group()
	cyl("iron", 0.85, -0.42, 0.8, 0.03, 0.07, -1.0, 6, c)                        # a candle in its dish
	candle(0.85, 0.83, -0.42, 0.18, c)


# The reading stand: a sloping top on one post, a book open on it
func piece_lectern() -> void:
	var g := _group()
	box("wood_mid", -0.25, 0.25, 0.0, 0.06, -0.38, -0.02, g)                     # foot
	box("wood_mid", -0.06, 0.06, 0.06, 0.95, -0.26, -0.14, g)                    # post
	var top := box("wood", -0.32, 0.32, -0.03, 0.03, -0.22, 0.22, g, Vector3(22, 0, 0))
	top.position = Vector3(0.0, 1.0, -0.2)
	for x in [-0.27, 0.01]:                                                      # the book, open: two pages
		var page := box("paper", x, x + 0.26, -0.012, 0.012, -0.16, 0.16, -1, Vector3(22, 0, 0))
		page.position = Vector3(x + 0.13, 1.04, -0.2)


# The church's altar: stone, a white cloth over it, the gold cross, a candle at either end
func piece_altar() -> void:
	var w := 1.15
	var d := -0.6
	var g := _group()
	planks = Vector4(1, 0, 0, 0.38)
	box("stone", -w, w, 0.0, 0.9, d, 0.0, g)                                     # the stone block
	planks = Vector4.ZERO
	box("stone", -w - 0.05, w + 0.05, 0.0, 0.08, d - 0.05, 0.05, g)              # its plinth
	var c := _group()
	box("linen", -w + 0.05, w - 0.05, 0.9, 0.94, d + 0.02, -0.02, c)             # the cloth on top
	box("linen", -0.6, 0.6, 0.3, 0.94, -0.02, 0.0, c)                            # hanging down the front
	box("gold", -0.6, 0.6, 0.3, 0.36, 0.0, 0.01, c)                              # its gold hem
	box("gold", -0.025, 0.025, 0.46, 0.8, 0.0, 0.01, c)                          # the cross on it
	box("gold", -0.1, 0.1, 0.66, 0.7, 0.0, 0.01, c)
	for x in [-0.95, 0.95]:
		var k := _group()
		cyl("gold", x, -0.3, 0.94, 0.05, 0.1, -1.0, 6, k)                        # candlesticks
		cyl("gold", x, -0.3, 0.99, 0.08, 0.04, -1.0, 6, k)
		cyl("gold", x, -0.3, 1.07, 0.03, 0.08, -1.0, 6, k)
		candle(x, 1.1, -0.3, 0.26, k)


# A tall iron candle stand
func piece_candlestand() -> void:
	var g := _group()
	cyl("iron", 0.0, -0.15, 0.0, 0.05, 0.16, -1.0, 6, g)                        # foot
	cyl("iron", 0.0, -0.15, 0.05, 0.95, 0.03, -1.0, 6, g)                        # stem
	cyl("iron", 0.0, -0.15, 1.0, 0.04, 0.1, 0.05, 6, g)                          # dish
	candle(0.0, 1.04, -0.15, 0.22, g)



# The teacher's desk: its plain front toward the room (the camera), the drawers on the far side, where
# she stands looking at the pupils. Books, the register open, the ink, an apple.
func piece_teacherdesk() -> void:
	var w := 0.98
	var d := -0.62
	var g := _group()
	planks = Vector4(1, 0, 0, 0.2)
	box("wood", -w - 0.03, w + 0.03, 0.74, 0.8, d - 0.03, 0.03, g)              # top
	planks = Vector4(1, 0, 0, 0.16)
	box("wood_mid", -w, w, 0.06, 0.74, -0.05, 0.0, g)                            # the front panel, boards upright
	planks = Vector4.ZERO
	for x in [-w, w - 0.08]:
		box("wood", x, x + 0.08, 0.0, 0.74, -0.06, 0.01, g)                     # its corner posts
		box("wood_mid", x, x + 0.08, 0.0, 0.74, d, d + 0.08, g)
	box("wood", -w, w, 0.0, 0.06, -0.06, 0.01, g)                               # the rail along its foot
	box("wood", -w, w, 0.66, 0.74, -0.06, 0.01, g)                              # and under the top
	box("wood_mid", -w, w, 0.06, 0.74, d, d + 0.03, g)                           # the drawers' side, hidden
	var b := _group()
	box("book_blue", -0.85, -0.45, 0.8, 0.86, -0.5, -0.22, b)                    # a pile of books
	box("book_red", -0.82, -0.47, 0.86, 0.92, -0.48, -0.24, b)
	box("book_green", -0.84, -0.5, 0.92, 0.97, -0.47, -0.25, b)
	for x in [-0.3, 0.0]:                                                        # the register, open
		box("paper", x, x + 0.29, 0.8, 0.82, -0.46, -0.16)
	cyl("iron", 0.45, -0.32, 0.8, 0.07, 0.05, -1.0, 6)                           # the ink
	box("paper", 0.43, 0.45, 0.84, 1.0, -0.33, -0.31)                            # its quill
	cyl("apple", 0.75, -0.3, 0.8, 0.09, 0.055, 0.045, 8)                         # an apple


# The tavern's bar: the counter, its boards upright toward the customers, a thick top with the day's
# bottles, mugs and a jug on it. Marta stands behind it (north).
func piece_bar_counter() -> void:
	var w := 1.72     # from the open end (west) to the stairs (east)
	var d := -0.72
	var g := _group()
	planks = Vector4(1, 0, 0, 0.14)
	box("wood_mid", -w + 0.04, w - 0.04, 0.06, 0.94, -0.07, -0.02, g)          # the front, boards upright
	planks = Vector4.ZERO
	box("wood_mid", -w, w, 0.0, 0.06, -0.08, 0.0, g)                             # its foot
	for x in [-w, -w / 2.0 - 0.05, -0.05, w / 2.0 - 0.05, w - 0.1]:
		box("wood", x, x + 0.1, 0.06, 0.94, -0.09, -0.01, g)                   # posts between the boards
	box("wood_mid", -w, w, 0.06, 0.94, d, -0.07, g)                              # the body behind
	planks = Vector4(0, 0, 1, 0.16)
	box("wood", -w - 0.05, w + 0.05, 0.94, 1.02, d - 0.03, 0.06, g)              # the thick top, overhanging
	planks = Vector4.ZERO
	var t := [["bottle", "glass_green", -1.45, 0.26], ["bottle", "glass_amber", -1.3, 0.22], ["bottle", "glass_purple", -1.16, 0.24]]
	for b in t:
		bottle(b[0], b[1], b[2], 1.02, -0.3, b[3])
	cyl("pewter", -0.55, -0.32, 1.02, 0.12, 0.06, -1.0, 8)                        # mugs
	cyl("pewter", -0.3, -0.4, 1.02, 0.12, 0.06, -1.0, 8)
	cyl("pewter", 0.45, -0.34, 1.02, 0.12, 0.06, -1.0, 8)
	cyl("clay", 0.9, -0.34, 1.02, 0.2, 0.06, 0.09, 8)                            # the jug
	cyl("clay", 0.9, -0.34, 1.22, 0.06, 0.045, 0.06, 8)
	bottle("bottle", "glass_amber", 1.25, 1.02, -0.36, 0.22)


# Behind the bar, against the wall: on the left the bottles on two shelves over a cupboard, on the right
# two barrels on their sides in a cradle, their taps toward the room
func piece_bar_back() -> void:
	var d := -0.5
	var g := _group()
	# the cupboard along the whole back
	var x0 := -1.7
	var x1 := 1.7
	box("wood_mid", x0, x1, 0.0, 0.7, d, -0.04, g)                               # its body
	planks = Vector4(1, 0, 0, 0.3)
	box("wood_mid", x0 + 0.04, x1 - 0.04, 0.06, 0.64, -0.05, 0.0)                # its doors
	planks = Vector4.ZERO
	for x in range(5):
		var kx := x0 + 0.37 + x * 0.74
		box("iron", kx - 0.02, kx + 0.02, 0.36, 0.42, 0.0, 0.02, g)             # knobs
	box("wood", x0 - 0.03, x1 + 0.03, 0.7, 0.76, d - 0.02, 0.03, g)              # its top
	# the shelves, left: a back board and two shelves full of bottles
	var sx1 := 0.15
	planks = Vector4(1, 0, 0, 0.2)
	box("shadow", x0, sx1, 0.76, 1.9, d, d + 0.03, g)
	planks = Vector4.ZERO
	for x in [x0, sx1 - 0.06]:
		box("wood_mid", x, x + 0.06, 0.76, 1.9, d, d + 0.3, g)                 # the shelves' sides
	for y in [1.2, 1.56, 1.86]:
		box("wood_mid", x0, sx1, y, y + 0.04, d, d + 0.3, g)                     # shelves
	var glass := ["glass_green", "glass_purple", "glass_amber", "glass_blue", "glass_green", "glass_amber",
		"glass_purple", "glass_blue", "glass_amber", "glass_green", "glass_purple", "glass_blue"]
	for row in 2:
		var y: float = [0.76, 1.24][row]
		var i := 0
		var x := x0 + 0.18
		while x < sx1 - 0.15:
			var kind := "flask" if (i + row) % 4 == 3 else "bottle"
			bottle(kind, glass[(i + row * 5) % glass.size()], x, y, d + 0.15, 0.24 + 0.04 * ((i * 7 + row) % 3), g)
			x += 0.16
			i += 1
	# the barrels, right, on their sides on a cradle, the taps toward the room. (Squat: the picture stands
	# heights up 1/cos 50, which would draw their round ends tall)
	for bx in [0.52, 1.28]:
		var k := _group()
		box("wood_mid", bx - 0.32, bx + 0.32, 0.76, 0.84, d + 0.02, -0.02, k)    # the cradle
		var r := 0.35
		var ry := r * COS50
		var cy := 0.84 + ry
		planks = Vector4(1, 0, 0, 0.11)
		var barrel := cyl("wood", 0.0, 0.0, -0.22, 0.44, r, -1.0, 14, k)
		planks = Vector4.ZERO
		barrel.rotation_degrees = Vector3(90, 0, 0)
		barrel.scale = Vector3(1, 1, COS50)
		barrel.position = Vector3(bx, cy, d + 0.24)
		for hz in [0.03, 0.4]:                                                   # iron hoops
			var hoop := cyl("iron", 0.0, 0.0, -0.02, 0.04, r + 0.012, -1.0, 14, k)
			hoop.rotation_degrees = Vector3(90, 0, 0)
			hoop.scale = Vector3(1, 1, COS50)
			hoop.position = Vector3(bx, cy, d + 0.02 + hz)
		planks = Vector4(0, 1, 0, 0.09)
		var end := cyl("wood_end", 0.0, 0.0, -0.01, 0.02, r - 0.03, -1.0, 14)       # its round end, a line about it
		planks = Vector4.ZERO
		end.rotation_degrees = Vector3(90, 0, 0)
		end.scale = Vector3(1, 1, COS50)
		end.position = Vector3(bx, cy, d + 0.465)
		box("iron", bx - 0.03, bx + 0.03, cy - 0.1, cy - 0.06, d + 0.46, d + 0.56, k)  # the tap
		box("iron", bx - 0.02, bx + 0.02, cy - 0.16, cy - 0.08, d + 0.53, d + 0.56, k)



# A tall bar stool: a round seat on four legs, a ring between them for the feet. Its seat is higher than
# a stool's: whoever sits on it is raised (the spec's "seat_raise", Seat.raise)
func piece_barstool() -> void:
	var g := _group()
	cyl("wood", 0.0, -0.24, 0.74, 0.07, 0.24, -1.0, 8, g)                        # seat
	for a in [90.0, 210.0, 330.0]:                                               # three legs
		var x := cos(deg_to_rad(a)) * 0.18
		var z := -0.24 + sin(deg_to_rad(a)) * 0.18
		cyl("wood_mid", x, z, 0.0, 0.74, 0.035, 0.04, 4, g)
	cyl("wood_mid", 0.0, -0.24, 0.26, 0.03, 0.18, -1.0, 8, g)                    # the ring for the feet
