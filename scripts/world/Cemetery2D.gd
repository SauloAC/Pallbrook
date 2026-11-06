class_name Cemetery2D
extends RefCounted

# The cemetery beyond the bridge, painted (6 Nov), like the rest of the town (see Nature2D). Its 3D pieces
# are gone from town.glb (the _Removed collection in town.blend); this lays the painted ones and their
# colliders. The graves, the statue, the pillars come from the Cainos "Basic" pack, as the buildings and
# the greenery come from its "Village" pack; what it lacks (the crypt, the iron fence and its arch, the
# dead trees, the lanterns, the road's gate) are KayKit Halloween Bits (CC0) rendered from 3D in the town's
# camera and coloured with the pack's own ramps (art_source/tools/cemetery/). The ground (darker grass, the
# paved walks, the old graves' sunken plots) is painted into ground_baked.png (env2d/bake.py, same places).
#
# Inside the iron fence (x -26.4..-17.6, z -10.8..1.0): the arch on the north side, onto the road from the
# bridge; the walk from it down to the praying statue at the south end; the crypt in the north-west
# corner, facing the graves; the old graves in rows either side of the walk, each stone at the south
# end of its plot, toward the camera. The new graves (GraveSlot_1..8 in town.blend), wooden crosses,
# narrower than the stones, fill the south rows and the rest of the row by the crypt.

const DIR := "res://assets/environment2d/props/"
const FENCE := Rect2(-26.4, -10.8, 8.8, 9.0)           # x, z (north), width, depth
const ARCH_X := -22.0                                 # The arch's middle; its opening x -22.8..-21.2
const CRYPT := Rect2(-26.1, -10.55, 2.84, 2.88)       # The crypt's footprint; its door faces south
const STATUE := Vector3(-22.0, 0.0, -2.3)             # Its foot, at the walk's south end
const OLD_GRAVES := [                                 # [stone, foot]: the stone's south side
	["cem_tall", Vector3(-25.5, 0.0, -5.3)],
	["cem_rip", Vector3(-20.6, 0.0, -8.1)], ["cem_broken", Vector3(-18.6, 0.0, -8.1)],
	["cem_low", Vector3(-20.6, 0.0, -5.3)], ["cem_tomb", Vector3(-18.65, 0.0, -5.3)],
]
# Outside the fence; the east one far enough south that its picture leaves the road and Gideon's stall clear
const DEAD_TREES := [["cem_tree_dead_l", Vector3(-27.3, 0.0, -5.8)], ["cem_tree_dead_m", Vector3(-16.9, 0.0, -4.6)]]
const LANTERNS := [Vector3(-23.15, 0.0, -10.7), Vector3(-20.85, 0.0, -10.7)]
const ROAD_GATE := Vector3(-26.9, 0.0, -10.5)         # The town's gate across the road, west of the arch (its south end)
const SIDE_STEP := 3.0                                # One side run of the fence (cem_fence_side.png)


# The street lamp by the arch (StreetLamp7, Cidade.tscn) stands on the fence's line, and its picture came
# out in front of the fence, as if the post stood on the wall. Pulled less toward the camera, along the
# camera's own line of sight, it shows in the same place on screen but behind the fence, which then hides
# its foot: the post rises from behind the wall.
static func lamp_pull(at: Vector3, pull: float) -> float:
	if at.x > FENCE.position.x and at.x < FENCE.end.x and absf(at.z - FENCE.position.y) < 0.5:
		return pull - 0.25
	return pull


static func build(n: Nature2D, region: Node3D) -> void:
	var north := FENCE.position.y
	var south := FENCE.end.y
	var west := FENCE.position.x
	var east := FENCE.end.x
	# The fence: the north side either side of the arch, the south side and the sides in three
	var fence_n := load(DIR + "cem_fence_n.png") as Texture2D
	var fence_s := load(DIR + "cem_fence_s.png") as Texture2D
	var fence_side := load(DIR + "cem_fence_side.png") as Texture2D
	n._stand(fence_n, Vector3((west + ARCH_X - 0.9) / 2.0, 0.0, north + 0.19))
	n._stand(fence_n, Vector3((east + ARCH_X + 0.9) / 2.0, 0.0, north + 0.19))
	n._stand(load(DIR + "cem_arch.png"), Vector3(ARCH_X, 0.0, north + 0.19))
	for i in 3:
		n._stand(fence_s, Vector3(west + (i + 0.5) * (east - west) / 3.0, 0.0, south + 0.19))
	for x in [west, east]:
		for i in 3:
			n._stand(fence_side, Vector3(x, 0.0, north + SIDE_STEP * (i + 1)))
	n._stand(load(DIR + "cem_crypt.png"), Vector3(CRYPT.get_center().x, 0.0, CRYPT.end.y))
	n._stand(load(DIR + "cem_statue.png"), STATUE)
	for g in OLD_GRAVES:
		n._stand(load(DIR + g[0] + ".png"), g[1])
	for t in DEAD_TREES:
		var tex := load(DIR + t[0] + ".png") as Texture2D
		n._stand(tex, t[1]).material_override = n._sway_material(tex, "tree", tex.get_height())
	for at in LANTERNS:
		n._stand(load(DIR + "cem_post_lantern.png"), at)
	n._stand(load(DIR + "cem_gate_side.png"), ROAD_GATE)
	# Grass grown along the foot of the fence, inside and out
	n._tufts(Vector3(west + 0.3, 0.0, south - 0.05), Vector3(east - 0.3, 0.0, south - 0.05), 0.45, 501)
	n._tufts(Vector3(west + 0.25, 0.0, north + 0.6), Vector3(west + 0.25, 0.0, south - 0.3), 0.55, 502)
	n._tufts(Vector3(east - 0.25, 0.0, north + 0.6), Vector3(east - 0.25, 0.0, south - 0.3), 0.55, 503)
	n._tufts(Vector3(west - 0.2, 0.0, south + 0.35), Vector3(east + 0.2, 0.0, south + 0.35), 0.5, 504)
	_colliders(region)


