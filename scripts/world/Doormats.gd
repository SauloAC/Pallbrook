class_name Doormats
extends Node3D

# A small mat just inside every front door, so the way out is easy to spot from inside.
# Built from the doors in town.glb (Door_1_Round*, all on the south walls); the church
# already has its long carpet running from the door.

const SKIP := ["Igreja_Front"]
const DOOR_WIDTH := 1.16       # The door model, measured in Blender
const SIZE := Vector2(1.05, 0.55)
const INSIDE := 0.6            # How far in from the door (north, -z)
const BORDER := Color(0.47, 0.33, 0.17)
const MIDDLE := Color(0.46, 0.13, 0.09)


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	await get_tree().process_frame  # town.glb may finish loading after us
	var border := _material(BORDER)
	var middle := _material(MIDDLE)
	for door in get_tree().current_scene.find_children("Door_1_Round*", "Node3D", true, false):
		if door.get_parent() and String(door.get_parent().name) in SKIP:
			continue
		var d := door as Node3D
		# The door's origin is its hinge; its middle is half a door along its own x
		var middle_point := d.global_position + d.global_basis * Vector3(DOOR_WIDTH * 0.5, 0.0, 0.0)
		var at := Vector3(middle_point.x, d.global_position.y, middle_point.z - INSIDE)
		_mat_piece(at + Vector3(0.0, 0.015, 0.0), SIZE, border)
		_mat_piece(at + Vector3(0.0, 0.02, 0.0), SIZE - Vector2(0.14, 0.14), middle)


func _mat_piece(at: Vector3, size: Vector2, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.01, size.y)
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	piece.global_position = at


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
