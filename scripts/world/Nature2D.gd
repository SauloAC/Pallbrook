class_name Nature2D
extends Node3D

# Test (3 Nov): the town's greenery in the painted style of the buildings, from the same Cainos pack
# ("Pixel Art Top Down - Village"). The 3D trees, bushes and tall grass of town.glb are hidden and a
# painted one stands in each place (upright, lit like the facades, a small painted shadow at its foot),
# and the ground is one painted picture: the pack's grass, its dirt for the paths and cobbles for the
# streets, with soft hand-drawn edges (see ground_baked.gdshader). Collisions and hiding spots are left as they were.
# F8 switches between this and the 3D greenery, to compare.

const PX := 0.04375                 # The buildings' pixel, in metres
const UPRIGHT := 1.5557238          # 1 / cos(50 deg), as for the facades
const TOWARD_CAMERA := Vector3(0.0, 0.76604444, 0.64278761)
const PULL := 0.5                   # Metres toward the camera: the ground doesn't cut the foot
const PLANTS := preload("res://assets/environment2d/plants_cainos.png")
const GRASS := preload("res://assets/environment2d/grass_cainos.png")
const SHADOW := preload("res://assets/environment2d/shadow_blob.png")
const SPRITE_SHADER := preload("res://assets/buildings2d/sprite_surface.gdshader")
const GROUND_SHADER := preload("res://assets/environment2d/ground_baked.gdshader")
const BAKED := preload("res://assets/environment2d/ground_baked.png")
# The ground and the road meshes all get the painted ground (grass, dirt paths, cobbled streets)
var GROUND := RegEx.create_from_string("^(Ground|GroundWestSkirt|Streets|StreetsNew|PathDirt|CemeteryRoad)$")
const PAINTED_GROUND := ["M_GroundGrass", "M_GroundDirt", "Street_Cobble", "Path_Dirt"]

# Pieces of plants_cainos.png: [x, y, width, height, trunk x] in pixels, smallest first
const ART := {
	"tree_green": [[19, 76, 55, 106, 27.5], [104, 59, 79, 123, 39.0], [196, 42, 87, 140, 44.5], [319, 21, 93, 161, 48.5], [445, 5, 96, 179, 52.0]],
	"tree_autumn": [[19, 271, 55, 106, 27.5], [104, 254, 79, 123, 39.0], [196, 237, 87, 140, 44.5], [319, 216, 93, 161, 48.5], [444, 200, 96, 179, 52.0]],
	"oak": [[687, 16, 252, 248, 146.9], [702, 278, 213, 208, 125.1]],
	"bush_autumn": [[34, 899, 27, 27, 12.8], [93, 896, 38, 30, 19.8], [153, 887, 42, 39, 20.4], [217, 890, 45, 38, 22.9], [293, 886, 57, 41, 28.6], [379, 886, 73, 45, 33.0], [472, 872, 79, 57, 51.3]],
	"bush_green": [[34, 963, 27, 27, 12.8], [93, 960, 38, 30, 19.8], [153, 951, 42, 39, 20.4], [217, 954, 45, 38, 22.9], [293, 950, 57, 41, 28.6], [379, 950, 73, 45, 33.0], [472, 936, 79, 57, 51.3]],
}
var TREE := RegEx.create_from_string("^(K_)?(Tree|TreeFarW)|^KOuter")
# Painted over by other means (the bridge, the fields and gardens, see below): only hidden
var REPLACED := RegEx.create_from_string("^(StoneBridge|BridgePost|BridgeRail|FarmField_|GSoil_|GFence_)|^(Carrot|Plant)(_\\d+)*$")
var BUSH := RegEx.create_from_string("^(KBush|Bush_Common)")
var TALL_GRASS := RegEx.create_from_string("^KGrass")
var NOISE := RegEx.create_from_string("^GrassTufts")

var hidden: Array[Node3D] = []
var ground: Array = []              # [MeshInstance3D, surface, original override]
var painted: Node3D
var on := true


