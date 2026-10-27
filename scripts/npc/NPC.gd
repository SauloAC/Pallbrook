extends CharacterBody3D

enum State { ROUTINE, TALKING, SCARED, SLEEPING, DEAD, HUNTING, INSIDE }

# Places people stay outside at (everything else has a door to go through)
const OPEN_AIR_PLACES := ["Praca"]
# Walk-in buildings: people stay visible inside (the roof opens when the doctor enters)
const WALK_IN_PLACES := ["Clinica", "Taverna", "Biblioteca", "Prefeitura", "Escola", "Igreja", "Casa2",
		"Casa1", "CasaSophia", "CasaSarah", "CasaHugo"]

@export var data: NPCData
@export var speed := 2.5
@export var wander := false      # Debug: walk to random places instead of the schedule
@export var show_state := false   # Debug: show the current state above the name
@export var witness_range := 5.0  # How close the doctor must be to recognize a hunting vampire

var hunt_returning := false
var hurrying := false  # Caught outside at sunrise: rushing home
var witnessed := false        # The doctor got close enough to see its face (as the vampire)
var noticed_doctor := false   # It saw the doctor watching (as the vampire)
var chasing := false          # Running after the doctor (as the vampire)
const NOTICE_RANGE := 11.0    # How far a hunting vampire notices a doctor in the open
const CHASE_SPEED := 1.8      # Times the walking speed while chasing: 4.5, the doctor walks at 5
                              # (rested he slowly pulls away; tired after midnight, it catches him)
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
var hid_night := -1                    # Last night this person caught the doctor lurking

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

# ---------- Autumn chill (flu) ----------
# A common cold that has nothing to do with the vampire: fever, a strong quick pulse,
# flushed cheeks, a cough. The tonic does nothing for it; rest and good food do.
# The vampire won't touch someone with fever in their blood.
const FLU_DAYS := 4            # Days to get over it alone (half with rest)
const FLU_MAX_SICK := 2        # Never more than this many at once
var flu_days := 0              # Days left (0 = not sick)
var flu_rest := false          # The doctor prescribed rest
var rest_day := 0              # Last day rest was prescribed
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
var visit_day := 0                # Day of the last appointment itself (one visit per day)
var waiting_announced := false    # Told the doctor they've arrived for this appointment
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

# Spots inside walk-in buildings, around their marker: open floor, clear of the furniture.
# Clinic: the last two are outside the door, for a queue.
const INTERIOR_SLOTS := {
	# Homes (marker at the front door): spots off to the side, so the doctor can step in
	"Casa1": [Vector3(0.6, 0.0, -2.2), Vector3(-0.4, 0.0, -1.9), Vector3(0.2, 0.0, -2.9)],
	"CasaSophia": [Vector3(-1.2, 0.0, -2.0), Vector3(-1.8, 0.0, -2.4), Vector3(-0.6, 0.0, -1.7)],
	"CasaSarah": [Vector3(0.0, 0.0, -3.6), Vector3(0.4, 0.0, -2.1), Vector3(-0.1, 0.0, -1.2)],
	"CasaHugo": [Vector3(2.0, 0.0, -2.2), Vector3(-2.1, 0.0, -2.3), Vector3(1.2, 0.0, -1.9)],
	# Tomas's forge (marker at the house door): beside the anvil, at the hearth, in front of the anvil
	"Casa2": [
		Vector3(4.1, 0.0, -1.9), Vector3(4.25, 0.0, -2.3), Vector3(2.6, 0.0, -0.6), Vector3(3.4, 0.0, -0.6),
	],
	"Clinica": [
		Vector3(0.0, 0.0, 0.0), Vector3(-0.6, 0.0, 0.2), Vector3(0.3, 0.0, -1.0), Vector3(-1.0, 0.0, 0.4),
		Vector3(0.4, 0.0, -1.7), Vector3(0.5, 0.0, 0.5), Vector3(-0.6, 0.0, 2.4), Vector3(0.6, 0.0, 2.6),
	],
	# Tavern (marker at the south door): four inside by the bar and the table, four out on the patio
	"Taverna": [
		Vector3(0.5, 0.0, -5.0), Vector3(-0.5, 0.0, -5.0), Vector3(0.0, 0.0, -2.0), Vector3(1.2, 0.0, -7.2),
		Vector3(0.0, 0.0, 1.4), Vector3(-0.6, 0.0, 3.1), Vector3(0.6, 0.0, 3.1), Vector3(2.4, 0.0, 0.9),
	],
	# Town hall (marker at the tower door): around the round rug, clear of the council desks
	"Prefeitura": [
		Vector3(1.0, 0.0, -2.0), Vector3(0.2, 0.0, -2.5), Vector3(1.8, 0.0, -2.5), Vector3(1.0, 0.0, -3.2),
		Vector3(0.0, 0.0, -3.4), Vector3(2.0, 0.0, -3.4), Vector3(0.6, 0.0, -4.0), Vector3(1.4, 0.0, -4.0),
	],
	# School (marker at the south door): the teacher's spot first, then the aisle and the front row
	"Escola": [
		Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, -3.8), Vector3(0.0, 0.0, -2.6), Vector3(-1.6, 0.0, -1.2),
		Vector3(1.6, 0.0, -1.2), Vector3(-0.5, 0.0, -4.2), Vector3(0.5, 0.0, -3.2), Vector3(-0.4, 0.0, -2.0),
	],
	# Church (marker at the tower door): the priest at the altar, the rest along the aisle
	"Igreja": [
		Vector3(0.0, 0.0, -6.9), Vector3(-0.9, 0.0, -6.6), Vector3(0.9, 0.0, -6.6), Vector3(-0.4, 0.0, -6.2),
		Vector3(0.4, 0.0, -6.2), Vector3(0.0, 0.0, -5.2), Vector3(0.0, 0.0, -4.3), Vector3(0.0, 0.0, -3.4),
	],
	# Library (marker at the south door): around the reading table, by the shelves and the desks
	"Biblioteca": [
		Vector3(-1.8, 0.0, -3.2), Vector3(1.8, 0.0, -3.2), Vector3(0.0, 0.0, -1.7), Vector3(-1.3, 0.0, -4.6),
		Vector3(1.3, 0.0, -4.6), Vector3(-0.9, 0.0, -1.1), Vector3(0.9, 0.0, -1.1), Vector3(0.0, 0.0, -0.6),
	],
}

