extends CharacterBody3D

enum State { ROUTINE, TALKING, SCARED, SLEEPING, DEAD, HUNTING, INSIDE }

# Places people stay outside at (everything else has a door to go through)
const OPEN_AIR_PLACES := ["Praca", "Clinica"]  # Clinica: patients wait inside, in plain sight

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
var place_slot := -1  # Which spot this NPC took at the current place
var real_target := Vector3.ZERO  # Where we actually want to go (detours are temporary)
var detouring := false
var stuck_tries := 0

# ---------- What this person noticed at night ----------
const SIGHT_RANGE := 9.0         # How far someone on the street can see
const SIGHT_RANGE_INSIDE := 6.0  # From inside a building: just the street by the door
const RECOGNIZE_RANGE := 4.0     # In the dark, a hunter's face is only seen up close
const SIGHT_INTERVAL := 0.5      # Seconds between looks around

var sightings: Array[Dictionary] = []  # {night, kind, who, place, hour}
var wary_day := 0                      # Keeps away from the doctor on this day
var asked: Dictionary = {}             # question -> day it was last asked
var sight_timer := 0.0

# ---------- Death and burial ----------
var found_day := 0     # Day the body was found at the door
var visual: CharacterVisual = null  # The 3D model, when there is one

# ---------- Blood and anemia ----------
const ANEMIA_LEVEL := 50.0
const PALE := Color(0.92, 0.9, 0.88)
var blood := 100.0                    # 0 = dead. The vampire feeds a little each night.
var bite_traces: Array[String] = []   # What each bite left on the clothes
var bite_spots: Array[String] = []    # "neck" or "wrist" for each bite
var wrist_found := false              # Wrist bites hide under the sleeve until a careful exam
var exam_count := 0
var worried := false                  # Feels sick from fear of the outbreak, but isn't bitten
var exams: Array[Dictionary] = []     # The doctor's records, shown on the patient chart

# ---------- Trust in the doctor ----------
# Trust of 60 or more: a night visit marks them instead of turning them (see VampireDirector)
var affinity := 40.0
var talked_day := 0             # Last day a conversation raised trust
var cared_day := 0              # Last day an exam raised trust
var marked := false             # Visited by the vampire; turns next night unless saved
var marked_day := 0             # The morning they will warn the doctor
var appointment_until := -1.0   # Hour until which they wait at the clinic (-1 = none)
var appointment_from := -1.0    # Hour the visit starts
var appointment_day := 0        # Day of the visit
var treated_day := 0
var appointment: Dictionary = {}  # This patient's current entry in GameState.appointments
var skip_appointment := false     # Said yes, but will not go
var booked_day := 0               # Day the last appointment was made (one per day)
var appointment_arrival := -1.0   # When they actually turn up (some come an hour late)
var doctor_was_there := false     # The doctor was at the clinic during the visit hours

# ---------- Tonight's plan ----------
# Every evening each person may change their plans, so alibis and sightings differ night to night
var tonight: Dictionary = {}  # hour -> place, from 6 PM (empty during the day)
var tonight_bedtime := 22
var plans: Dictionary = {}    # night -> {"schedule": Dictionary, "bedtime": int, "kind": String}
var buried := false

# Spots in front of a door (the door faces +z): a small crowd instead of a pile
const PLACE_SLOTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.8),
	Vector3(-1.8, 0.0, 1.1),
	Vector3(1.8, 0.0, 1.1),
	Vector3(-0.9, 0.0, 2.7),
	Vector3(0.9, 0.0, 2.7),
	Vector3(-2.7, 0.0, 2.8),
	Vector3(2.7, 0.0, 2.8),
	Vector3(0.0, 0.0, 4.2),
]

# Inside the clinic room (around the marker): the middle of the floor, clear of the bed,
# cabinet and desk. The last two are outside the door, for a queue.
const CLINIC_SLOTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(-0.6, 0.0, 0.2),
	Vector3(0.3, 0.0, -1.0),
	Vector3(-1.0, 0.0, 0.4),
	Vector3(0.4, 0.0, -1.7),
	Vector3(0.5, 0.0, 0.5),
	Vector3(-0.6, 0.0, 2.4),
	Vector3(0.6, 0.0, 2.6),
]

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
		# A 3D body if this person has one; otherwise the colored capsule stays
		visual = CharacterVisual.new()
		add_child(visual)
		if visual.setup(data.npc_name):
			mesh.visible = false
		else:
			visual.queue_free()
			visual = null
	_update_label()
	# Wait until the navigation map actually has walkable area
	var map := agent.get_navigation_map()
	while NavigationServer3D.map_get_random_point(map, 1, true) == Vector3.ZERO:
		await get_tree().physics_frame
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.phase_changed.connect(_on_phase_changed)
	if wander:
		_pick_random_destination()
	else:
		_follow_schedule()


