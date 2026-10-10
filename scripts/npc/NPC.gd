extends CharacterBody3D

enum State { ROUTINE, TALKING, SCARED, SLEEPING }

@export var data: NPCData
@export var speed := 2.5
@export var wander := false      # Debug: walk to random places instead of the schedule
@export var show_state := true   # Debug: show the current state above the name

var state: State = State.ROUTINE
var current_place := ""
var stuck_time := 0.0
var highlighted := false
var line_index := 0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var name_label: Label3D = $NameLabel
@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("npcs")
	if data:
		var material := StandardMaterial3D.new()
		material.albedo_color = data.color
		mesh.material_override = material
	_update_label()
	# Wait until the navigation map actually has walkable area
	var map := agent.get_navigation_map()
	while NavigationServer3D.map_get_random_point(map, 1, true) == Vector3.ZERO:
		await get_tree().physics_frame
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	if wander:
		_pick_random_destination()
	else:
		_follow_schedule()
	


# ---------- State machine ----------

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.ROUTINE:
			_set_present(true)
			_follow_schedule()
		State.TALKING:
			agent.target_position = global_position  # Stop walking
		State.SCARED:
			_set_present(true)
			if data and data.home != "":
				_go_to_place(data.home)
		State.SLEEPING:
			_set_present(false)  # Went inside the house
	_update_label()


func _set_present(present: bool) -> void:
	visible = present
	collision.disabled = not present


func _update_label() -> void:
	var text: String = data.npc_name if data else String(name)
	if show_state:
		text += "\n(%s)" % State.keys()[state]
	if highlighted and state == State.ROUTINE:
		text += "\n[E] Falar"
	name_label.text = text

func can_talk() -> bool:
	return state == State.ROUTINE


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_update_label()


func talk(player: Node3D) -> void:
	set_state(State.TALKING)
	# Turn to face the doctor (ignore height so we don't tilt)
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	var line := "..."
	if data and not data.dialogue_lines.is_empty():
		# Go through the lines in order, looping back to the start
		line = data.dialogue_lines[line_index % data.dialogue_lines.size()]
		line_index += 1
	EventBus.dialogue_started.emit(data.npc_name if data else String(name), line)


func _on_dialogue_ended() -> void:
	if state == State.TALKING:
		set_state(State.ROUTINE)

# ---------- Movement ----------

func go_to(target: Vector3) -> void:
	agent.target_position = target


func _physics_process(delta: float) -> void:
	if state == State.SLEEPING:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var current_speed := speed * (1.8 if state == State.SCARED else 1.0)

	if state == State.TALKING or agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		if state != State.TALKING:
			_on_arrived()
	else:
		var direction := agent.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()

	# If trying to walk but barely moving for 2s, give up
	if state != State.TALKING and not agent.is_navigation_finished() and get_real_velocity().length() < 0.2:
		stuck_time += delta
		if stuck_time > 2.0:
			stuck_time = 0.0
			if wander:
				_pick_random_destination()
			else:
				agent.target_position = global_position  # Close enough: stop here
	else:
		stuck_time = 0.0


func _on_arrived() -> void:
	if wander:
		_pick_random_destination()
		return
	# Reached home at night (or while scared): go inside
	if data and current_place == data.home and (GameState.is_night or state == State.SCARED):
		set_state(State.SLEEPING)


# ---------- Schedule ----------

func _on_hour_changed(_hour: int) -> void:
	if wander or data == null:
		return
	if state == State.SLEEPING:
		if not GameState.is_night:
			set_state(State.ROUTINE)  # Wake up and start the day
		return
	if state == State.ROUTINE:
		_follow_schedule()


func _follow_schedule() -> void:
	if data == null or data.schedule.is_empty():
		return
	_go_to_place(_place_for_hour(int(GameState.hour)))


func _go_to_place(place: String) -> void:
	var marker := _find_location(place)
	if marker:
		current_place = place
		# Small random offset so people don't stack on the exact same spot
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


func _pick_random_destination() -> void:
	var map := agent.get_navigation_map()
	for i in 10:
		var point := NavigationServer3D.map_get_random_point(map, 1, true)
		if point != Vector3.ZERO and point.y < 1.0:
			go_to(point)
			return
	await get_tree().create_timer(0.2).timeout
	_pick_random_destination()
