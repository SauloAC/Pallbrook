class_name ClinicMural
extends Node3D

# The cork board on the clinic's back wall, between the bed and the cabinet. Walk up to it and
# press E to study the outbreak map (Mural.gd). Day or night.

const ICON := preload("res://assets/ui/icon_examine.png")
const MAP_TEX := "res://assets/ui/mural/map.png"
# From the clinic's door marker (Locations/Clinica), so the board moves with the building
const BOARD_FROM_DOOR := Vector3(-0.71, 1.6, -5.3)   # Centre of the board, on the inner face of the back wall
const USE_FROM_DOOR := Vector3(-0.71, 0.0, -4.6)     # Where the doctor stands to read it
const USE_RANGE := 0.75
const WOOD := Color(0.24, 0.15, 0.09)
const CORK := Color(0.58, 0.43, 0.27)
const PAPER := Color(0.92, 0.88, 0.78)
const PIN := Color(0.72, 0.1, 0.08)

var prompt: Sprite3D
var board: Mural


var board_at := Vector3.ZERO
var use_at := Vector3.ZERO


func _ready() -> void:
	var door := GameState.place_position("Clinica")
	board_at = door + BOARD_FROM_DOOR
	use_at = door + USE_FROM_DOOR
	_build_board()
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.position = board_at + Vector3(0.0, 0.85, 0.2)
	prompt.visible = false
	add_child(prompt)
	board = Mural.new()
	add_child(board)


func _build_board() -> void:
	_box(board_at, Vector3(1.3, 0.95, 0.05), WOOD)
	_box(board_at + Vector3(0.0, 0.0, 0.01), Vector3(1.18, 0.83, 0.05), CORK)
	# The map in the middle, papers around it, a few pins and a thread
	var front := board_at.z + 0.04
	var map := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.7)
	map.mesh = quad
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(MAP_TEX):
		mat.albedo_texture = load(MAP_TEX)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	else:
		mat.albedo_color = PAPER
	map.material_override = mat
	add_child(map)
	map.position = Vector3(board_at.x, board_at.y, front)
	for spot in [Vector2(-0.43, 0.22), Vector2(-0.43, -0.12), Vector2(0.43, 0.25), Vector2(0.44, -0.05), Vector2(0.42, -0.28)]:
		_box(Vector3(board_at.x + spot.x, board_at.y + spot.y, front - 0.005), Vector3(0.22, 0.14, 0.004), PAPER)
		_box(Vector3(board_at.x + spot.x, board_at.y + spot.y + 0.055, front + 0.004), Vector3(0.025, 0.025, 0.02), PIN)
	for spot in [Vector2(-0.08, 0.15), Vector2(0.1, -0.12), Vector2(0.02, 0.24)]:
		_box(Vector3(board_at.x + spot.x, board_at.y + spot.y, front + 0.008), Vector3(0.03, 0.03, 0.02), PIN)


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	piece.material_override = mat
	add_child(piece)
	piece.position = at


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - use_at
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	GameState.near_mural = near
	prompt.visible = near and not GameState.in_dialogue and not GameState.reading and not board.is_open


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	board.open_board()