# ---------- State machine ----------

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	if new_state == State.INSIDE or (state == State.INSIDE and new_state == State.ROUTINE):
		Audio.play_at("door" if new_state == State.INSIDE else "door_close", global_position, -6.0)
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
			_set_present(true)  # May have come out to the door to talk
			agent.target_position = global_position  # Stop walking
		State.SCARED:
			_set_present(true)
			if data and data.home != "":
				_go_to_place(data.home)
		State.SLEEPING:
			_set_present(false)  # Went inside the house
		State.INSIDE:
			_set_present(false)  # Inside a building; the window lights up at night
			visible = highlighted  # The doctor is already at the door
			velocity = Vector3.ZERO
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
			mesh.rotation_degrees.z = 90.0  # Lying sideways, so it reads as a body from above
			if visual:
				visual.die()
			mesh.position.y = 0.5
			name_label.position.y = 1.2
		State.HUNTING:
			_set_present(true)
			witnessed = false
			name_label.visible = false  # Just a dark shape in the night
			_set_dark(true)
	_update_label()


func is_inside() -> bool:
	return state == State.INSIDE


func is_alive() -> bool:
	return state != State.DEAD


func die(trace: String = "") -> void:
	body_trace = trace
	# Killed during the night: found the next morning. Killed at dawn: found today.
	found_day = GameState.day + 1 if GameState.is_night else GameState.day
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
	var can_act := highlighted and (state == State.ROUTINE or state == State.INSIDE \
			or (state == State.DEAD and not examined))
	name_label.modulate = HIGHLIGHT_COLOR if can_act else Color.WHITE
	prompt_icon.visible = can_act
	if can_act:
		prompt_icon.texture = ICON_EXAMINE if state == State.DEAD else ICON_TALK

func can_talk() -> bool:
	# Talk to the living, examine the dead (once)
	return state == State.ROUTINE or state == State.INSIDE \
			or (state == State.DEAD and not examined and not buried)


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	if state == State.INSIDE:
		visible = value  # Comes to the door when the doctor is close
	_update_label()


func talk(player: Node3D) -> void:
	# Dead bodies are examined, not talked to (must come BEFORE any state change)
	if state == State.DEAD:
		_examine_body()
		return

	set_state(State.TALKING)
	# Turn to face the doctor (ignore height so we don't tilt)
	if visual:
		visual.face(player.global_position)
	else:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	EventBus.conversation_started.emit(self)  # The dialogue box shows the questions


func _on_dialogue_ended() -> void:
	if state == State.TALKING:
		set_state(State.ROUTINE)
		
func make_servant() -> void:
	is_servant = true
	_update_color()
	_update_label()


func _update_color() -> void:
	# Servants turn grey; blood loss makes anyone paler
	var material := mesh.material_override as StandardMaterial3D
	if material == null or data == null or is_dark:
		return
	var c := data.color
	if is_servant:
		c = c.lerp(Color(0.85, 0.85, 0.9), 0.5)
	c = c.lerp(PALE, clampf((100.0 - blood) / 100.0, 0.0, 1.0) * 0.6)
	material.albedo_color = c
	if visual:
		visual.tint((100.0 - blood) / 100.0, is_servant)


func is_anemic() -> bool:
	return blood < ANEMIA_LEVEL


func claims_sickness() -> bool:
	# Who says they are ill: the anemic, the frightened, and the vampire hiding from the sun
	return is_anemic() or worried or (is_vampire() and not GameState.is_night)


func neck_bitten() -> bool:
	return bite_spots.has("neck")


func marks_visible() -> bool:
	return neck_bitten() or (bite_spots.has("wrist") and wrist_found)


func is_vampire() -> bool:
	return data != null and data.npc_name == GameState.vampire_name


# The vampire's own blood: drops each day, refills when he feeds. Never kills him.
func set_hunger(level: float) -> void:
	blood = clampf(level, 1.0, 100.0)
	_update_color()


# A bite. Returns true if it was the last one.
func feed(amount: float, trace: String) -> bool:
	blood = maxf(blood - amount, 0.0)
	bite_traces.append(trace)
	bite_spots.append("neck" if randf() < 0.6 else "wrist")
	_update_color()
	if blood <= 0.0:
		die(trace)
		return true
	return false


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
	real_target = target
	detouring = false
	stuck_tries = 0
	agent.target_position = target


func _detour() -> void:
	# Blocked (a post, a corner, another person): step to the side, then try again
	var forward := real_target - global_position
	forward.y = 0.0
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	detouring = true
	agent.target_position = global_position + side * 1.5 - forward * 0.5


