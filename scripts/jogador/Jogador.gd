extends CharacterBody3D

@export var speed := 5.0
@export var talk_range := 2.5

var nearby_npc: Node3D = null
var spawn_point: Vector3
var visual: CharacterVisual = null
var step_timer := 0.0
const STEP_INTERVAL := 0.42


func _ready() -> void:
	add_to_group("player")  # Lets the vampire know where the doctor is
	spawn_point = global_position  # Where the doctor starts; used if he ever falls off
	visual = CharacterVisual.new()
	add_child(visual)
	visual.position.y = -1.0  # The doctor's body origin sits at the capsule's center
	if visual.setup("Doctor"):
		$MeshInstance3D.visible = false
	else:
		visual.queue_free()
		visual = null


func _physics_process(delta: float) -> void:
	if global_position.y < -5.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
		reset_physics_interpolation()  # Teleport instantly, don't slide there
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if GameState.in_dialogue:
		# Stand still while talking
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# Camera looks straight north, so "up" on the keyboard is -z in the world
		var direction := Vector3(input.x, 0, input.y)
		var current_speed := speed * (1.0 - GameState.exhaustion * 0.6)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()
	if visual:
		visual.animate(get_real_velocity(), delta)
	_footsteps(delta)
	_update_nearby_npc()


func _footsteps(delta: float) -> void:
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if not moving:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = STEP_INTERVAL / maxf(1.0 - GameState.exhaustion * 0.6, 0.4)  # Slower when tired
		Audio.play("step_%d" % (randi() % 5), -26.0, 0.0, 0.08)  # Soft steps on dirt


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
	if GameState.in_dialogue or nearby_npc == null:
		return
	if event.is_action_pressed("interact"):
		nearby_npc.set_highlighted(false)
		nearby_npc.talk(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accuse") and nearby_npc.is_alive():
		nearby_npc.set_highlighted(false)
		EventBus.accusation_requested.emit(nearby_npc)
		get_viewport().set_input_as_handled()