# Where each person sleeps: the foot of their bed (from the home's door marker) and which
# way the head points (degrees around Y; 0 = head toward -z). Homes without a bed here
# (the tavern rooms upstairs, the priest's quarters) still send their owner out of sight.
const BED_SPOTS := {
	"Casa1": [Vector3(2.15, 0.0, -2.75), 0.0],
	"Casa2": [Vector3(-1.9, 0.0, -2.7), 0.0],
	"CasaSophia": [Vector3(-1.0, 0.0, -3.7), 90.0],
	"CasaSarah": [Vector3(2.55, 0.0, -3.8), 90.0],
	"CasaHugo": [Vector3(2.7, 0.0, -3.8), 90.0],
	"Taverna": [Vector3(1.45, 3.12, -6.85), -90.0],  # Marta sleeps upstairs, by the window (feet at the foot of the bed, head to the wall)
}
const BED_HEIGHT := 0.6
# Upstairs beds: where to walk to first (on the upper floor, beside the bed), relative to the door.
# The bed itself has no navigation mesh, and its nearest mesh point can be outside the house.
const BED_APPROACH := {
	"Taverna": Vector3(0.6, 3.12, -6.6),
}
var in_bed := false

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
	if in_bed:
		_get_up()
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
			if data and BED_SPOTS.has(data.home) and current_place == data.home:
				_lie_down()  # In bed, visible through the open roof
			else:
				_set_present(false)  # Went inside, out of sight
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
			noticed_doctor = false
			name_label.visible = false  # Just a dark shape in the night
			_set_dark(true)
	_update_label()


func _lie_down() -> void:
	var marker := _find_location(data.home)
	if marker == null:
		_set_present(false)
		return
	var bed: Array = BED_SPOTS[data.home]
	in_bed = true
	visible = true
	collision.disabled = true  # Doesn't block the doctor walking around the bed
	velocity = Vector3.ZERO
	agent.target_position = global_position
	global_position = marker.global_position + bed[0]
	reset_physics_interpolation()
	if bed_upstairs() and GameState.open_building == data.home and not GameState.open_upstairs:
		visible = false  # The upper floor is cut away while the doctor is downstairs
	if visual:
		visual.rotation = Vector3(-PI / 2.0, deg_to_rad(bed[1]), 0.0)
		visual.position.y = BED_HEIGHT
	else:
		mesh.rotation = Vector3(-PI / 2.0, deg_to_rad(bed[1]), 0.0)
		mesh.position.y = BED_HEIGHT


# A bed on the upper floor: hidden with that floor when the doctor walks in downstairs
func bed_upstairs() -> bool:
	return data != null and BED_SPOTS.has(data.home) and BED_SPOTS[data.home][0].y > 1.0


func _get_up() -> void:
	in_bed = false
	collision.disabled = false
	if visual:
		visual.rotation = Vector3.ZERO
		visual.position.y = 0.0
	else:
		mesh.rotation = Vector3.ZERO
		mesh.position.y = 1.0
	# Step off the bed onto the floor beside it
	var marker := _find_location(current_place)
	if marker and INTERIOR_SLOTS.has(current_place):
		global_position = _reachable_spot(marker.global_position, marker.global_position + INTERIOR_SLOTS[current_place][0])
		reset_physics_interpolation()


func is_inside() -> bool:
	# Also true for someone standing inside a walk-in building (window lights, sight)
	return state == State.INSIDE or (state == State.ROUTINE and WALK_IN_PLACES.has(current_place) \
			and agent.is_navigation_finished())


func is_alive() -> bool:
	return state != State.DEAD and not jailed


var jailed := false  # Condemned at a hearing: shut outside the town gate

func jail() -> void:
	jailed = true
	marked = false
	_set_present(false)
	set_process(false)
	set_physics_process(false)


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
	if jailed:
		return false
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
	# Who says they are ill: the anemic, the frightened, the feverish, and the vampire hiding from the sun
	return is_anemic() or worried or has_flu() or (is_vampire() and not GameState.is_night and not walks_by_day())


# A well-fed vampire can go out under clouds or fog, but by day it is only a person: no powers,
# no hunting. Hungry or weak, it hasn't the strength and stays in bed.
const VAMPIRE_DAY_FED := 70.0

func walks_by_day() -> bool:
	return is_vampire() and GameState.weather != "clear" and blood >= VAMPIRE_DAY_FED


func has_flu() -> bool:
	return flu_days > 0


func catch_flu() -> void:
	if is_vampire() or not is_alive() or has_flu():
		return
	flu_days = FLU_DAYS
	flu_rest = false
	Playtest.count("flu_cases")


# Each morning: the sick get better (faster with rest), and the chill may spread
func _flu_morning() -> void:
	if has_flu():
		flu_days -= 2 if flu_rest else 1
		if flu_days <= 0:
			flu_days = 0
			flu_rest = false
		return
	if is_vampire() or not is_alive():
		return
	var sick := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != self and npc.is_alive() and npc.has_flu():
			sick += 1
	if sick >= FLU_MAX_SICK:
		return
	if randf() < 0.04 + 0.08 * sick:  # Rare on its own, more likely when someone is coughing in town
		catch_flu()


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
		"Have you noticed how strange {name} has been lately?",
		"I wouldn't trust {name} if I were you, doctor.",
		"I saw {name} wandering around late at night.",
	]
	return _t(lies.pick_random(), {"name": _n(suspect)})

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

	var current_speed := speed * (1.8 if state == State.SCARED or state == State.HUNTING or hurrying else 1.0)
	if chasing:
		current_speed = speed * CHASE_SPEED

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
	hurrying = false
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
	if state == State.ROUTINE and current_place != "" and not OPEN_AIR_PLACES.has(current_place) \
			and not WALK_IN_PLACES.has(current_place):
		set_state(State.INSIDE)


func start_hunt(place: String) -> void:
	hunt_returning = false
	set_state(State.HUNTING)
	_go_to_place(place)


func end_hunt() -> void:
	chasing = false
	hunt_returning = true
	_go_to_place(data.home)