func _physics_process(delta: float) -> void:
	if state == State.SLEEPING or state == State.DEAD or state == State.INSIDE:
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
		if detouring:
			detouring = false
			agent.target_position = real_target  # Side step done: back to the real goal
		elif state != State.TALKING:
			_on_arrived()
	else:
		var direction := agent.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()
	if visual:
		visual.animate(get_real_velocity(), delta)

	# If trying to walk but barely moving for 2s, give up
	if state != State.TALKING and not agent.is_navigation_finished() and get_real_velocity().length() < 0.2:
		stuck_time += delta
		if stuck_time > 2.0:
			stuck_time = 0.0
			stuck_tries += 1
			if wander:
				_pick_random_destination()
			elif stuck_tries <= 3 and global_position.distance_to(real_target) > 2.0:
				_detour()
			else:
				detouring = false
				agent.target_position = global_position  # Close enough (or truly stuck): stop here
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
	# Reached a building during the routine: go in
	if state == State.ROUTINE and current_place != "" and not OPEN_AIR_PLACES.has(current_place):
		set_state(State.INSIDE)


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
	if visual:
		visual.set_dark(dark)
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


func _process(delta: float) -> void:
	_check_seen_by_doctor()
	sight_timer -= delta
	if sight_timer <= 0.0:
		sight_timer = SIGHT_INTERVAL
		_look_around()
		_check_appointment()


func _check_seen_by_doctor() -> void:
	if state != State.HUNTING or witnessed:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) < witness_range:
		witnessed = true
		name_label.visible = true  # Close enough to recognize the face
		var clue := "Night of Day %d, %s: you saw %s sneaking through the dark streets." % [GameState.day, GameState.format_time(GameState.hour), data.npc_name]
		GameState.add_clue(clue, "evidence")

# ---------- Schedule ----------

func _on_hour_changed(_hour: int) -> void:
	if wander or data == null or state == State.DEAD:
		return
	if state == State.SLEEPING:
		if not GameState.is_night:
			set_state(State.ROUTINE)  # Wake up and start the day
		return
	if state == State.INSIDE:
		if data.home == current_place and _is_bedtime():
			set_state(State.SLEEPING)  # Already home: lights out
		elif _place_for_hour(int(GameState.hour)) != current_place:
			set_state(State.ROUTINE)  # Time to be somewhere else: step out
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
		place_slot = _free_slot(place)
		# Each person takes their own spot, with a tiny jitter so it doesn't look like a grid
		var jitter := Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
		var slots := CLINIC_SLOTS if place == "Clinica" else PLACE_SLOTS
		if place == "Clinica":
			jitter *= 0.5  # A small room: stay on the spot
		go_to(marker.global_position + slots[place_slot] + jitter)


func _free_slot(place: String) -> int:
	# Spots already taken by other people heading to (or standing at) the same place
	var taken := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self or npc.current_place != place:
			continue
		if npc.state == State.DEAD or npc.state == State.SLEEPING:
			continue
		taken.append(npc.place_slot)
	var count := CLINIC_SLOTS.size() if place == "Clinica" else PLACE_SLOTS.size()
	for i in count:
		if not taken.has(i):
			return i
	return randi() % count  # Very crowded: share a spot


func _place_for_hour(hour: int) -> String:
	if _at_clinic_now() and not skip_appointment:
		return "Clinica"  # At the clinic from the hour they arrive
	var place := _scheduled_place(hour)
	if not tonight.is_empty() and GameState.is_night:
		place = _plan_place(tonight, hour)
	if not GameState.is_night:
		# The sick stay in bed. The vampire hides from the sun and blames the same sickness.
		if is_anemic() or ((is_vampire() or worried) and hour >= 8 and hour < 17):
			return data.home
	# Servants avoid the open square during the day
	if is_servant and not GameState.is_night and place == "Praca":
		return data.home
	return place


func _scheduled_place(hour: int) -> String:
	var hours := data.schedule.keys()
	hours.sort()
	var place: String = data.schedule[hours[-1]]  # Default: last entry (carried over from yesterday)
	for h in hours:
		if h <= hour:
			place = data.schedule[h]
	return place


# Where a plan (hour -> place) puts someone at a given hour. Hours after midnight count as 24+.
func _plan_place(plan: Dictionary, hour: int) -> String:
	var h := hour + 24 if hour < 12 else hour
	var hours := plan.keys()
	hours.sort()
	var place: String = plan[hours[0]]
	for key: int in hours:
		if key <= h:
			place = plan[key]
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
	exams.append({"day": GameState.day, "pulse": "None", "temp": "Cold", "look": "Dead",
			"sleep": "—", "vitality": 0.0, "marks": true, "old_marks": false,
			"trace": body_trace, "dead": true})
	var text := "Bite marks on the neck. On the clothes, traces of %s." % trace
	GameState.add_clue("Body of %s: %s" % [data.npc_name, text], "evidence")
	EventBus.dialogue_started.emit("Body of %s" % data.npc_name, text)


func _is_bedtime() -> bool:
	# Bedtime until sunrise: e.g. 22 means asleep from 22:00 to 06:00
	var bed := tonight_bedtime if not tonight.is_empty() else data.bedtime
	return GameState.hour >= bed or GameState.hour < 6.0