func _ready() -> void:
	await get_tree().process_frame  # town.glb may finish loading after us
	await get_tree().process_frame
	var town := get_parent().find_child("town", true, false) as Node3D   # CameraFollow adds us to the town's scene
	if town == null and get_tree().current_scene:
		town = get_tree().current_scene.find_child("town", true, false) as Node3D
	if town == null:
		return
	painted = Node3D.new()
	add_child(painted)
	var spots := []                 # [position, kind, height, autumn]
	for node in town.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		var kind := ""
		if TREE.search(n):
			kind = "tree"
		elif BUSH.search(n):
			kind = "bush"
		elif TALL_GRASS.search(n):
			kind = "grass"
		elif NOISE.search(n) or REPLACED.search(n):
			hidden.append(mi)
			continue
		else:
			_retile(mi)
			continue
		hidden.append(mi)
		var spot := Vector2(mi.global_position.x, mi.global_position.z)
		if (kind == "tree" and TREE_CLEAR.any(func(r: Rect2): return r.has_point(spot))) or STALL_FOOT.has_point(spot):
			cleared.append(spot)  # Room for Ada's stall, and the trees that hid a garden and the willow
			continue
		var box := mi.get_aabb()
		var height := box.size.y * mi.global_basis.get_scale().y
		spots.append([mi.global_position, kind, height, not _is_pine(mi)])
	for s in _merge(spots):
		_plant(s[0], s[1], s[2], s[3])
	_props(town)
	_fields()
	_gardens(town)
	await get_tree().physics_frame  # Gideon's stall is built a physics frame in
	await get_tree().process_frame
	_street_lamps()
	_gideon()
	_bridge()
	_colliders(town)
	_apply()
	_garlic()


# ---------- Props ----------
# Outdoor props of town.glb, by name and place, and the painted piece that stands in for each.
# Rules: [name pattern, painted piece ("" = only hidden), zone]. Only props inside a zone are
# touched, so the furniture inside the 3D buildings stays as it is.
const PROPS_DIR := "res://assets/environment2d/props/"
const ZONES := {
	"plaza": Rect2(-3.0, -1.5, 11.0, 9.5), "market": Rect2(-0.5, 8.0, 7.5, 4.0),
	"tavern": Rect2(-11.0, 14.0, 9.0, 10.0), "clinic_yard": Rect2(12.5, 5.0, 3.5, 4.5),
	"forge_yard": Rect2(5.0, -25.0, 11.0, 6.0), "river": Rect2(-40.0, -80.0, 50.0, 120.0),
}
const WELL_AT := Vector3(2.5, 0.0, 3.35)   # The front of the well's stone base
const PROP_RULES := [
	["^Well", "", "plaza"],   # The well's many pieces: one painted well instead (WELL_AT)
	["^Stall_Cart_Empty", "stall_ada", "market"],
	["^(FarmCrate|Bag|Barrel_Apples)", "", "market"],
	["^Bench", "bench", "plaza"], ["^Bench", "bench", "tavern"], ["^Bench", "bench", "clinic_yard"],
	["^Table_Large", "table_v_cloth", "tavern"], ["^Table_Large", "table", "clinic_yard"], ["^Table_Large", "table", "forge_yard"],
	["^Barrel_Holder", "barrels_stack", "tavern"], ["^Barrel_Apples", "crate_apples", "tavern"],
	["^Barrel", "barrel", "tavern"], ["^Barrel", "barrel", "forge_yard"],
	["^FarmCrate_Carrot", "crate_carrots", "tavern"], ["^(Crate_Wooden|Crates)", "crate_empty", "tavern"],
	["^Chest_Wood", "crate_empty", "forge_yard"], ["^Bucket", "", "forge_yard"], ["^Trough", "trough", "forge_yard"],
	["^Flower_3_Group", "pot_flowers", "plaza"], ["^Flower_4_Group", "pot_flowers2", "plaza"], ["^Vase_2", "", "plaza"],
	["^Floor_Brick", "", "plaza"], ["^Floor_Brick", "", "tavern"],   # Painted into the ground (stone slabs)
	["^(KRock|Rock_Medium)", "rock", "river"],
]


