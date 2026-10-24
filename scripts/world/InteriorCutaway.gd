extends Area3D

# A walk-in building: while the doctor is inside, its roof, upper floor and front wall are
# hidden so the top-down camera can see the room (a dollhouse cutaway).
# The pieces are named nodes inside town.glb, grouped in Blender as <Building>_Roof,
# <Building>_Upper, <Building>_UpperFront and <Building>_Front, where <Building> is this
# area's parent node (Clinica, Taverna...). Groups a building doesn't have are simply skipped.
# Two levels: downstairs everything above the room is cut away; upstairs (via the stairs)
# only the roof and the front walls go, so the upper room and its beds show.

const PART_SUFFIXES := ["_Roof", "_Upper", "_UpperFront", "_Front"]
const UPSTAIRS_HEIGHT := 1.6  # Doctor's feet above this = on the upper floor

@export var hide_sign := true  # The floating name label sits right over the room

var parts: Dictionary = {}     # suffix -> Node3D
var sign_label: Node3D = null
var building := ""
var player: Node3D = null      # The doctor, while inside
var upstairs := false


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


func _apply(open: bool) -> void:
	for suffix in parts:
		var cut: bool = open and not (upstairs and suffix == "_Upper")
		parts[suffix].visible = not cut
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
