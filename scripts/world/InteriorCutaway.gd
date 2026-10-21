extends Area3D

# A walk-in building: while the doctor is inside, its roof and front wall are hidden
# so the top-down camera can see the room (a dollhouse cutaway).
# The pieces are named nodes inside town.glb (grouped in Blender), found by name.

@export var hide_names: PackedStringArray = ["Clinica_Roof", "Clinica_Front"]
@export var hide_sign := true  # The floating name label sits right over the room

var parts: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# town.glb may finish loading after us, so look the parts up once the scene is ready
	await get_tree().process_frame
	var scene := get_tree().current_scene
	for part_name in hide_names:
		var node := scene.find_child(part_name, true, false) as Node3D
		if node:
			parts.append(node)
		else:
			push_warning("InteriorCutaway: no node named %s" % part_name)
	if hide_sign:
		var sign := get_parent().get_node_or_null("Sign") as Node3D
		if sign:
			parts.append(sign)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_set_open(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_set_open(false)


func _set_open(open: bool) -> void:
	for part in parts:
		part.visible = not open