# Sunrise caught it outside and nobody is watching: it made it home in the dark hours the doctor
# didn't see (or slept through). Put it there at once.
func snap_home() -> void:
	chasing = false
	hunt_returning = false
	hurrying = false
	var marker := _find_location(data.home)
	if marker == null:
		return
	var spot := marker.global_position
	if INTERIOR_SLOTS.has(data.home):
		spot = _reachable_spot(marker.global_position, marker.global_position + INTERIOR_SLOTS[data.home][0])
	global_position = spot
	reset_physics_interpolation()
	go_to(spot)
	current_place = data.home
	if WALK_IN_PLACES.has(data.home):
		if state == State.ROUTINE:
			_follow_schedule()
		else:
			set_state(State.ROUTINE)
	else:
		set_state(State.INSIDE)


# Sunrise caught it outside in front of the doctor: it hurries home, head down
func hurry_home() -> void:
	chasing = false
	hunt_returning = false
	if state == State.ROUTINE:
		_follow_schedule()
	else:
		set_state(State.ROUTINE)
	_go_to_place(data.home)
	hurrying = true


# Hours passed in a moment (the doctor read or brewed): be wherever the day has taken them by now
func catch_up() -> void:
	if state != State.ROUTINE or wander or data == null or chasing:
		return
	_follow_schedule()
	var spot := agent.target_position
	if spot.distance_to(global_position) > 0.5:
		global_position = spot
		reset_physics_interpolation()


func at_home() -> bool:
	if current_place != data.home:
		return false
	if state == State.INSIDE or state == State.SLEEPING:
		return true
	return global_position.distance_to(GameState.place_position(data.home)) < 6.0


func stop_hunt() -> void:
	# Dawn arrived mid-hunt: drop everything and return to daily life
	chasing = false
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


# Two separate things while hunting: the doctor seeing its face (close, a clear line, even from
# inside a bush), and the vampire noticing the doctor (further away, but not if he is hidden).
func _check_seen_by_doctor() -> void:
	if state != State.HUNTING:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if not noticed_doctor and distance < NOTICE_RANGE and sees(player):
		noticed_doctor = true
	if witnessed:
		return
	if distance < witness_range and sees(player, true):
		witnessed = true
		name_label.visible = true  # Close enough to recognize the face
		var clue := _t("Night of Day {day}, {time}: you saw {name} sneaking through the dark streets.",
				{"day": GameState.day, "time": GameState.format_time(GameState.hour), "name": _n(data.npc_name)})
		GameState.add_clue(clue, "evidence")
		var nights: Array = GameState.saw_hunting.get(data.npc_name, [])
		if not nights.has(GameState.day):
			nights.append(GameState.day)
		GameState.saw_hunting[data.npc_name] = nights

# ---------- Schedule ----------

func _on_hour_changed(_hour: int) -> void:
	if wander or data == null or state == State.DEAD or jailed:
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
		var slots: Array = INTERIOR_SLOTS.get(place, PLACE_SLOTS)
		if INTERIOR_SLOTS.has(place):
			jitter *= 0.5  # Indoors: stay on the spot
		var spot: Vector3 = marker.global_position + slots[place_slot] + jitter
		if data and place == data.home and BED_SPOTS.has(place) \
				and (_is_bedtime() or state == State.SCARED or hunt_returning):
			spot = marker.global_position + BED_SPOTS[place][0]  # Off to bed (stops beside it)
			if BED_APPROACH.has(place):
				spot = _upstairs_spot(marker, place)
		elif INTERIOR_SLOTS.has(place):
			spot = _reachable_spot(marker.global_position, spot)
		go_to(spot)


# Indoor spots sit among furniture. If one is off the navigation mesh, or on a patch the
# streets can't reach, the agent heads for the nearest mesh point instead, which can be
# outside behind a wall (that's how people ended up stuck behind the church).
# So slide the spot back toward the door until it can be reached from the square.
func _reachable_spot(door: Vector3, spot: Vector3) -> Vector3:
	var map := agent.get_navigation_map()
	var hub := _find_location("Praca")
	if hub == null or NavigationServer3D.map_get_iteration_id(map) == 0:
		return spot
	for i in 11:
		var p := spot.lerp(door, i / 10.0)
		var path := NavigationServer3D.map_get_path(map, hub.global_position, p, true)
		if path.is_empty():
			continue
		var end := path[path.size() - 1]
		if Vector2(end.x - p.x, end.z - p.z).length() < 0.35:
			return end
	return door


# Up the stairs to the side of the bed. If the upper floor can't be reached (navigation mesh
# not baked up there), wait inside on the ground floor instead of walking round the outside.
func _upstairs_spot(marker: Node3D, place: String) -> Vector3:
	var target: Vector3 = marker.global_position + BED_APPROACH[place]
	var map := agent.get_navigation_map()
	var hub := _find_location("Praca")
	if hub and NavigationServer3D.map_get_iteration_id(map) != 0:
		var path := NavigationServer3D.map_get_path(map, hub.global_position, target, true)
		if not path.is_empty():
			var end := path[path.size() - 1]
			if Vector2(end.x - target.x, end.z - target.z).length() < 0.5 and absf(end.y - target.y) < 0.6:
				return end
	var slots: Array = INTERIOR_SLOTS.get(place, [Vector3.ZERO])
	return _reachable_spot(marker.global_position, marker.global_position + slots[0])


