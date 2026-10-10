extends CharacterBody3D

@export var speed := 5.0
@export var talk_range := 2.5

var nearby_npc: Node3D = null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if GameState.in_dialogue:
		# Stand still while talking
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# Rotate input 45° so "up" matches the isometric camera's screen direction
		var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, deg_to_rad(45))
		var current_speed := speed * (1.0 - GameState.exhaustion * 0.6)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()
	_update_nearby_npc()


func _update_nearby_npc() -> void:
	var closest: Node3D = null
	var closest_distance := talk_range
	if GameState.in_dialogue:
		closest_distance = 0.0  # Nobody is "nearby" while already talking
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not npc.can_talk():
			continue
		var distance: float = global_position.distance_to(npc.global_position)
		if distance < closest_distance:
			closest = npc
			closest_distance = distance
	# Only the closest NPC shows the "[E] Falar" prompt
	if closest != nearby_npc:
		if nearby_npc:
			nearby_npc.set_highlighted(false)
		nearby_npc = closest
		if nearby_npc:
			nearby_npc.set_highlighted(true)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.in_dialogue:
		return
	if event.is_action_pressed("interact") and nearby_npc:
		nearby_npc.set_highlighted(false)
		nearby_npc.talk(self)
		get_viewport().set_input_as_handled()