# Where nobody walks through: the fence (open under the arch), the crypt, the statue, the stones, the
# trees' trunks, the lantern posts and the road's south side either side; and the floor of its south
# part. Under the navigation region, so its mesh is baked around (and over) them.
static func _colliders(region: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Cemetery2DColliders"
	region.add_child(body)
	var north := FENCE.position.y
	var south := FENCE.end.y
	var west := FENCE.position.x
	var east := FENCE.end.x
	var boxes := [
		[west, ARCH_X - 0.8, north - 0.15, north + 0.15], [ARCH_X + 0.8, east, north - 0.15, north + 0.15],
		[west, east, south - 0.15, south + 0.15],
		[west - 0.15, west + 0.15, north, south], [east - 0.15, east + 0.15, north, south],
		[CRYPT.position.x, CRYPT.end.x, CRYPT.position.y, CRYPT.end.y - 0.1],
		[STATUE.x - 0.75, STATUE.x + 0.75, STATUE.z - 0.75, STATUE.z - 0.05],
	]
	for g in OLD_GRAVES:
		var foot: Vector3 = g[1]
		if g[0] == "cem_tomb":   # A stone tomb over the whole plot
			boxes.append([foot.x - 0.6, foot.x + 0.6, foot.z - 2.2, foot.z - 0.05])
		else:
			boxes.append([foot.x - 0.55, foot.x + 0.55, foot.z - 0.4, foot.z - 0.05])
	for t in DEAD_TREES:
		boxes.append([t[1].x - 0.25, t[1].x + 0.25, t[1].z - 0.4, t[1].z - 0.05])
	for at: Vector3 in LANTERNS:
		boxes.append([at.x - 0.15, at.x + 0.15, at.z - 0.3, at.z - 0.05])
	# The road's south side either side of the cemetery, so nobody walks off the west bank's floor: from
	# the road's gate to the fence, and from the fence to the bridge's rail (its wooden fence is town.glb's)
	boxes.append([-26.9, west, north - 0.15, north + 0.05])
	boxes.append([east, -15.6, north - 0.15, north + 0.05])
	for b in boxes:
		_box(body, b[0], b[1], b[2], b[3], 0.0, 1.5)
	# The ground under the cemetery's south edge: the west bank's floor (Col046 in town.blend) stops at
	# z -2.6, where the old crypt stood
	_box(body, west - 0.3, east + 0.3, -2.7, south + 0.3, -0.7, 0.0)


static func _box(body: StaticBody3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	shape.shape = box
	shape.position = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	body.add_child(shape)


# ---------- A grave dug during the game ----------
# A wooden cross with the name on it, and the fresh mound of earth behind it (north, away from the
# camera), at a GraveSlot. Static: NPC.make_headstone (a burial) and VampireDirector (Jonas, the week
# before the doctor came) both lay one.
const SPRITE_SHADER := preload("res://assets/buildings2d/sprite_surface.gdshader")
const PX := 0.04375
const UPRIGHT := 1.5557238
const TOWARD_CAMERA := Vector3(0.0, 0.76604444, 0.64278761)

static func grave(title: String, subtitle: String) -> Node3D:
	var node := Node3D.new()
	node.add_child(_sprite(load(DIR + "cem_mound.png"), Vector3(0.0, 0.0, -0.15)))
	node.add_child(_sprite(load(DIR + "cem_marker.png"), Vector3.ZERO))
	var plate := Label3D.new()
	plate.text = "%s\n%s" % [title, subtitle]
	plate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Already in the current language
	plate.font_size = 48
	plate.outline_size = 12
	plate.pixel_size = 0.006
	plate.position = Vector3(0.0, 1.25, 0.2)   # Over the cross: the fence in front would hide it lower down
	plate.modulate = Color(0.9, 0.88, 0.82)
	node.add_child(plate)
	return node


static func _sprite(tex: Texture2D, at: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = PX
	sprite.offset = Vector2(0.0, tex.get_height() / 2.0)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("lit_share", 0.5)
	mat.set_shader_parameter("own_light", 0.85)
	sprite.material_override = mat
	sprite.scale.y = UPRIGHT
	sprite.position = at + TOWARD_CAMERA * 0.5
	return sprite