# ---------- Night memory ----------

func _look_around() -> void:
	# Only the night is worth remembering, and only while awake
	if not GameState.is_night or data == null:
		return
	if state == State.SLEEPING or state == State.DEAD or state == State.HUNTING:
		return
	var sight := SIGHT_RANGE_INSIDE if state == State.INSIDE else SIGHT_RANGE
	var night := GameState.day
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self or npc.data == null or not npc.is_alive():
			continue
		var same_room: bool = state == State.INSIDE and npc.is_inside() and npc.current_place == current_place
		var on_street: bool = npc.state == State.ROUTINE or npc.state == State.SCARED \
				or npc.state == State.TALKING or npc.state == State.HUNTING
		var distance := global_position.distance_to(npc.global_position)
		if not same_room and not (on_street and distance <= sight):
			continue
		var place: String = current_place if same_room else GameState.nearest_place(npc.global_position)
		if npc.state == State.HUNTING and distance > RECOGNIZE_RANGE:
			add_sighting(night, "figure", "", place, GameState.hour)  # Too dark to see who
		else:
			add_sighting(night, "person", npc.data.npc_name, place, GameState.hour, same_room)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and global_position.distance_to(player.global_position) <= sight:
		var place := GameState.nearest_place(player.global_position)
		if place != "Clinica":  # Nobody minds the doctor at his own door
			add_sighting(night, "doctor", "the doctor", place, GameState.hour)
			if _is_late(GameState.hour):
				if wary_day != GameState.day + 1:
					change_affinity(-12.0)
				wary_day = GameState.day + 1  # Tomorrow they keep their distance


func add_sighting(night: int, kind: String, who: String, place: String, hour: float, inside := false) -> void:
	# One entry per person per night, updated to the last time they were seen
	for s in sightings:
		if s["night"] == night and s["kind"] == kind and s["who"] == who and (kind != "figure" or s["place"] == place):
			s["place"] = place
			s["hour"] = hour
			s["inside"] = inside
			return
	sightings.append({"night": night, "kind": kind, "who": who, "place": place, "hour": hour, "inside": inside})


func _is_late(hour: float) -> bool:
	return hour >= 22.0 or hour < 6.0


func _night_order(hour: float) -> float:
	return hour + 24.0 if hour < 12.0 else hour  # 1 AM comes after 11 PM


# ---------- Conversation ----------

func is_wary() -> bool:
	return GameState.day <= wary_day or affinity < 20.0


func change_affinity(amount: float) -> void:
	affinity = clampf(affinity + amount, 0.0, 100.0)


func trust_word() -> String:
	if affinity >= 70.0:
		return "Trusts you"
	if affinity >= 45.0:
		return "Friendly"
	if affinity >= 25.0:
		return "Guarded"
	return "Distrusts you"


func was_asked(question: String) -> bool:
	return asked.get(question, 0) == GameState.day


func greeting() -> String:
	if talked_day != GameState.day:
		talked_day = GameState.day
		change_affinity(6.0)  # A daily visit builds trust
	if marked and marked_day == GameState.day:
		GameState.add_clue("Day %d · %s was visited in the night and fears it will come back tonight." % [GameState.day, data.npc_name], "evidence")
		return "Doctor... last night something stood by my bed. I couldn't move, and now my neck burns. Please, it will come back tonight."
	var night := GameState.last_night()
	for s in sightings:
		if s["night"] == night and s["kind"] == "doctor_collapsed":
			GameState.add_clue("Day %d · %s found you collapsed near %s and keeps their distance." % [GameState.day, data.npc_name, GameState.place_name(s["place"])])
			var spot := "my door" if s["place"] == data.home else GameState.place_name(s["place"])
			return "Doctor! We found you lying in the street near %s this morning. Are you ill... or is it something else?" % spot
	for s in sightings:
		if s["night"] == night and s["kind"] == "doctor" and _is_late(s["hour"]):
			GameState.add_clue("Day %d · %s saw you out near %s at %s and keeps their distance." % [GameState.day, data.npc_name, GameState.place_name(s["place"]), GameState.format_time(s["hour"])])
			return "I saw you near %s at %s last night, doctor. Decent folk are home by then." % [GameState.place_name(s["place"]), GameState.format_time(s["hour"])]
	if claims_sickness():
		var sick := ["This sickness... I can barely stand, doctor.",
				"Forgive me, doctor. The light hurts my eyes these days.",
				"I'm so tired. Is it the same thing the others have?"]
		return sick[(GameState.day + data.npc_name.length()) % sick.size()]
	if is_servant:
		return "Doctor. What is it now?"
	var hellos := ["Good day, doctor.", "Doctor. Need something?", "Ah, doctor. Any news?"]
	return hellos[(GameState.day + line_index) % hellos.size()]