func _free_slot(place: String) -> int:
	# Spots already taken by other people heading to (or standing at) the same place
	var taken := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self or npc.current_place != place:
			continue
		if npc.state == State.DEAD or npc.state == State.SLEEPING:
			continue
		taken.append(npc.place_slot)
	var count: int = INTERIOR_SLOTS[place].size() if INTERIOR_SLOTS.has(place) else PLACE_SLOTS.size()
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
		# (The vampire all day long: the sun is up from dawn to dusk, not only from eight to five)
		if is_anemic() or (is_vampire() and not walks_by_day()) or (worried and hour >= 8 and hour < 17):
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
	var trace := tr(body_trace) if body_trace != "" else tr("nothing unusual")
	exams.append({"day": GameState.day, "pulse": "None", "temp": "Cold", "look": "Dead",
			"sleep": "—", "vitality": 0.0, "marks": true, "old_marks": false,
			"trace": body_trace, "dead": true})
	var text := _t("Bite marks on the neck. On the clothes, traces of {trace}.", {"trace": trace})
	GameState.add_clue(_t("Body of {name}: {text}", {"name": _n(data.npc_name), "text": text}), "evidence")
	EventBus.dialogue_started.emit(_t("Body of {name}", {"name": _n(data.npc_name)}), text)


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
			# Where they were heading (their routine), so someone just walking past isn't
			# taken for a liar later. A hunter's errand is no routine, so it isn't kept.
			var heading: String = npc.current_place if npc.state != State.HUNTING else ""
			add_sighting(night, "person", npc.data.npc_name, place, GameState.hour, same_room, heading)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	# Behind a tree or a wall, the doctor isn't seen at all
	if player and global_position.distance_to(player.global_position) <= sight and sees(player):
		var place := GameState.nearest_place(player.global_position)
		if place != "Clinica":  # Nobody minds the doctor at his own door
			var hiding: bool = _is_late(GameState.hour) and player.has_method("is_lurking") \
					and (player.is_lurking() or player.just_left_cover())
			add_sighting(night, "doctor_hiding" if hiding else "doctor", "the doctor", place, GameState.hour)
			if _is_late(GameState.hour):
				if wary_day != GameState.day + 1:
					change_affinity(-12.0)
				wary_day = GameState.day + 1  # Tomorrow they keep their distance
			if hiding and hid_night != night:
				hid_night = night
				Playtest.count("caught_lurking")
				Playtest.log_line("%s caught the doctor lurking near %s" % [data.npc_name, place])
				change_affinity(-8.0)  # Lurking in the dark is worse than walking by


# Line of sight from this person's eyes to someone: walls, trees and props block it
func sees(target: Node3D, ignore_hiding := false) -> bool:
	if not ignore_hiding and target.has_method("is_hidden") and target.is_hidden():
		return false  # Inside a bush or tall grass
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.5, 0.0),
			target.global_position + Vector3(0.0, 0.5, 0.0))
	var skip: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		skip.append((target as CollisionObject3D).get_rid())
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func add_sighting(night: int, kind: String, who: String, place: String, hour: float, inside := false, heading := "") -> void:
	# One entry per person per night, updated to the last time they were seen
	for s in sightings:
		if s["night"] == night and s["kind"] == kind and s["who"] == who and (kind != "figure" or s["place"] == place):
			s["place"] = place
			s["hour"] = hour
			s["inside"] = inside
			s["heading"] = heading
			return
	sightings.append({"night": night, "kind": kind, "who": who, "place": place, "hour": hour, "inside": inside,
			"heading": heading})


func _is_late(hour: float) -> bool:
	return hour >= 22.0 or hour < 6.0


func _night_order(hour: float) -> float:
	return hour + 24.0 if hour < 12.0 else hour  # 1 AM comes after 11 PM


# ---------- Conversation ----------

# A line in the current language: the English text is the key (see localization/strings.csv),
# {placeholders} are filled in after translating, so each language can order the sentence its own way.
func _t(text: String, args := {}) -> String:
	return Lang.contract(tr(text).format(args))


# A townsperson's name as the current language writes it
func _n(person: String) -> String:
	return tr(person)


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
		GameState.add_clue(_t("Day {day} · {name} was visited in the night and fears it will come back tonight.", {"day": GameState.day, "name": _n(data.npc_name)}), "evidence")
		return tr("Doctor... last night something stood by my bed. I couldn't move, and now my neck burns. Please, it will come back tonight.")
	var night := GameState.last_night()
	for s in sightings:
		if s["night"] == night and s["kind"] == "doctor_collapsed":
			var where := {"day": GameState.day, "name": _n(data.npc_name), "place": GameState.place_name(s["place"])}
			if s.get("inside", false):
				# He fell inside a building: only whoever was in there knows
				GameState.add_clue(_t("Day {day} · {name} found you collapsed inside {place} and keeps their distance.", where))
				if s["place"] == data.home:
					return tr("Doctor! I found you collapsed in my own house this morning. What were you doing in here?")
				return _t("Doctor! I found you collapsed inside {place} this morning. Are you ill... or is it something else?", where)
			GameState.add_clue(_t("Day {day} · {name} found you collapsed near {place} and keeps their distance.", where))
			var spot := tr("my door") if s["place"] == data.home else GameState.place_name(s["place"])
			return _t("Doctor! We found you lying in the street near {place} this morning. Are you ill... or is it something else?", {"place": spot})
	for s in sightings:
		if s["night"] == night and s["kind"] == "doctor_hiding":
			var hid := {"day": GameState.day, "name": _n(data.npc_name), "place": GameState.place_name(s["place"]), "time": GameState.format_time(s["hour"])}
			GameState.add_clue(_t("Day {day} · {name} caught you hiding in the dark near {place} at {time} and doesn't trust you.", hid))
			return _t("I saw you last night, doctor, creeping around in the dark near {place} at {time}. Who were you hiding from?", hid)
	for s in sightings:
		if s["night"] == night and s["kind"] == "doctor" and _is_late(s["hour"]):
			var out := {"day": GameState.day, "name": _n(data.npc_name), "place": GameState.place_name(s["place"]), "time": GameState.format_time(s["hour"])}
			GameState.add_clue(_t("Day {day} · {name} saw you out near {place} at {time} and keeps their distance.", out))
			return _t("I saw you near {place} at {time} last night, doctor. Decent folk are home by then.", out)
	if is_vampire() and GameState.faced_night == night:
		# It knows he saw its face last night. It won't say so, but it wants him to know.
		if not was_asked("faced"):
			asked["faced"] = GameState.day
			GameState.add_clue(_t("Day {day} · {name} spoke to you oddly, as if they knew where you were last night.", {"day": GameState.day, "name": _n(data.npc_name)}))
		var cold := ["You look tired, doctor. Long night? You should stay indoors after dark. People get hurt.",
				"Doctor. You walk fast for a man your age. Mind where you walk at night.",
				"Whatever you think you saw last night, doctor, the dark plays tricks. Sleep well tonight."]
		return tr(cold[GameState.day % cold.size()])
	if claims_sickness():
		var sick := ["This sickness... I can barely stand, doctor.",
				"Forgive me, doctor. The light hurts my eyes these days.",
				"I'm so tired. Is it the same thing the others have?"]
		return tr(sick[(GameState.day + data.npc_name.length()) % sick.size()])
	if is_servant:
		return tr("Doctor. What is it now?")
	var hellos := ["Good day, doctor.", "Doctor. Need something?", "Ah, doctor. Any news?"]
	return tr(hellos[(GameState.day + line_index) % hellos.size()])


