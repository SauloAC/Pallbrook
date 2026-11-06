class_name Seat
extends Marker3D

# A place to sit (3 Nov): put one on each chair, stool or bench the doctor may use, on the floor
# where his feet go, and pick which way he faces. Near it, an icon shows and E sits him down;
# any movement stands him up again. Lunch and other scenes can also seat him (sit_player).
# Sitting takes the doctor off physics, so a chair's collision doesn't push him out of it;
# when he stands he steps back to where he stood before sitting down.

@export_enum("south", "east", "north", "west") var facing := "south"
@export var use_range := 0.8
@export var interactive := true   # False for seats only scenes use (lunch), never offered by E

const ICON := preload("res://assets/ui/icon_sit.png")

var prompt: Sprite3D
var sitter: Node3D = null   # The doctor while he sits here
var stand_at := Vector3.ZERO  # Where he stood before sitting: he gets up there (a stool's collision would lift him onto it)


func _ready() -> void:
	add_to_group("seats")
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	prompt.top_level = true
	add_child(prompt)
	prompt.global_position = global_position + Vector3(0.0, 1.8, 0.0)


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")  # Untyped: Jogador fields
	if sitter:
		prompt.visible = false
		var wants := Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1
		if wants and not GameState.in_dialogue and not GameState.reading:
			stand_player()
		return
	var near := false
	if player and interactive and player.visual and not player.visual.seated:
		var gap: Vector3 = player.global_position - global_position
		near = Vector2(gap.x, gap.z).length() < use_range and absf(gap.y) < 2.5
	# Talking to someone close by comes first: the doctor's own E is theirs then
	prompt.visible = near and player.nearby_npc == null and not GameState.in_dialogue \
			and not GameState.reading and not GameState.chased


func _unhandled_input(event: InputEvent) -> void:
	if prompt == null or not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	sit_player(get_tree().get_first_node_in_group("player"))


# Seats the doctor here, facing the way the seat faces. Returns false if he can't sit (no sprite clip)
func sit_player(player) -> bool:
	if player == null or player.visual == null or sitter:
		return false
	var was_at: Vector3 = player.global_position
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.global_position = Vector3(global_position.x, player.global_position.y, global_position.z)
	player.reset_physics_interpolation()
	if player.visual.sit(facing) <= 0.0:
		player.global_position = was_at  # No sitting clip for this body: he stays where he was
		player.reset_physics_interpolation()
		player.set_physics_process(true)
		return false
	sitter = player
	stand_at = was_at
	return true


func stand_player() -> void:
	if sitter == null:
		return
	sitter.visual.stand_up()
	sitter.global_position = stand_at
	sitter.reset_physics_interpolation()
	sitter.set_physics_process(true)
	sitter = null


# The closest seat to a point within reach, or null
static func nearest(tree: SceneTree, point: Vector3, reach: float) -> Seat:
	var best: Seat = null
	for seat: Seat in tree.get_nodes_in_group("seats"):
		var d := Vector2(seat.global_position.x - point.x, seat.global_position.z - point.z).length()
		if d < reach and seat.sitter == null:
			best = seat
			reach = d
	return best