func answer_alibi() -> String:
	asked["alibi"] = GameState.day
	if is_wary():
		return _wary_line()
	if GameState.day == 1:
		return "Last night? You only arrived this morning, doctor. I was home, like every night."
	var text := _alibi_text(GameState.last_night())
	GameState.add_clue("Day %d · %s, about last night: \"%s\"" % [GameState.day, data.npc_name, text])
	return text


func answer_seen() -> String:
	asked["seen"] = GameState.day
	if is_wary():
		return _wary_line()
	if GameState.day == 1:
		return "Nothing yet. Pallbrook is quiet, doctor. Mostly."
	var lines: Array[String] = []
	if is_servant:
		lines.append(_servant_sighting())  # A lie that points at someone innocent
	else:
		var night := GameState.last_night()
		var seen := sightings.filter(func(s): return s["night"] == night and s["kind"] != "doctor_collapsed")
		# Most worrying first: dark figures, then whatever happened latest
		seen.sort_custom(func(a, b): return _weight(a) > _weight(b))
		for s in seen.slice(0, 3):
			lines.append(_describe(s))
	var text := "No. I slept through the night." if lines.is_empty() else " ".join(lines)
	GameState.add_clue("Day %d · %s saw: \"%s\"" % [GameState.day, data.npc_name, text])
	return text


func answer_exam() -> String:
	asked["exam"] = GameState.day
	if is_wary():
		return "I'd rather you didn't touch me today, doctor."
	if cared_day == GameState.day and not exams.is_empty():
		return "You already examined me today, doctor. Nothing has changed since."  # Once per day
	exam_count += 1
	if bite_spots.has("wrist") and not wrist_found and (exam_count >= 2 or randf() < 0.35):
		wrist_found = true  # A closer look this time: under the sleeve
	var record := vitals()
	var text := _exam_text(record)
	GameState.add_clue("Day %d · Exam of %s: %s" % [GameState.day, data.npc_name, text], "evidence")
	if cared_day != GameState.day:
		cared_day = GameState.day
		change_affinity(8.0)
		GameState.coins += GameState.EXAM_FEE  # The patient pays for the visit
	record["day"] = GameState.day
	record["marked"] = marked
	exams.append(record)
	return text


# What an exam shows right now, in a doctor's words (never the raw number)
func vitals() -> Dictionary:
	if is_vampire():
		# His own blood is his hunger: fed, he looks healthy; starving, he looks as anemic
		# as his victims. The tells: the pulse stays slow and there are never any marks.
		var vv := {"marks": false, "old_marks": false, "trace": "", "vitality": blood / 100.0, "dead": false}
		if blood >= 80.0:
			vv.merge({"pulse": ["56, slow", "60, slow", "64, steady"].pick_random(), "temp": ["Cool", "Normal"].pick_random(),
					"look": ["Good color", "A little pale"].pick_random()})
		elif blood >= ANEMIA_LEVEL:
			vv.merge({"pulse": ["56, slow", "60, slow"].pick_random(), "temp": ["Cool", "Normal"].pick_random(),
					"look": "A little pale"})
		elif blood >= 25.0:
			vv.merge({"pulse": ["52, slow", "56, slow"].pick_random(), "temp": "Cool", "look": "Pale"})
		else:
			vv.merge({"pulse": "48, slow", "temp": "Cold", "look": "Grey"})
		# Sleeps like anyone else, by his own account
		vv["sleep"] = ["Sound", "Light", "Restless", "Oversleeps"].pick_random()
		return vv
	var trace := ""
	if marks_visible():
		trace = bite_traces[-1] + ("" if neck_bitten() else " (wrist)")
	var v := {"marks": neck_bitten(), "old_marks": is_servant, "trace": trace,
			"vitality": blood / 100.0, "dead": false}
	if worried and blood >= 80.0:
		# Frightened, not bitten: looks much like the vampire on a single exam
		v.merge({"pulse": ["60, slow", "64, steady", "68, steady", "72, steady"].pick_random(),
				"temp": ["Cool", "Normal"].pick_random(),
				"look": ["Good color", "A little pale"].pick_random()})
	elif blood >= 80.0:
		# Healthy people vary too, so a single slow or cool reading proves nothing
		v.merge({"pulse": ["64, steady", "68, steady", "72, steady", "76, steady"].pick_random(),
				"temp": "Cool" if randf() < 0.25 else "Normal", "look": "Good color"})
	elif blood >= ANEMIA_LEVEL:
		v.merge({"pulse": "88, quick", "temp": "Normal", "look": "A little pale"})
	elif blood >= 25.0:
		v.merge({"pulse": "104, weak", "temp": "Cool", "look": "Pale"})
	else:
		v.merge({"pulse": "120, faint", "temp": "Cool", "look": "Grey"})
	v["sleep"] = _sleep()
	return v