func answer_alibi() -> String:
	Playtest.count("asked_alibi")
	asked["alibi"] = GameState.day
	if is_wary():
		if GameState.day > 1:
			GameState.record_refusal(GameState.last_night(), data.npc_name, "alibi")
		return _wary_line()
	if GameState.day == 1:
		# Before the doctor's first night here: just their usual day, from their routine
		var usual := _usual_day_text()
		GameState.add_clue(_t("Day {day} · {name}, about yesterday: \"{text}\"", {"day": 1, "name": _n(data.npc_name), "text": usual}))
		return usual
	var night := GameState.last_night()
	var text := _alibi_text(night)
	GameState.add_clue(_t("Day {day} · {name}, about last night: \"{text}\"", {"day": GameState.day, "name": _n(data.npc_name), "text": text}))
	var told := _told_plan(night)
	GameState.record_alibi(night, data.npc_name, told["plan"], told["bed"], data.home, text)
	return text


func answer_seen() -> String:
	Playtest.count("asked_seen")
	asked["seen"] = GameState.day
	if is_wary():
		if GameState.day > 1:
			GameState.record_refusal(GameState.last_night(), data.npc_name, "seen")
		return _wary_line()
	if GameState.day == 1:
		var rumor := _first_day_rumor()
		GameState.add_clue(_t("Day {day} · {name} said: \"{text}\"", {"day": 1, "name": _n(data.npc_name), "text": rumor}))
		return rumor
	var lines: Array[String] = []
	var night := GameState.last_night()
	var told: Array = []  # What they actually said, kept for the casebook's cross-check
	if is_servant:
		lines.append(_servant_sighting())  # A lie that points at someone innocent
		told.append(servant_lie)
	else:
		var seen := sightings.filter(func(s): return s["night"] == night and s["kind"] != "doctor_collapsed")
		# Most worrying first: dark figures, then whatever happened latest
		seen.sort_custom(func(a, b): return _weight(a) > _weight(b))
		for s in seen.slice(0, 3):
			lines.append(_describe(s))
			told.append(s)
	GameState.record_report(night, data.npc_name, told)
	var text := tr("No. I slept through the night.") if lines.is_empty() else Lang.join_sentences(lines)
	GameState.add_clue(_t("Day {day} · {name} saw: \"{text}\"", {"day": GameState.day, "name": _n(data.npc_name), "text": text}))
	return text


# Whether an exam would actually happen now (the dialogue spends the hour before asking)
func can_examine() -> bool:
	return not is_wary() and not (cared_day == GameState.day and not exams.is_empty())


func answer_exam() -> String:
	asked["exam"] = GameState.day
	if is_wary():
		return tr("I'd rather you didn't touch me today, doctor.")
	if cared_day == GameState.day and not exams.is_empty():
		return tr("You already examined me today, doctor. Nothing has changed since.")  # Once per day
	exam_count += 1
	if bite_spots.has("wrist") and not wrist_found and (exam_count >= 2 or randf() < 0.35):
		wrist_found = true  # A closer look this time: under the sleeve
	var record := vitals()
	var text := _exam_text(record)
	GameState.add_clue(_t("Day {day} · Exam of {name}: {text}", {"day": GameState.day, "name": _n(data.npc_name), "text": text}), "evidence")
	Playtest.count("exams")
	if is_vampire():
		Playtest.count("exams_of_the_vampire")
	elif blood < 80.0:
		Playtest.count("exams_of_bitten")
	if has_flu():
		Playtest.count("exams_of_flu")
	if cared_day != GameState.day:
		cared_day = GameState.day
		change_affinity(8.0)
		GameState.coins += GameState.EXAM_FEE  # The patient pays for the visit
	record["day"] = GameState.day
	record["marked"] = marked
	exams.append(record)
	if not GameState.casebook_hint_shown:
		GameState.casebook_hint_shown = true
		return text + "\n\n" + tr("(You wrote this down in your casebook. Press Tab to read your notes and open each patient's chart.)")
	return text


# What an exam shows right now, in a doctor's words (never the raw number)
func vitals() -> Dictionary:
	if is_vampire():
		# His own blood is his hunger: fed, he looks healthy; starving, he looks as anemic
		# as his victims. The tells: the pulse stays slow and there are never any marks.
		# The vitality bar reads like anyone else's: full while fed, falling only as hunger shows
		var vv := {"marks": false, "old_marks": false, "trace": "", "vitality": minf(blood / 80.0, 1.0), "dead": false}
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
	if has_flu():
		# Fever on top of whatever else: warm, and if the blood is fine, a strong quick pulse
		v["temp"] = ["Feverish", "Fever", "Hot"].pick_random()
		if blood >= 80.0:
			v["pulse"] = ["92, strong", "96, strong", "100, strong"].pick_random()
			v["look"] = ["Flushed", "Sweaty", "Red-nosed"].pick_random()
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
	if has_flu():
		return ["Coughs at night", "Restless", "Sweats"].pick_random()
	if worried:
		return ["Light", "Restless", "Nightmares"].pick_random()  # Frightened by the outbreak
	return "Restless" if randf() < 0.2 else "Sound"


func _exam_text(v: Dictionary) -> String:
	var parts: Array[String] = [_t("Pulse {pulse}.", {"pulse": Lang.value(v["pulse"])})]
	if blood >= 80.0 and has_flu():
		parts.append(tr("Flushed, forehead burning, a dry cough and a stuffy nose."))
	elif blood >= 80.0 and (is_vampire() or worried):
		parts.append(tr("Complains of weakness, but the blood seems fine."))
	elif blood >= 80.0:
		parts.append(tr("Good color."))
	elif blood >= ANEMIA_LEVEL:
		parts.append(tr("A little pale. Mild anemia."))
	elif blood >= 25.0:
		parts.append(tr("Pale and weak. Clear anemia."))
	else:
		parts.append(tr("Grey lips, can barely stand. Severe anemia: one more night like this could kill."))
	if has_flu() and blood < 80.0:
		parts.append(tr("Also feverish, with a cough."))
	if v["temp"] == "Cool" and blood >= ANEMIA_LEVEL:
		parts.append(tr("Hands a little cool, but it is autumn."))
	if neck_bitten():
		parts.append(_t("Two small punctures on the neck. On the collar, traces of {trace}.", {"trace": tr(bite_traces[-1])}))
	elif bite_spots.has("wrist") and wrist_found:
		parts.append(_t("No marks on the neck, but two small punctures inside the wrist. On the cuff, traces of {trace}.", {"trace": tr(bite_traces[-1])}))
	elif not is_servant:
		parts.append(tr("No marks on the neck."))
	if is_servant:
		parts.append(tr("The punctures are old and healed, and the eyes flinch from the window."))
	match str(v.get("sleep", "")):
		"Night terrors":
			parts.append(tr("Wakes screaming: dreams of something leaning over the bed."))
		"Hallucinations":
			parts.append(tr("Swears a figure stands at the foot of the bed each night."))
		"Sleepwalks":
			parts.append(tr("Was found at the door at night, with no memory of it."))
		"Nightmares":
			parts.append(tr("Sleeps badly, with nightmares."))
		"Coughs at night", "Sweats":
			parts.append(tr("Sleeps badly, coughing and sweating."))
	return Lang.join_sentences(parts)