func _props(town: Node3D) -> void:
	var rules := []
	for r in PROP_RULES:
		rules.append([RegEx.create_from_string(r[0]), r[1], ZONES[r[2]]])
	var done := {}
	for node in town.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		var at := box.get_center()
		for r in rules:
			if not (r[0] as RegEx).search(String(mi.name)) or not (r[2] as Rect2).has_point(Vector2(at.x, at.z)):
				continue
			if done.has(mi):
				break
			done[mi] = true
			hidden.append(mi)
			var piece: String = r[1]
			if piece == "bench" and maxf(box.size.x, box.size.z) < 1.3:
				piece = ""  # The little bench by the well: the painted ones are all long
			elif piece == "bench" or piece == "table" or piece == "trough":
				piece += "_h" if box.size.x >= box.size.z else "_v"
			if piece == "rock":
				_rock(mi, box)
				piece = ""
			var foot := Vector3(at.x, 0.0, box.end.z)
			if piece == "stall_ada":
				foot += STALL_SHIFT
			if piece != "":
				# The art's foot line is the prop's front edge (its south side, toward the camera)
				_stand(load(PROPS_DIR + piece + ".png"), foot)
			break
	_stand(load(PROPS_DIR + "well.png"), WELL_AT)


# The rocks along the river: fewer and smaller than the 3D ones, sitting on the water's edge
func _rock(mi: MeshInstance3D, box: AABB) -> void:
	var h := hash(String(mi.name))
	if h % 5 >= 2:
		return  # Two in five stay: a row of boulders hid the banks
	var at := box.get_center()
	var small := ["rock_03", "rock_04", "rock_13", "rock_14", "rock_15", "rock_05"]
	var medium := ["rock_06", "rock_07", "rock_16"]
	var piece: String = medium[h % medium.size()] if (h / 7) % 3 == 0 else small[h % small.size()]
	# On the bank's lip: half on the grass, half over the water
	var x := at.x
	if absf(at.x - RIVER.x) < 1.2:
		x = RIVER.x + 0.1 + float(h % 5) * 0.06
	elif absf(at.x - RIVER.y) < 1.2:
		x = RIVER.y - 0.1 - float(h % 5) * 0.06
	_wet_rock(_stand(load(PROPS_DIR + piece + ".png"), Vector3(x, 0.0, box.end.z)), Vector3(x, 0.0, box.end.z))
	if h % 3 == 0:  # Now and then a pebble beside it
		var side := 0.45 if x < (RIVER.x + RIVER.y) / 2.0 else -0.45
		var at2 := Vector3(x + side, 0.0, box.end.z + 0.35)
		_wet_rock(_stand(load(PROPS_DIR + small[(h / 3) % small.size()] + ".png"), at2), at2)


# The rocks that stand in the water: the river's shader froths around them
var wet_rocks: Array[Vector4] = []
var water_mat: ShaderMaterial

func _wet_rock(sprite: Sprite3D, foot: Vector3) -> void:
	if foot.x < RIVER.x - 0.3 or foot.x > RIVER.y + 0.3 or wet_rocks.size() >= 48:
		return
	var w := float(sprite.texture.get_width())
	var row := (foot.z * SIN50 - foot.y * COS50) / PX
	wet_rocks.append(Vector4(foot.x / PX, row, w / 2.0, maxf(w * 0.28, 3.0)))
	if water_mat:
		water_mat.set_shader_parameter("rocks", wet_rocks)
		water_mat.set_shader_parameter("rock_count", wet_rocks.size())


# ---------- The river ----------
const RIVER := Vector2(-15.0, -10.0)            # World x of the west and east water's edge (town.blend)
const WATER_Y := -0.28
const BRIDGE_AT := Vector3(-12.5, 0.0, -12.0)   # The middle of the bridge's deck
const BRIDGE_DECK_ROWS := 60.0                  # Rows of bridge.png that are the deck; below, the arch's face
const SIN50 := 0.76604444
const COS50 := 0.64278761
const WATER_SHADER := preload("res://assets/environment2d/water_river.gdshader")
const FOAM := preload("res://assets/environment2d/water_foam.png")


