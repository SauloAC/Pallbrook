extends Area3D

# A walk-in building: while the doctor is inside, its roof, upper floor and front wall are
# hidden so the top-down camera can see the room (a dollhouse cutaway).
# The pieces are named nodes inside town.glb, grouped in Blender as <Building>_Roof,
# <Building>_Upper and <Building>_Front, where <Building> is this area's parent node
# (Clinica, Taverna...). Groups a building doesn't have are simply skipped.

const PART_SUFFIXES := ["_Roof", "_Upper", "_Front"]

@export var hide_sign := true  # The floating name label sits right over the room

var parts: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# town.glb may finish loading after us, so look the parts up once the scene is ready
	await get_tree().process_frame
	var building := get_parent().name
	var scene := get_tree().current_scene
	for suffix in PART_SUFFIXES:
		var node := scene.find_child(building + suffix, true, false) as Node3D
		if node:
			parts.append(node)
	if parts.is_empty():
		push_warning("InteriorCutaway: no %s_Roof/_Upper/_Front nodes found" % building)
	if hide_sign:
		var sign_label := get_parent().get_node_or_null("Sign") as Node3D
		if sign_label:
			parts.append(sign_label)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_set_open(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_set_open(false)


func _set_open(open: bool) -> void:
	for part in parts:
		part.visible = not open