# How they have been sleeping. Anyone bitten may dream badly; the marked are haunted.
func _sleep() -> String:
	if marked:
		return ["Night terrors", "Hallucinations", "Sleepwalks"].pick_random()
	if is_servant:
		return "Dreamless"
	if blood < 25.0:
		return "Nightmares" if randf() < 0.35 else ["Oversleeps", "Wakes dizzy", "Can't get up"].pick_random()
	if blood < 80.0:
		return "Nightmares" if randf() < 0.25 else ["Restless", "Oversleeps", "Wakes tired"].pick_random()
	if worried:
		return ["Light", "Restless", "Nightmares"].pick_random()  # Frightened by the outbreak
	return "Restless" if randf() < 0.2 else "Sound"


func _exam_text(v: Dictionary) -> String:
	var parts: Array[String] = ["Pulse %s." % v["pulse"]]
	if blood >= 80.0 and (is_vampire() or worried):
		parts.append("Complains of weakness, but the blood seems fine.")
	elif blood >= 80.0:
		parts.append("Good color.")
	elif blood >= ANEMIA_LEVEL:
		parts.append("A little pale. Mild anemia.")
	elif blood >= 25.0:
		parts.append("Pale and weak. Clear anemia.")
	else:
		parts.append("Grey lips, can barely stand. Severe anemia: one more night like this could kill.")
	if v["temp"] == "Cool" and blood >= ANEMIA_LEVEL:
		parts.append("Hands a little cool, but it is autumn.")
	if neck_bitten():
		parts.append("Two small punctures on the neck. On the collar, traces of %s." % bite_traces[-1])
	elif bite_spots.has("wrist") and wrist_found:
		parts.append("No marks on the neck, but two small punctures inside the wrist. On the cuff, traces of %s." % bite_traces[-1])
	elif not is_servant:
		parts.append("No marks on the neck.")
	if is_servant:
		parts.append("The punctures are old and healed, and the eyes flinch from the window.")
	match str(v.get("sleep", "")):
		"Night terrors":
			parts.append("Wakes screaming: dreams of something leaning over the bed.")
		"Hallucinations":
			parts.append("Swears a figure stands at the foot of the bed each night.")
		"Sleepwalks":
			parts.append("Was found at the door at night, with no memory of it.")
		"Nightmares":
			parts.append("Sleeps badly, with nightmares.")
	return " ".join(parts)


func answer_chat() -> String:
	asked["chat"] = GameState.day
	if is_wary():
		return "I'd rather not chat today, doctor."
	var line := "..."
	if is_servant:
		line = _servant_line()
	elif not data.dialogue_lines.is_empty():
		# Go through the lines in order, looping back to the start
		line = data.dialogue_lines[line_index % data.dialogue_lines.size()]
		line_index += 1
	GameState.add_clue("%s said: \"%s\"" % [data.npc_name, line])
	return line


func _wary_line() -> String:
	return "I have nothing to tell you today, doctor."


func _alibi_text(night: int) -> String:
	# What they really did that evening. The vampire tells this too: a lie by omission.
	if data.schedule.is_empty():
		return "At home, asleep."
	var plan: Dictionary = data.schedule
	var bed := data.bedtime
	var last_place := _scheduled_place(18)
	if plans.has(night):
		plan = plans[night]["schedule"]
		bed = plans[night]["bedtime"]
		last_place = plan.get(18, last_place)
	var text := "From 6 PM I was %s" % _where(last_place)
	var hours := plan.keys()
	hours.sort()
	for h: int in hours:
		if h > 18 and h < bed and plan[h] != last_place:
			last_place = plan[h]
			text += ", then %s from %s" % [_where(last_place), GameState.format_time(h)]
	if last_place != data.home:
		text += ", then I went home"
	return text + ". I went to bed around %s." % GameState.format_time(bed)


func _where(place: String) -> String:
	if place == data.home and place.begins_with("Casa"):
		return "at home"
	if place == "Praca":
		return "in the square"
	return "at " + GameState.place_name(place)


func _weight(s: Dictionary) -> float:
	return _night_order(s["hour"]) + (100.0 if s["kind"] == "figure" else 0.0)


func _describe(s: Dictionary) -> String:
	var time := GameState.format_time(s["hour"])
	var where := GameState.place_name(s["place"])
	match s["kind"]:
		"figure":
			return "Around %s I saw a dark figure near %s. I couldn't make out a face." % [time, where]
		"doctor":
			return "And you, doctor, were near %s around %s." % [where, time]
	if s.get("inside", false):
		return "%s was with me at %s until about %s." % [s["who"], where, time]
	if _is_late(s["hour"]):
		return "I saw %s out near %s around %s. At that hour!" % [s["who"], where, time]
	return "I saw %s passing near %s around %s." % [s["who"], where, time]