# The stone bridge from the pack, laid on the 3D deck (whose collider is kept): the deck's picture
# follows the arch you walk on, and the arch's face hangs from its south edge down to the water.
# The 3D bridge and its rails are hidden.
func _bridge() -> void:
	var tex := load(PROPS_DIR + "bridge.png") as Texture2D
	var rows := float(tex.get_height())
	var w := tex.get_width() * PX
	var x0 := BRIDGE_AT.x - w / 2.0
	var half := BRIDGE_DECK_ROWS * PX / SIN50 / 2.0
	var zn := BRIDGE_AT.z - half
	var zs := BRIDGE_AT.z + half
	# The face's foot: as far below the deck's ends (on the ground) as the picture's arch is tall
	var zb := zs + ((rows - BRIDGE_DECK_ROWS) * PX - (0.0 - WATER_Y) * COS50) / SIN50
	var space := get_world_3d().direct_space_state
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 48
	var cols := []
	for i in steps + 1:
		var x := x0 + w * float(i) / steps
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 3.0, BRIDGE_AT.z), Vector3(x, -2.0, BRIDGE_AT.z))
		var hit := space.intersect_ray(query)
		var y := 0.0
		if not hit.is_empty() and hit["position"].y > -0.5:
			y = maxf(hit["position"].y, 0.0)
		cols.append([x, y + 0.02, float(i) / steps])
	var v_deck := BRIDGE_DECK_ROWS / rows
	for i in steps:
		var a: Array = cols[i]
		var b: Array = cols[i + 1]
		# The deck
		_quad(st, Vector3(a[0], a[1], zn), Vector3(b[0], b[1], zn), Vector3(b[0], b[1], zs), Vector3(a[0], a[1], zs),
				Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(b[2], v_deck), Vector2(a[2], v_deck), Vector3.UP)
		# The arch's face, sloping down to the water toward the camera
		_quad(st, Vector3(a[0], a[1], zs), Vector3(b[0], b[1], zs), Vector3(b[0], WATER_Y + 0.01, zb), Vector3(a[0], WATER_Y + 0.01, zb),
				Vector2(a[2], v_deck), Vector2(b[2], v_deck), Vector2(b[2], 1.0), Vector2(a[2], 1.0), Vector3(0.0, SIN50, COS50))
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = _material(tex)
	painted.add_child(mesh)
	# Rocks at the arch's feet, where its stones go into the water
	for r in [[RIVER.x + 0.25, 0.10, "rock_07"], [RIVER.x + 0.75, 0.35, "rock_13"], [RIVER.x + 0.05, 0.45, "rock_03"],
			[RIVER.y - 0.3, 0.10, "rock_06"], [RIVER.y - 0.8, 0.35, "rock_14"], [RIVER.y - 0.05, 0.42, "rock_04"]]:
		var foot := Vector3(r[0], WATER_Y, zb + r[1])
		_wet_rock(_stand(load(PROPS_DIR + r[2] + ".png"), foot), foot)
	# Grass and moss where its ends meet the road
	for end_x in [x0 + 0.25, x0 + w - 0.25]:
		_tufts(Vector3(end_x, 0.0, zn + 0.25), Vector3(end_x, 0.0, zs + 0.1), 0.3, int(end_x * 10.0))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, normal: Vector3) -> void:
	# Wound to face up (the deck) and toward the camera (the face)
	for v in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
		st.set_normal(normal)
		st.set_uv(v[1])
		st.add_vertex(v[0])