func answer_chat() -> String:
	asked["chat"] = GameState.day
	if is_wary():
		return tr("I'd rather not chat today, doctor.")
	var line := "..."
	if is_servant:
		line = _servant_line()
	elif not data.dialogue_lines.is_empty():
		# Go through the lines in order, looping back to the start
		line = tr(data.dialogue_lines[line_index % data.dialogue_lines.size()])
		line_index += 1
	GameState.add_clue(_t("{name} said: \"{text}\"", {"name": _n(data.npc_name), "text": line}))
	return line


func _wary_line() -> String:
	return tr("I have nothing to tell you today, doctor.")


func _alibi_text(night: int) -> String:
	# What they really did that evening. The vampire tells this too: a lie by omission.
	if data.schedule.is_empty():
		return tr("At home, asleep.")
	var plan: Dictionary = data.schedule
	var bed := data.bedtime
	var last_place := _scheduled_place(18)
	if plans.has(night):
		plan = plans[night]["schedule"]
		bed = plans[night]["bedtime"]
		last_place = plan.get(18, last_place)
	var text := _t("From {time} I was {where}", {"time": GameState.format_time(18), "where": _where(last_place)})
	var hours := plan.keys()
	hours.sort()
	for h: int in hours:
		if h > 18 and h < bed and plan[h] != last_place:
			last_place = plan[h]
			text += _t(", then {where} from {time}", {"where": _where(last_place), "time": GameState.format_time(h)})
	if last_place != data.home:
		text += tr(", then I went home")
	return text + _t(". I went to bed around {time}.", {"time": GameState.format_time(bed)})


# The evening as they told it: where they were from 6 PM, and when they went to bed
func _told_plan(night: int) -> Dictionary:
	if data.schedule.is_empty():
		return {"plan": {18: data.home}, "bed": data.bedtime}
	var plan: Dictionary = data.schedule
	var bed := data.bedtime
	var last_place := _scheduled_place(18)
	if plans.has(night):
		plan = plans[night]["schedule"]
		bed = plans[night]["bedtime"]
		last_place = plan.get(18, last_place)
	var told := {18: last_place}
	for h: int in plan.keys():
		if h > 18 and h < bed:
			told[h] = plan[h]
	return {"plan": told, "bed": bed}


# Yesterday, before the doctor's first night: an ordinary day, told from their schedule
func _usual_day_text() -> String:
	if data.schedule.is_empty():
		return tr("Yesterday? Nothing special. I stayed home.")
	var hours: Array = data.schedule.keys()
	hours.sort()
	var parts: Array[String] = []
	var last := ""
	for h: int in hours:
		if h >= 18:
			break
		var place: String = data.schedule[h]
		if place == last:
			continue
		last = place
		parts.append(_t("{where} from {time}", {"where": _where(place), "time": GameState.format_time(h)}))
	var day_text := tr(", then ").join(PackedStringArray(parts)) if not parts.is_empty() else tr("at home")
	var openers := ["Yesterday? Like any other day.", "Same as always, doctor.", "An ordinary day, nothing more."]
	var opener: String = tr(openers[data.npc_name.length() % openers.size()])
	var weak := tr(" I've been tired lately, though.") if is_anemic() or has_flu() else ""
	return _t("{opener} I was {day}. {evening}{weak}", {"opener": opener, "day": day_text, "evening": _alibi_text(-1), "weak": weak})


# Day 1 "did you see anything": what the town already whispers about
func _first_day_rumor() -> String:
	if is_anemic():
		return tr("Only my own weakness, doctor. I wake up more tired every day, and I don't know why.")
	var pale: Array[String] = []
	var coughing: Array[String] = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self or npc.data == null or not npc.is_alive():
			continue
		if npc.is_anemic():
			pale.append(_n(npc.data.npc_name))
		elif npc.has_flu():
			coughing.append(_n(npc.data.npc_name))
	if not pale.is_empty():
		var who := tr(" and ").join(PackedStringArray(pale))
		if pale.size() == 1:
			return _t("Nothing with my own eyes. But {who} has been pale and weak for days. People whisper about a sickness.", {"who": who})
		return _t("Nothing with my own eyes. But {who} have been pale and weak for days. People whisper about a sickness.", {"who": who})
	if not coughing.is_empty():
		return _t("Only {name} coughing all day. The cold weather is here.", {"name": coughing[0]})
	return tr("Nothing strange. The dogs barked a little after midnight, that's all.")


func _where(place: String) -> String:
	if place == "Casa2" and data.home == "Casa2":
		return tr("at the forge")  # Tomas lives and works there
	if place == data.home and place.begins_with("Casa"):
		return tr("at home")
	if place == "Praca":
		return tr("in the square")
	return _t("at {place}", {"place": GameState.place_name(place)})


func _weight(s: Dictionary) -> float:
	return _night_order(s["hour"]) + (100.0 if s["kind"] == "figure" else 0.0)


