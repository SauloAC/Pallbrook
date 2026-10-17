extends CharacterBody3D

enum State { ROUTINE, TALKING, SCARED, SLEEPING, DEAD, HUNTING }

@export var data: NPCData
@export var speed := 2.5
@export var wander := false      # Debug: walk to random places instead of the schedule
@export var show_state := false   # Debug: show the current state above the name
@export var witness_range := 5.0  # How close the doctor must be to recognize a hunting vampire

var hunt_returning := false
var witnessed := false
var is_dark := false
var normal_color: Color
var state: State = State.ROUTINE
var current_place := ""
var stuck_time := 0.0
var highlighted := false
var line_index := 0
var is_servant := false
var examined := false
var body_trace := ""

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var name_label: Label3D = $NameLabel
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var prompt_icon: Sprite3D = $PromptIcon

const ICON_TALK := preload("res://assets/ui/icon_talk.png")
const ICON_EXAMINE := preload("res://assets/ui/icon_examine.png")
const HIGHLIGHT_COLOR := Color("C2A65B")


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
	# Leaving the hunt: back to a normal, recognizable person
	if new_state != State.HUNTING and is_dark:
		_set_dark(false)
		name_label.visible = true
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
		State.DEAD:
			_set_present(true)
			collision.disabled = true  # Bodies don't block the way
			velocity = Vector3.ZERO
			agent.target_position = global_position
			# The body is found at the door of their home
			var home_marker: Node3D = null
			if data:
				home_marker = _find_location(data.home)
			if home_marker:
				# Push the body toward the middle of the street, so buildings don't hide it
				var toward_street := -signf(home_marker.global_position.x) * 1.5
				global_position = home_marker.global_position + Vector3(toward_street, 0.0, 0.8)
			# Lying on the ground
			mesh.rotation_degrees.x = 90.0
			mesh.position.y = 0.5
			name_label.position.y = 1.2
		State.HUNTING:
			_set_present(true)
			witnessed = false
			name_label.visible = false  # Just a dark shape in the night
			_set_dark(true)
	_update_label()


func is_alive() -> bool:
	return state != State.DEAD


func die(trace: String = "") -> void:
	body_trace = trace
	set_state(State.DEAD)

func _set_present(present: bool) -> void:
	visible = present
	collision.disabled = not present


func _update_label() -> void:
	var text: String = data.npc_name if data else String(name)
	if show_state:
		text += "\n(%s)" % State.keys()[state]
	if show_state and is_servant:
		text += " [SERVANT]"  # Debug only
	name_label.text = text

	# Can the player do something with this NPC right now?
	var can_act := highlighted and (state == State.ROUTINE \
			or (state == State.DEAD and not examined))
	name_label.modulate = HIGHLIGHT_COLOR if can_act else Color.WHITE
	prompt_icon.visible = can_act
	if can_act:
		prompt_icon.texture = ICON_EXAMINE if state == State.DEAD else ICON_TALK

func can_talk() -> bool:
	# Talk to the living, examine the dead (once)
	return state == State.ROUTINE or (state == State.DEAD and not examined)


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_update_label()


func talk(player: Node3D) -> void:
	# Dead bodies are examined, not talked to (must come BEFORE any state change)
	if state == State.DEAD:
		_examine_body()
		return

	set_state(State.TALKING)
	# Turn to face the doctor (ignore height so we don't tilt)
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	var line := "..."
	if is_servant:
		line = _servant_line()
	elif data and not data.dialogue_lines.is_empty():
		# Go through the lines in order, looping back to the start
		line = data.dialogue_lines[line_index % data.dialogue_lines.size()]
		line_index += 1
	if data:
		GameState.add_clue("%s said: \"%s\"" % [data.npc_name, line])
	EventBus.dialogue_started.emit(data.npc_name if data else String(name), line)


func _on_dialogue_ended() -> void:
	if state == State.TALKING:
		set_state(State.ROUTINE)
		
func make_servant() -> void:
	is_servant = true
	# Paler: blend the original color toward a sickly grey-white
	var material := mesh.material_override as StandardMaterial3D
	if material and data:
		material.albedo_color = data.color.lerp(Color(0.85, 0.85, 0.9), 0.5)
	_update_label()


func _servant_line() -> String:
	# Servants shift suspicion to others, but never to their master
	var suspects := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != self and npc.is_alive() and npc.data.npc_name != GameState.vampire_name:
			suspects.append(npc)
	if suspects.is_empty():
		return "..."
	var suspect: String = suspects.pick_random().data.npc_name
	var lies := [
		"Have you noticed how strange %s has been lately?",
		"I wouldn't trust %s if I were you, doctor.",
		"I saw %s wandering around late at night.",
	]
	return lies.pick_random() % suspect

# ---------- Movement ----------

func go_to(target: Vector3) -> void:
	agent.target_position = target


func _physics_process(delta: float) -> void:
	if state == State.SLEEPING or state == State.DEAD:
		return
	# Safety net: if no dialogue is open, nobody should be stuck talking
	if state == State.TALKING and not GameState.in_dialogue:
		set_state(State.ROUTINE)

	if not is_on_floor():
		velocity += get_gravity() * delta

	var current_speed := speed * (1.8 if state == State.SCARED or state == State.HUNTING else 1.0)

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
	if data and current_place == data.home and (_is_bedtime() or state == State.SCARED):
		set_state(State.SLEEPING)
	if state == State.HUNTING:
		# Back home after the hunt: go inside and sleep
		if hunt_returning and current_place == data.home:
			hunt_returning = false
			set_state(State.SLEEPING)
		return


func start_hunt(place: String) -> void:
	hunt_returning = false
	set_state(State.HUNTING)
	_go_to_place(place)


func end_hunt() -> void:
	hunt_returning = true
	_go_to_place(data.home)


func stop_hunt() -> void:
	# Dawn arrived mid-hunt: drop everything and return to daily life
	hunt_returning = false
	set_state(State.ROUTINE)


func _set_dark(dark: bool) -> void:
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		return
	if dark:
		normal_color = material.albedo_color
		material.albedo_color = Color(0.12, 0.12, 0.16)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.05, 0.05)  # A faint red glow: something is wrong
		material.emission_energy_multiplier = 0.6
	else:
		material.albedo_color = normal_color
		material.emission_enabled = false
	is_dark = dark


func _process(_delta: float) -> void:
	if state != State.HUNTING or witnessed:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) < witness_range:
		witnessed = true
		name_label.visible = true  # Close enough to recognize the face
		var clue := "Night of Day %d, %s: you saw %s sneaking through the dark streets." % [GameState.day, GameState.format_time(GameState.hour), data.npc_name]
		GameState.add_clue(clue)

# ---------- Schedule ----------

func _on_hour_changed(_hour: int) -> void:
	if wander or data == null or state == State.DEAD:
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
	# Servants avoid the open square during the day
	if is_servant and not GameState.is_night and place == "Praca":
		return data.home
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
	
	
func _examine_body() -> void:
	examined = true
	_update_label()
	var trace := body_trace if body_trace != "" else "nothing unusual"
	var text := "Bite marks on the neck. On the clothes, traces of %s." % trace
	GameState.add_clue("Body of %s: %s" % [data.npc_name, text])
	EventBus.dialogue_started.emit("Body of %s" % data.npc_name, text)


func _is_bedtime() -> bool:
	# Bedtime until sunrise: e.g. 22 means asleep from 22:00 to 06:00
	return GameState.hour >= data.bedtime or GameState.hour < 6.0