# ---------- Fields and gardens ----------
const FIELDS := {   # Ada's fields (FarmField_W, FarmField_E): the soil is painted in the ground picture
	"W": [Rect2(29.4, -44.6, 4.0, 7.2), 3, 8, ["crop_carrot", "crop_young"]],
	"E": [Rect2(35.2, -44.6, 7.2, 6.6), 6, 7, ["crop_pumpkin", "crop_cabbage", "crop_cabbage2"]],
}
const BEDS_H := ["bed_h_leafy", "bed_h_orange", "bed_h_white"]
const BEDS_V := ["bed_v_leafy", "bed_v_orange", "bed_v_white"]


# Rows of painted vegetables on the soil, one kind to a row
func _fields() -> void:
	for key in FIELDS:
		var f: Array = FIELDS[key]
		var r: Rect2 = f[0]
		var kinds: Array = f[3]
		for j in f[2]:
			for i in f[1]:
				var x: float = r.position.x + (i + 0.5) * r.size.x / f[1]
				var z: float = r.position.y + (j + 0.75) * r.size.y / f[2]
				var kind: String = kinds[j % kinds.size()]
				if kind == "crop_pumpkin" and (i + j) % 2 == 1:
					kind = "crop_pumpkin2"
				var jitter := (float(hash(Vector2i(i, j)) % 5) - 2.0) * 0.03
				_stand(load(PROPS_DIR + kind + ".png"), Vector3(x + jitter, 0.0, z))
		# Grass grown over the edges of the soil
		var e := r.end
		var o := r.position
		_tufts(Vector3(o.x, 0.0, e.y + 0.05), Vector3(e.x, 0.0, e.y + 0.05), 0.45, 11 + key.unicode_at(0))
		_tufts(Vector3(o.x, 0.0, o.y + 0.1), Vector3(e.x, 0.0, o.y + 0.1), 0.5, 23 + key.unicode_at(0))
		_tufts(Vector3(o.x - 0.05, 0.0, o.y + 0.4), Vector3(o.x - 0.05, 0.0, e.y), 0.5, 37 + key.unicode_at(0))
		_tufts(Vector3(e.x + 0.05, 0.0, o.y + 0.4), Vector3(e.x + 0.05, 0.0, e.y), 0.5, 41 + key.unicode_at(0))


var garden_boxes: Array[AABB] = []