func _servant_sighting() -> String:
	var innocents := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != self and npc.is_alive() and npc.data.npc_name != GameState.vampire_name:
			innocents.append(npc)
	if innocents.is_empty():
		return "Nothing. Nothing at all."
	var target = innocents.pick_random()
	var place: String = GameState.PLACE_NAMES.keys().pick_random()
	var time := GameState.format_time(snappedf(randf_range(22.5, 24.5), 1.0 / 6.0))
	return "I saw %s sneaking near %s around %s. Ask them where they were." % [target.data.npc_name, GameState.place_name(place), time]


# ---------- Burial ----------

func _on_phase_changed(is_night: bool) -> void:
	# The body stays at the door for the day it is found; at dusk it is buried
	if is_night and state == State.DEAD and not buried and GameState.day >= found_day:
		_bury()
	if is_night and is_alive() and data and not data.schedule.is_empty():
		_plan_evening()
	elif not is_night:
		tonight = {}


func _plan_evening() -> void:
	# Start from the usual evening, then maybe change it
	var plan := {}
	for h: int in data.schedule.keys():
		if h > 18:
			plan[h] = data.schedule[h]
	plan[18] = _scheduled_place(18)
	var bed := data.bedtime
	var kind := "usual"
	var friends := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != self and npc.is_alive() and npc.data and npc.data.home != data.home:
			friends.append(npc)
	var roll := randf()
	if is_anemic():
		# Too weak to go out
		kind = "sick"
		plan = {18: data.home}
		bed = maxi(data.bedtime - 1, 20)
	elif roll < 0.2:
		# A long night at the tavern
		kind = "tavern"
		plan = {18: plan[18], 19: "Taverna"}
		bed = mini(data.bedtime + 1, 23)
	elif roll < 0.4 and not friends.is_empty():
		# Visiting a friend after dinner
		kind = "visit"
		var friend = friends.pick_random()
		for h: int in plan.keys():
			if h >= 19 and h <= 21:
				plan.erase(h)
		plan[19] = friend.data.home
		plan[21] = data.home
	elif roll < 0.55:
		# Tired: home early
		kind = "early"
		plan = {18: data.home}
		bed = maxi(data.bedtime - 1, 20)
	elif roll < 0.7:
		# A walk through the square before bed
		kind = "walk"
		plan[20] = "Praca"
		if not plan.has(21):
			plan[21] = data.home
	# Whatever happened, they must end the night at home to go to sleep
	var keys := plan.keys()
	keys.sort()
	if plan[keys[-1]] != data.home:
		plan[bed] = data.home
	tonight = plan
	tonight_bedtime = bed
	plans[GameState.day] = {"schedule": plan.duplicate(), "bedtime": bed, "kind": kind}


func _bury() -> void:
	buried = true
	visible = false
	collision.disabled = true
	var slot := _free_grave_slot()
	if slot:
		slot.add_child(_make_headstone())
	GameState.add_night_event("%s was buried in the cemetery beyond the bridge." % data.npc_name)
	if not examined:
		GameState.add_clue("Day %d · %s was buried before you examined the body." % [GameState.day, data.npc_name], "evidence")


func _free_grave_slot() -> Node3D:
	# Empty slots come from the town model (empties named GraveSlot...)
	for slot in get_tree().root.find_children("GraveSlot*", "", true, false):
		if slot is Node3D and slot.get_child_count() == 0:
			return slot
	push_warning("No free grave slot in the cemetery")
	return null


func _make_headstone() -> Node3D:
	var stone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.9, 0.18)
	stone.mesh = box
	stone.position.y = 0.45
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.58)
	stone.material_override = material
	var plate := Label3D.new()
	plate.text = "%s\n%s" % [data.npc_name, data.role]
	plate.font_size = 48
	plate.outline_size = 12
	plate.pixel_size = 0.006
	plate.position = Vector3(0.0, 0.15, 0.1)  # On the face of the stone, toward the camera
	plate.modulate = Color(0.9, 0.88, 0.82)
	stone.add_child(plate)
	return stone


# ---------- Clinic visits ----------

