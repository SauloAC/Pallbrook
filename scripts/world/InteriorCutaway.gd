extends Area3D

# A walk-in building: while the doctor is inside, its roof, upper floor and front wall are
# hidden so the top-down camera can see the room (a dollhouse cutaway).
# The pieces are named nodes inside town.glb, grouped in Blender as <Building>_Roof,
# <Building>_Upper, <Building>_UpperFront and <Building>_Front, where <Building> is this
# area's parent node (Clinica, Taverna...). Groups a building doesn't have are simply skipped.
# Two levels: downstairs everything above the room is cut away; upstairs (via the stairs)
# only the roof and the front walls go, so the upper room and its beds show.
# 2D buildings also have <Building>_Inside: the room itself, shown only while the doctor is in
# (from outside it would show through the transparent parts of the painted facade).

const PART_SUFFIXES := ["_Roof", "_Upper", "_UpperFront", "_Front"]
const UPSTAIRS_HEIGHT := 1.6  # Doctor's feet above this = on the upper floor
# While the doctor is upstairs, whoever is on the floor below would show through the upper floor
# (sprites and name labels): they go to a render layer the camera leaves out
const BELOW_LAYER := 1 << 19

@export var hide_sign := true  # The floating name label sits right over the room

var parts: Dictionary = {}     # suffix -> Node3D
var sign_label: Node3D = null
var inside: Node3D = null      # <Building>_Inside, for 2D buildings
var lower: Node3D = null       # <Building>_Lower: shown only while the doctor is inside downstairs
var building := ""
var player: Node3D = null      # The doctor, while inside
var upstairs := false
var below := {}                # NPC -> {its visual node: its own render layers}, while hidden under the floor


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(false)
	# town.glb may finish loading after us, so look the parts up once the scene is ready
	await get_tree().process_frame
	building = get_parent().name
	var scene := get_tree().current_scene
	for suffix in PART_SUFFIXES:
		var node := scene.find_child(building + suffix, true, false) as Node3D
		if node:
			parts[suffix] = node
	inside = scene.find_child(building + "_Inside", true, false) as Node3D
	if inside:
		inside.visible = false
	lower = scene.find_child(building + "_Lower", true, false) as Node3D
	if parts.is_empty():
		push_warning("InteriorCutaway: no %s_Roof/_Upper/_Front nodes found" % building)
	if hide_sign:
		sign_label = get_parent().get_node_or_null("Sign") as Node3D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node3D
		upstairs = player.global_position.y > UPSTAIRS_HEIGHT
		_apply(true)
		set_process(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player = null
		upstairs = false
		_apply(false)
		set_process(false)


# Switch levels as the doctor climbs or goes down the stairs
func _process(_delta: float) -> void:
	if player == null:
		return
	var now_up := player.global_position.y > UPSTAIRS_HEIGHT
	if now_up != upstairs:
		upstairs = now_up
		_apply(true)
	if upstairs:
		_hide_below()


# Upstairs: hide the people downstairs in this building (and show them again once they leave it)
func _hide_below() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.cull_mask &= ~BELOW_LAYER
	for npc in get_tree().get_nodes_in_group("npcs"):
		var n := npc as Node3D
		var hide_it := n.global_position.y < UPSTAIRS_HEIGHT and _over_room(n.global_position)
		if hide_it and not below.has(n):
			var saved := {}
			for v in n.find_children("*", "VisualInstance3D", true, false):
				saved[v] = (v as VisualInstance3D).layers
				(v as VisualInstance3D).layers = BELOW_LAYER
			below[n] = saved
		elif not hide_it and below.has(n):
			_show_again(n)


func _show_again(n: Node) -> void:
	var saved: Dictionary = below[n]
	below.erase(n)
	for v in saved:
		if is_instance_valid(v):
			(v as VisualInstance3D).layers = saved[v]


func _show_all() -> void:
	for n in below.keys():
		_show_again(n)


# Within this building's walls (its area's boxes), seen from above
func _over_room(p: Vector3) -> bool:
	for c in get_children():
		var shape := c as CollisionShape3D
		if shape == null or not (shape.shape is BoxShape3D):
			continue
		var l := shape.global_transform.affine_inverse() * p
		var half: Vector3 = (shape.shape as BoxShape3D).size / 2.0
		if absf(l.x) <= half.x and absf(l.z) <= half.z:
			return true
	return false


func _apply(open: bool) -> void:
	if not (open and upstairs):
		_show_all()
	for suffix in parts:
		var cut: bool = open and not (upstairs and suffix == "_Upper")
		parts[suffix].visible = not cut
	if inside:
		inside.visible = open
	if lower:
		lower.visible = open and not upstairs
	if sign_label:
		sign_label.visible = not open
	if open:
		GameState.open_building = building
		GameState.open_upstairs = upstairs
	elif GameState.open_building == building:
		GameState.open_building = ""
		GameState.open_upstairs = false
	# Whoever sleeps upstairs goes with the upper floor
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.in_bed and npc.data and npc.data.home == building and npc.bed_upstairs():
			npc.visible = not open or upstairs