# The townsfolk's vegetable gardens (GSoil_*): raised beds from the pack in place of the soil and its fence
func _gardens(town: Node3D) -> void:
	for node in town.find_children("GSoil_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		var h := hash(String(mi.name))
		garden_boxes.append(box)
		# Grass around the beds' foot
		_tufts(Vector3(box.position.x - 0.05, 0.0, box.end.z + 0.05), Vector3(box.end.x + 0.05, 0.0, box.end.z + 0.05), 0.35, h % 1000)
		_tufts(Vector3(box.position.x - 0.1, 0.0, box.position.z + 0.3), Vector3(box.position.x - 0.1, 0.0, box.end.z), 0.45, h % 1000 + 1)
		_tufts(Vector3(box.end.x + 0.1, 0.0, box.position.z + 0.3), Vector3(box.end.x + 0.1, 0.0, box.end.z), 0.45, h % 1000 + 2)
		if box.size.x >= 2.0:  # Wide: beds one behind the other, north to south
			var n := maxi(1, roundi(box.size.z / 1.05))
			for i in n:
				var z := box.position.z + (i + 1) * box.size.z / n
				_stand(load(PROPS_DIR + BEDS_H[(h + i) % BEDS_H.size()] + ".png"), Vector3(box.get_center().x, 0.0, z))
		else:                  # Narrow: long beds side by side
			var m := maxi(1, floori(box.size.x / 0.75))
			for j in m:
				var x := box.position.x + (j + 0.5) * box.size.x / m
				_stand(load(PROPS_DIR + BEDS_V[(h + j) % BEDS_V.size()] + ".png"), Vector3(x, 0.0, box.end.z))


# The garlic the gardens grow (SafeZones.gd plants it in 3D): a painted plant at each one. Which
# garden has none is a clue, so it has to read as well as before.
func _garlic() -> void:
	var zones: Node = null
	for i in 240:  # The vampire's director sets the gardens up when the night's plans are made
		zones = get_tree().get_first_node_in_group("safe_zones")
		if zones and zones.get_child_count() > 0:
			break
		await get_tree().process_frame
	if zones == null or zones.get_child_count() == 0:
		return
	var tex := load(PROPS_DIR + "garlic.png") as Texture2D
	var glow := _garlic_material(tex)
	# SafeZones lines each garden's garlic along its west side: painted, it goes on top of the beds
	# instead, in two short rows side by side
	var by_garden := {}
	for plant in zones.get_children():
		if not plant is Node3D:
			continue
		for mi in plant.find_children("*", "MeshInstance3D", true, false):
			hidden.append(mi)
		var p: Vector3 = plant.global_position
		var home := -1
		for g in garden_boxes.size():
			var b: AABB = garden_boxes[g]
			if absf(p.x - b.position.x) < 0.6 and p.z > b.position.z - 0.3 and p.z < b.end.z + 0.3:
				home = g
				break
		if home < 0:
			_stand(tex, Vector3(p.x, 0.0, p.z)).material_override = glow  # Not by a garden we know: where it was
			continue
		by_garden[home] = by_garden.get(home, 0) + 1
	for g in by_garden:
		var b: AABB = garden_boxes[g]
		var count: int = by_garden[g]
		var rows := ceili(count / 2.0)
		var cols_x := [b.position.x + b.size.x * 0.25, b.position.x + b.size.x * 0.75]
		var step := minf(0.42, (b.size.z - 0.6) / maxf(rows - 1, 1))
		var z0 := b.get_center().z - step * (rows - 1) / 2.0
		for k in count:
			var z := z0 + step * (k / 2)
			# Pulled toward the camera past the beds' front, so it draws over their plants
			_stand(tex, Vector3(cols_x[k % 2], 0.0, z), -1.0, PULL + (b.end.z - z) + 0.15).material_override = glow
	_apply()


# ---------- Ada's stall ----------
const STALL_SHIFT := Vector3(0.0, 0.0, 3.3)         # South of its place in town.blend, off the plaza
const STALL_FOOT := Rect2(1.2, 11.8, 3.6, 2.2)      # Where it now stands: nothing else grows there
const TREE_CLEAR := [
	Rect2(-1.0, 11.5, 8.0, 5.0),    # In front of the stall
	Rect2(-9.5, -15.5, 4.0, 3.5),   # In front of Sarah's garden and the willow by the bridge
]
const CART_MIDDLE := Vector3(4.25, 0.0, 10.0)        # ColMarketStall's box, from town.blend
const STALL_MIDDLE := Vector3(3.0, 0.0, 10.0)        # The stall's picture, before the shift
var cleared: Array[Vector2] = []     # Where trees were taken away (their trunks' colliders go too)
var moved: Array = []                 # [StaticBody3D, its place in town.glb, where it goes with the painted town]


# The colliders of what was moved or taken away: the stall's two (the cart's and ColMarketStall) go
# with its picture; the cleared trees' trunks go under the ground. Then the navigation mesh, baked
# from the colliders, is baked again so the townsfolk walk around the stall where it now stands.
func _colliders(town: Node3D) -> void:
	var cart := AABB()
	var cart_mesh := town.find_child("Stall_Cart_Empty", true, false) as MeshInstance3D
	if cart_mesh:
		cart = cart_mesh.global_transform * cart_mesh.get_aabb()
	for body in town.find_children("*", "StaticBody3D", true, false):
		var box := _body_box(body)
		if box.size == Vector3.ZERO:
			continue
		var middle := Vector2(box.get_center().x, box.get_center().z)
		var to := Vector3.ZERO
		if cart.size != Vector3.ZERO and box.size.x < 4.0 and _overlap_xz(box, cart):
			# The cart's own collider moves with it; ColMarketStall (wider) is centred on the picture
			to = STALL_SHIFT if String(body.name) != "ColMarketStall" else STALL_MIDDLE + STALL_SHIFT - CART_MIDDLE
		elif box.size.x < 1.2 and box.size.z < 1.2 and cleared.any(func(t: Vector2): return t.distance_to(middle) < 0.9):
			to = Vector3(0.0, -60.0, 0.0)
		if to != Vector3.ZERO:
			moved.append([body, body.global_position, body.global_position + to])


func _body_box(body: Node) -> AABB:
	var out := AABB()
	for c in body.find_children("*", "CollisionShape3D", true, false):
		var shape := c as CollisionShape3D
		if shape.shape == null:
			continue
		var b: AABB = shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
		out = b if out.size == Vector3.ZERO else out.merge(b)
	return out


func _overlap_xz(a: AABB, b: AABB) -> bool:
	return Rect2(a.position.x, a.position.z, a.size.x, a.size.z).intersects(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))