func _describe(s: Dictionary) -> String:
	var time := GameState.format_time(s["hour"])
	var where := GameState.place_name(s["place"])
	if s["place"] == data.home:
		where = tr("my forge") if data.home == "Casa2" else tr("my house")  # Never their own name
	var a := {"time": time, "place": where, "name": _n(str(s["who"]))}
	match s["kind"]:
		"figure":
			return _t("Around {time} I saw a dark figure near {place}. I couldn't make out a face.", a)
		"doctor":
			return _t("And you, doctor, were near {place} around {time}.", a)
		"doctor_hiding":
			return _t("And you, doctor, were lurking in the shadows near {place} around {time}.", a)
	if s.get("inside", false):
		return _t("{name} was with me at {place} until about {time}.", a)
	if _is_late(s["hour"]):
		return _t("I saw {name} out near {place} around {time}. At that hour!", a)
	return _t("I saw {name} passing near {place} around {time}.", a)


var servant_lie := {}  # The made-up sighting behind the last lie, for the cross-check

func _servant_sighting() -> String:
	var innocents := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != self and npc.is_alive() and npc.data.npc_name != GameState.vampire_name:
			innocents.append(npc)
	if innocents.is_empty():
		return tr("Nothing. Nothing at all.")
	var target = innocents.pick_random()
	var place: String = GameState.PLACE_NAMES.keys().pick_random()
	var lie_hour := fposmod(snappedf(randf_range(22.5, 24.5), 1.0 / 6.0), 24.0)
	var time := GameState.format_time(lie_hour)
	servant_lie = {"night": GameState.last_night(), "kind": "person", "who": target.data.npc_name,
			"place": place, "hour": lie_hour, "inside": false}
	return _t("I saw {name} sneaking near {place} around {time}. Ask them where they were.", {"name": _n(target.data.npc_name), "place": GameState.place_name(place), "time": time})


# ---------- Burial ----------

func _on_phase_changed(is_night: bool) -> void:
	# The body stays at the door for the day it is found; at dusk it is buried
	if is_night and state == State.DEAD and not buried and GameState.day >= found_day:
		_bury()
	if is_night and is_alive() and data and not data.schedule.is_empty():
		_plan_evening()
	elif not is_night:
		tonight = {}
		if is_alive() and data:
			_flu_morning()


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
	if is_anemic() or flu_rest:
		# Too weak to go out (or the doctor said to rest)
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
	GameState.add_night_event(_t("{name} was buried in the cemetery beyond the bridge.", {"name": _n(data.npc_name)}))
	if not examined:
		GameState.add_clue(_t("Day {day} · {name} was buried before you examined the body.", {"day": GameState.day, "name": _n(data.npc_name)}), "evidence")


func _free_grave_slot() -> Node3D:
	# Empty slots come from the town model (empties named GraveSlot...)
	for slot in get_tree().root.find_children("GraveSlot*", "", true, false):
		if slot is Node3D and slot.get_child_count() == 0:
			return slot
	push_warning("No free grave slot in the cemetery")
	return null


func _make_headstone() -> Node3D:
	return make_headstone(_n(data.npc_name), tr(data.role))


# Dark weathered stone with a rounded top and a fresh mound, like the old graves around it.
# Static so the town can lay graves that were dug before the game began (Clara's Jonas).
static func make_headstone(title: String, subtitle: String) -> Node3D:
	var grave := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.21, 0.2)
	material.roughness = 0.95
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.62, 0.16)
	slab.mesh = box
	slab.position.y = 0.31
	slab.material_override = material
	grave.add_child(slab)
	var top := MeshInstance3D.new()
	var round_top := CylinderMesh.new()
	round_top.top_radius = 0.3
	round_top.bottom_radius = 0.3
	round_top.height = 0.16
	top.mesh = round_top
	top.rotation.x = PI / 2.0
	top.position.y = 0.62
	top.material_override = material
	grave.add_child(top)
	var mound := MeshInstance3D.new()
	var earth := SphereMesh.new()
	earth.radius = 0.5
	earth.height = 0.36
	mound.mesh = earth
	mound.scale = Vector3(0.75, 1.0, 1.5)
	mound.position = Vector3(0.0, 0.0, -0.8)  # Behind the stone, away from the camera
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.17, 0.11, 0.07)
	soil.roughness = 1.0
	mound.material_override = soil
	grave.add_child(mound)
	var plate := Label3D.new()
	plate.text = "%s\n%s" % [title, subtitle]
	plate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Already in the current language
	plate.font_size = 48
	plate.outline_size = 12
	plate.pixel_size = 0.006
	plate.position = Vector3(0.0, 0.42, 0.09)  # On the face of the stone, toward the camera
	plate.modulate = Color(0.9, 0.88, 0.82)
	grave.add_child(plate)
	return grave


# ---------- Clinic visits ----------

# Whether they would come at all. "" means yes: the doctor then picks today or tomorrow.
func clinic_refusal() -> String:
	asked["clinic"] = GameState.day
	if GameState.is_night:
		return tr("At this hour? Ask me tomorrow, doctor.")
	if is_wary():
		return tr("I'll manage on my own, thank you.")
	if appointment_until >= 0.0:
		return _t("I'll be at the clinic at {time}, doctor, as we agreed.", {"time": GameState.format_time(appointment_from)})
	if treated_day == GameState.day:
		return tr("You already treated me today, doctor. Let the tonic do its work.")  # Once per day
	if booked_day == GameState.day or visit_day == GameState.day:
		return tr("I couldn't make it today, doctor. Ask me again tomorrow.")  # One visit per day
	if blood >= 80.0 and not marked and not is_vampire() and not worried and not has_flu():
		return tr("Me? I feel fine, doctor. Save your medicine for the sick.")
	if not is_vampire() and affinity < 45.0 and randf() < 0.35:
		return tr("Tonics and bloodletting... no, doctor. I don't trust medicine.")  # Some refuse out of pride or fear
	return ""


# Too late in the day for a visit today: the doctor can only ask for tomorrow
func clinic_today_possible() -> bool:
	return floorf(GameState.hour) + 2.0 <= 18.0


