extends CharacterBody3D

@export var data: NPCData
@export var speed := 2.5
@export var wander := true  # Temporary test: walk to random places
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
	# The navigation map is only ready after the first physics frame
		# Wait until the navigation map has actually been built
	var map := agent.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	if wander:
		_pick_random_destination()

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
		# If trying to walk but barely moving for 2s, give up and pick another place
	if not agent.is_navigation_finished() and get_real_velocity().length() < 0.2:
		stuck_time += delta
		if stuck_time > 2.0 and wander:
			stuck_time = 0.0
			_pick_random_destination()
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