func _rebake_navigation() -> void:
	var town := get_parent().find_child("town", true, false)
	var region := town.get_parent() as NavigationRegion3D if town else null
	if region and region.navigation_mesh and not region.is_baking():
		region.bake_navigation_mesh(true)  # On a thread: the old mesh serves until the new one is ready


# One material per picture, shared by every sprite that shows it (they batch)
var materials := {}

func _material(tex: Texture2D) -> ShaderMaterial:
	if not materials.has(tex):
		var mat := ShaderMaterial.new()
		mat.shader = SPRITE_SHADER
		mat.set_shader_parameter("tex", tex)
		mat.set_shader_parameter("lit_share", 0.5)
		mat.set_shader_parameter("own_light", 0.85)
		materials[tex] = mat
	return materials[tex]


# The garlic keeps a little of its own light at night, as the 3D garlic did (a clue: it must read after dark)
const GARLIC_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
global uniform float sprite_daylight;
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * 0.5;
	vec3 tint = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = c.rgb * 0.85 * max(sprite_daylight, 0.4) * tint;
	ROUGHNESS = 1.0;
}
"""

func _garlic_material(tex: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GARLIC_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tex", tex)
	return mat


# A painted piece standing in the town, its bottom middle on the spot
func _stand(tex: Texture2D, at: Vector3, foot_x := -1.0, pull := PULL) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = PX
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	sprite.offset = Vector2(w / 2.0 - (w / 2.0 if foot_x < 0.0 else foot_x), h / 2.0)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.material_override = _material(tex)
	sprite.scale.y = UPRIGHT
	sprite.position = at + TOWARD_CAMERA * pull
	painted.add_child(sprite)
	return sprite


# Tufts of grass along a line on the ground, where two textures meet (a bed, a field, the bridge's ends)
func _tufts(a: Vector3, b: Vector3, step: float, seed: int, pull := PULL) -> void:
	var n := maxi(1, roundi(a.distance_to(b) / step))
	for i in n + 1:
		var h := hash(Vector2i(seed, i))
		if h % 4 == 0:
			continue  # A gap now and then
		var at := a.lerp(b, float(i) / n) + Vector3(float(h % 7 - 3) * 0.03, 0.0, float((h / 7) % 5 - 2) * 0.03)
		_stand(load(PROPS_DIR + "tuft_%02d.png" % (h % 16)), at, -1.0, pull)


# The street lamps (StreetLamp.tscn): the post becomes a painted one with its lantern; the light stays
func _street_lamps() -> void:
	var post := load(PROPS_DIR + "lamppost.png") as Texture2D
	for lamp in get_parent().find_children("StreetLamp*", "Node3D", true, false):
		for mi in lamp.get_children():
			if mi is MeshInstance3D:
				hidden.append(mi)
		# The lantern hangs from the arm, a little east of the post: the post's foot is 4 px in
		_stand(post, Vector3(lamp.global_position.x, 0.0, lamp.global_position.z), 4.0)


# Gideon's stall (Merchant.gd builds it from boxes): a painted market stall instead
func _gideon() -> void:
	for m in get_parent().find_children("*", "Node3D", true, false):
		if m.get_script() == null or not String(m.get_script().resource_path).ends_with("Merchant.gd"):
			continue
		for piece in m.get_children():
			if piece is MeshInstance3D:
				hidden.append(piece)
		var at: Vector3 = (m.get_script() as GDScript).get_script_constant_map().get("STALL_AT", m.global_position)
		_stand(load(PROPS_DIR + "stall_gideon.png"), at + Vector3(0.0, 0.0, 0.45))


func _is_pine(mi: MeshInstance3D) -> bool:
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		if m and "Pine" in m.resource_name:
			return true
	return false


# Trees and their foliage come as two objects in one place, tall grass as clumps of six: one each
func _merge(spots: Array) -> Array:
	var out := []
	for s in spots:
		var reach := 1.3 if s[1] == "grass" else 0.8
		var found := false
		for o in out:
			if o[1] == s[1] and Vector2(o[0].x - s[0].x, o[0].z - s[0].z).length() < reach:
				o[2] = maxf(o[2], s[2])
				found = true
				break
		if not found:
			out.append(s.duplicate())
	return out


func _plant(at: Vector3, kind: String, height: float, autumn: bool) -> void:
	var piece: Array
	if kind == "tree":
		var size := 0 if height < 3.4 else (1 if height < 4.0 else (2 if height < 4.6 else (3 if height < 5.2 else 4)))
		piece = ART["tree_autumn" if autumn else "tree_green"][size]
	elif kind == "bush":
		piece = ART["bush_green"][3]
	else:
		piece = ART["bush_autumn"][4]
	var w: float = piece[2]
	var h: float = piece[3]
	var sprite := Sprite3D.new()
	sprite.texture = PLANTS
	sprite.region_enabled = true
	sprite.region_rect = Rect2(piece[0], piece[1], w, h)
	sprite.pixel_size = PX
	sprite.offset = Vector2(w / 2.0 - float(piece[4]), h / 2.0)  # The trunk's foot on the spot
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.material_override = _material(PLANTS)
	sprite.scale.y = UPRIGHT
	sprite.position = Vector3(at.x, 0.0, at.z) + TOWARD_CAMERA * PULL
	painted.add_child(sprite)
	# A small painted shadow under it, lying on the ground
	var shadow := Sprite3D.new()
	shadow.texture = SHADOW
	shadow.pixel_size = PX * clampf(w / 64.0 * 0.9, 0.35, 2.5)
	shadow.rotation.x = -PI / 2.0
	shadow.scale.y = 1.0 / 0.76604444  # Squashed back by the tilt, so it reads as drawn
	shadow.shaded = false
	shadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(at.x, 0.03, at.z)
	painted.add_child(shadow)


var ground_mat: ShaderMaterial

func _retile(mi: MeshInstance3D) -> void:
	if mi.mesh == null or not GROUND.search(String(mi.name)):
		return
	if ground_mat == null:
		ground_mat = ShaderMaterial.new()
		ground_mat.shader = GROUND_SHADER
		ground_mat.set_shader_parameter("baked", BAKED)
		ground_mat.set_shader_parameter("grass", GRASS)
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m and m.resource_name == "Water" and String(mi.name) == "Ground":
			ground.append([mi, i, mi.get_surface_override_material(i), _water_material()])
			continue
		if m == null or m.resource_name not in PAINTED_GROUND:
			continue  # The riverbed and the banks' soil keep their own look
		ground.append([mi, i, mi.get_surface_override_material(i), ground_mat])


func _water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	water_mat = mat
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("foam", FOAM)
	mat.set_shader_parameter("banks", RIVER)
	return mat


func _apply() -> void:
	for mi in hidden:
		mi.visible = not on
	if painted:
		painted.visible = on
	for g in ground:
		(g[0] as MeshInstance3D).set_surface_override_material(g[1], g[3] if on else g[2])
	for m in moved:
		(m[0] as Node3D).global_position = m[2] if on else m[1]
	if not moved.is_empty():
		_rebake_navigation.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and OS.is_debug_build():
		on = not on
		_apply()
		get_viewport().set_input_as_handled()