# Called once clinic_refusal() said yes
func answer_clinic(tomorrow := false) -> String:
	if tomorrow and visit_day == GameState.day + 1:
		return tr("I'm already coming tomorrow, doctor.")
	# The vampire says yes and never comes (the sun). Weak patients sometimes can't make it either.
	booked_day = GameState.day
	skip_appointment = is_vampire() or randf() < 0.25
	# Today: one or two hours from now, lasting two hours (too late today means tomorrow morning).
	# Tomorrow: in the morning, once the ordered tonics have arrived.
	appointment_day = GameState.day
	appointment_from = minf(floorf(GameState.hour) + float(randi_range(1, 2)), 17.0)
	if tomorrow or appointment_from + 1.0 > 18.0:
		appointment_day = GameState.day + 1
		appointment_from = float(randi_range(8, 10))
	# One patient per hour: move to the next free hour (today, else tomorrow morning)
	while _slot_taken(appointment_day, appointment_from):
		appointment_from += 1.0
		if appointment_from + 1.0 > 18.0:
			if appointment_day != GameState.day:
				break  # Tomorrow is full too: share an hour, rare
			appointment_day = GameState.day + 1
			appointment_from = 8.0
	if appointment_day == GameState.day + 1 and visit_day == appointment_day:
		return tr("I'm already coming tomorrow, doctor.")  # Never two visits on the same day
	visit_day = appointment_day
	waiting_announced = false
	appointment_until = minf(appointment_from + 2.0, 18.0)  # Home before dark
	# Some patients are late and only turn up in the second hour
	appointment_arrival = appointment_from
	if appointment_from + 1.0 < appointment_until and randf() < 0.3:
		appointment_arrival = appointment_from + 1.0
	doctor_was_there = false
	appointment = {"day": appointment_day, "name": data.npc_name, "from": appointment_from,
			"until": appointment_until, "status": "waiting"}
	GameState.appointments.append(appointment)
	Playtest.count("appointments_booked")
	var when := GameState.format_time(appointment_from)
	var reply := _t("Yes... I'll come to the clinic at {time}. Please be there, doctor.", {"time": when})
	if appointment_day != GameState.day:
		reply = _t("Yes... I'll come to the clinic tomorrow at {time}. Please be there, doctor.", {"time": when})
	# A reminder when there are more patients coming than tonics on the shelf
	var waiting := 0
	for a in GameState.appointments:
		if a["status"] == "waiting":
			waiting += 1
	if waiting > GameState.tonics + GameState.tonics_ordered:
		reply += "\n" + tr("(You don't have a tonic for every patient. See the Supplies bookmark for how to make more.)")
		Playtest.count("booked_without_tonic")
	return reply


# Another patient is already expected at the clinic in that hour
func _slot_taken(day: int, from: float) -> bool:
	for a in GameState.appointments:
		if a["status"] == "waiting" and a["day"] == day and a["name"] != data.npc_name \
				and absf(float(a["from"]) - from) < 1.0:
			return true
	return false


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
				Playtest.count("appointments_absent")
				GameState.add_clue(_t("Day {day} · {name} never showed up at the clinic.", {"day": GameState.day, "name": _n(data.npc_name)}))
			else:
				# The doctor was not there in time (whether they came or not, he can't tell)
				appointment["status"] = "missed"
				Playtest.count("appointments_missed")
				GameState.add_clue(_t("Day {day} · You missed {name}'s appointment at the clinic.", {"day": GameState.day, "name": _n(data.npc_name)}))
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
		# Here and waiting: the doctor decides, in conversation, between the tonic and rest
		if not waiting_announced and not GameState.in_dialogue:
			waiting_announced = true
			EventBus.dialogue_started.emit(data.npc_name, tr("I'm here for the treatment, doctor. Examine me if you like, then give me the tonic or tell me what else to do."))


# Waiting at the clinic during their appointment, for the doctor's decision
func examined_today() -> bool:
	return not exams.is_empty() and exams[-1]["day"] == GameState.day


func awaiting_treatment() -> bool:
	return _at_clinic_now() and current_place == "Clinica" and treated_day != GameState.day


# The doctor gives the iron tonic (only at the clinic, during the appointment)
func answer_tonic() -> String:
	asked["tonic"] = GameState.day
	if not awaiting_treatment():
		return tr("The tonic? At the clinic, doctor, at the time we agreed.")
	if GameState.tonics <= 0:
		_no_tonic()
		return tr("No tonic, doctor? Then why did you call me here...")
	var feverish := has_flu() and blood >= 80.0
	Playtest.count("tonics_given")
	if feverish:
		Playtest.count("tonic_wasted_on_flu")
	_treat()
	if feverish:
		GameState.add_clue(_t("Day {day} · The tonic did nothing for {name}'s fever.", {"day": GameState.day, "name": _n(data.npc_name)}), "evidence")
		return tr("Thank you, doctor... though my head still burns.")
	return tr("Thank you, doctor. I feel stronger already.")


# Rest and good food: cures a chill in half the time, does nothing for lost blood
func answer_rest() -> String:
	asked["rest"] = GameState.day
	if exams.is_empty() or exams[-1]["day"] != GameState.day:
		return tr("Rest? You haven't even examined me today, doctor.")
	if rest_day == GameState.day:
		return tr("I know, doctor: bed, broth and warm milk. I'll do as you say.")
	rest_day = GameState.day
	if awaiting_treatment():
		treated_day = GameState.day
		appointment_until = -1.0
		appointment["status"] = "rest"
		if state == State.INSIDE:
			set_state(State.ROUTINE)
	GameState.add_clue(_t("Day {day} · You prescribed rest and good food to {name}.", {"day": GameState.day, "name": _n(data.npc_name)}), "evidence")
	Playtest.count("rest_prescribed")
	if has_flu():
		Playtest.count("rest_for_flu")
	elif blood < 80.0:
		Playtest.count("rest_for_bitten")
	if has_flu():
		flu_rest = true
		change_affinity(6.0)
		return tr("Bed and broth... yes, doctor. This fever needs it.")
	if blood < 80.0:
		return tr("If you say so, doctor... but I'm so weak, and rest hasn't helped so far.")
	return tr("Rest? I feel fine, doctor, but I'll take it easy.")


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
	GameState.add_clue(_t("Day {day} · {name} came to the clinic, but you had no tonic left.", {"day": GameState.day, "name": _n(data.npc_name)}))
	if state == State.INSIDE:
		set_state(State.ROUTINE)
	if not GameState.in_dialogue:
		EventBus.dialogue_started.emit(data.npc_name, tr("No tonic, doctor? Then why did you call me here..."))


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
	var note := _t("Day {day} · You treated {name} at the clinic: an iron tonic and rest.", {"day": GameState.day, "name": _n(data.npc_name)})
	if was_marked:
		note += tr(" The night visitor's hold on them is broken.")
	GameState.add_clue(note, "evidence")
	if state == State.INSIDE:
		set_state(State.ROUTINE)  # Back to their day
