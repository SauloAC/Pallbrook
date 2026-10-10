extends CharacterBody3D

@export var data: NPCData
@export var speed := 2.5
@export var wander := false  # Debug: walk to random places instead of following the schedule

var stuck_time := 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var name_label: Label3D = $NameLabel
@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("npcs")
	if data:
		name_label.text = data.npc_name
		var material := StandardMaterial3D.new()
		material.albedo_color = data.color
		mesh.material_override = material
	# Wait until the navigation map has actually been built
	# Wait until the navigation map actually has walkable area
	var map := agent.get_navigation_map()
	while NavigationServer3D.map_get_random_point(map, 1, true) == Vector3.ZERO:
		await get_tree().physics_frame
	EventBus.hour_changed.connect(_on_hour_changed)
	if wander:
		_pick_random_destination()
	else:
		_on_hour_changed(int(GameState.hour))  # Go to where I should be right now


func go_to(target: Vector3) -> void:
	agent.target_position = target


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		if wander:
			_pick_random_destination()
	else:
		# Walk toward the next corner of the calculated path
		var direction := agent.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

	move_and_slide()

	# If trying to walk but barely moving for 2s, give up
	if not agent.is_navigation_finished() and get_real_velocity().length() < 0.2:
		stuck_time += delta
		if stuck_time > 2.0:
			stuck_time = 0.0
			if wander:
				_pick_random_destination()
			else:
				agent.target_position = global_position  # Close enough: stop here
	else:
		stuck_time = 0.0


func _pick_random_destination() -> void:
	var map := agent.get_navigation_map()
	for i in 10:
		var point := NavigationServer3D.map_get_random_point(map, 1, true)
		# Skip the empty map (0,0,0) and rooftops (high y)
		if point != Vector3.ZERO and point.y < 1.0:
			go_to(point)
			return
	# Map not ready yet: try again in a moment
	await get_tree().create_timer(0.2).timeout
	_pick_random_destination()


func _on_hour_changed(hour: int) -> void:
	if wander or data == null or data.schedule.is_empty():
		return
	var marker := _find_location(_place_for_hour(hour))
	if marker:
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		go_to(marker.global_position + offset)


func _place_for_hour(hour: int) -> String:
	var hours := data.schedule.keys()
	hours.sort()
	var place: String = data.schedule[hours[-1]]  # Default: last entry (carried over from yesterday)
	for h in hours:
		if h <= hour:
			place = data.schedule[h]
	return place


func _find_location(place: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("locations"):
		if node.name == place:
			return node
	push_warning("Location not found: " + place)
	return null