func answer_clinic() -> String:
	asked["clinic"] = GameState.day
	if GameState.is_night:
		return "At this hour? Ask me tomorrow, doctor."
	if is_wary():
		return "I'll manage on my own, thank you."
	if appointment_until >= 0.0:
		return "I'll be at the clinic at %s, doctor, as we agreed." % GameState.format_time(appointment_from)
	if treated_day == GameState.day:
		return "You already treated me today, doctor. Let the tonic do its work."  # Once per day
	if booked_day == GameState.day:
		return "I couldn't make it today, doctor. Ask me again tomorrow."  # One booking per day
	if blood >= 80.0 and not marked and not is_vampire() and not worried:
		return "Me? I feel fine, doctor. Save your medicine for the sick."
	if not is_vampire() and affinity < 45.0 and randf() < 0.35:
		return "Tonics and bloodletting... no, doctor. I don't trust medicine."  # Some refuse out of pride or fear
	# The vampire says yes and never comes (the sun). Weak patients sometimes can't make it either.
	booked_day = GameState.day
	skip_appointment = is_vampire() or randf() < 0.25
	# A visit one or two hours from now, lasting two hours; too late today means tomorrow morning
	appointment_day = GameState.day
	appointment_from = floorf(GameState.hour) + float(randi_range(1, 2))
	if appointment_from + 1.0 > 18.0:
		appointment_day = GameState.day + 1
		appointment_from = float(randi_range(8, 10))
	appointment_until = minf(appointment_from + 2.0, 18.0)  # Home before dark
	# Some patients are late and only turn up in the second hour
	appointment_arrival = appointment_from
	if appointment_from + 1.0 < appointment_until and randf() < 0.3:
		appointment_arrival = appointment_from + 1.0
	doctor_was_there = false
	appointment = {"day": appointment_day, "name": data.npc_name, "from": appointment_from,
			"until": appointment_until, "status": "waiting"}
	GameState.appointments.append(appointment)
	var when := GameState.format_time(appointment_from)
	if appointment_day != GameState.day:
		when = "tomorrow at " + when
	return "Yes... I'll come to the clinic %s. Please be there, doctor." % ("at " + when if appointment_day == GameState.day else when)


func _check_appointment() -> void:
	if appointment_until < 0.0 or not is_alive():
		return
	var over := GameState.day > appointment_day \
			or (GameState.day == appointment_day and GameState.hour >= appointment_until)
	if over:
		# Waited long enough
		appointment_until = -1.0
		if treated_day != appointment_day:
			if skip_appointment and doctor_was_there:
				# The doctor waited and they never came
				appointment["status"] = "absent"
				GameState.add_clue("Day %d · %s never showed up at the clinic." % [GameState.day, data.npc_name])
			else:
				# The doctor was not there in time (whether they came or not, he can't tell)
				appointment["status"] = "missed"
				GameState.add_clue("Day %d · You missed %s's appointment at the clinic." % [GameState.day, data.npc_name])
				if not skip_appointment:
					change_affinity(-5.0)  # They went and waited for nothing
		skip_appointment = false
		if state == State.INSIDE:
			set_state(State.ROUTINE)
		return
	if not _in_appointment():
		return  # Not time yet
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# Only waiting into the last hour proves they never came (they might just be late)
	if player and GameState.hour >= appointment_until - 1.0 \
			and player.global_position.distance_to(GameState.place_position("Clinica")) < 6.0:
		doctor_was_there = true
	if not _at_clinic_now():
		return  # Late: still on their way
	if current_place == "Clinica" and (state == State.INSIDE or state == State.ROUTINE) and player \
			and player.global_position.distance_to(GameState.place_position("Clinica")) < 6.0 \
			and global_position.distance_to(GameState.place_position("Clinica")) < 6.0:
		if GameState.tonics > 0:
			_treat()
		else:
			_no_tonic()


func _at_clinic_now() -> bool:
	return _in_appointment() and GameState.hour >= appointment_arrival


func _in_appointment() -> bool:
	return appointment_until >= 0.0 and GameState.day == appointment_day \
			and GameState.hour >= appointment_from and GameState.hour < appointment_until


func _no_tonic() -> void:
	# They came, but the cabinet is empty
	appointment_until = -1.0
	appointment["status"] = "no tonic"
	change_affinity(-3.0)
	GameState.add_clue("Day %d · %s came to the clinic, but you had no tonic left." % [GameState.day, data.npc_name])
	if state == State.INSIDE:
		set_state(State.ROUTINE)
	if not GameState.in_dialogue:
		EventBus.dialogue_started.emit(data.npc_name, "No tonic, doctor? Then why did you call me here...")


func _treat() -> void:
	GameState.tonics -= 1
	var was_marked := marked
	treated_day = GameState.day
	worried = false  # Reassured by the doctor: back to their normal day
	appointment_until = -1.0
	appointment["status"] = "treated"
	marked = false
	blood = minf(blood + 25.0, 100.0)
	change_affinity(15.0)
	_update_color()
	# The doctor checks them again after the tonic: the chart shows the new state
	var record := vitals()
	record["day"] = GameState.day
	record["treated"] = true
	record["marked"] = false
	exams.append(record)
	var note := "Day %d · You treated %s at the clinic: an iron tonic and rest." % [GameState.day, data.npc_name]
	if was_marked:
		note += " The night visitor's hold on them is broken."
	GameState.add_clue(note, "evidence")
	if state == State.INSIDE:
		set_state(State.ROUTINE)  # Back to their day
	if not GameState.in_dialogue:
		EventBus.dialogue_started.emit(data.npc_name, "Thank you, doctor. I feel stronger already.")
