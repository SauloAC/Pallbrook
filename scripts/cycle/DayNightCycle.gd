extends Node

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var seconds_per_hour := 30.0
@export var start_hour := 8.0
@export var day_start_hour := 6.0
@export var night_start_hour := 18.0
@export var exhaustion_start_hour := 0.0
@export var collapse_hour := 1.0

var hour: float
var is_collapsing := false
var last_hour := -1

func _ready() -> void:
	hour = start_hour
	GameState.hour = hour
	# Test listener: shows the EventBus working
	EventBus.phase_changed.connect(func(is_night): print("Night " if is_night else "Day ", GameState.day))
	_update_lighting()
	EventBus.player_slept.connect(_on_player_slept)

func _process(delta: float) -> void:
	hour += delta / seconds_per_hour
	if hour >= 24.0:
		hour -= 24.0
	_check_phase()
	_update_exhaustion()
	_update_lighting()
	GameState.hour = hour
	if int(hour) != last_hour:
		last_hour = int(hour)
		EventBus.hour_changed.emit(last_hour)

func _check_phase() -> void:
	var should_be_night := hour >= night_start_hour or hour < day_start_hour
	if should_be_night and not GameState.is_night:
		GameState.start_night()
	elif not should_be_night and GameState.is_night:
		GameState.start_day()

func _update_lighting() -> void:
	# 0.0 at 6:00 (sunrise), 1.0 at 18:00 (sunset)
	var t := (hour - 6.0) / 12.0
	var daylight := clampf(sin(t * PI), 0.0, 1.0)

	if sun:
		sun.rotation_degrees.x = -lerpf(15.0, 165.0, clampf(t, 0.0, 1.0))
		sun.light_energy = lerpf(0.15, 1.0, daylight)
		# Bluish moonlight at night, warm white during the day
		sun.light_color = Color(0.5, 0.6, 1.0).lerp(Color(1.0, 0.95, 0.85), daylight)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_energy_multiplier = lerpf(0.05, 1.0, daylight)
		env.ambient_light_energy = lerpf(0.25, 1.0, daylight)

func _update_exhaustion() -> void:
	# Only between midnight and sunrise
	if GameState.is_night and hour >= exhaustion_start_hour and hour < day_start_hour:
		var progress := (hour - exhaustion_start_hour) / (collapse_hour - exhaustion_start_hour)
		GameState.exhaustion = clampf(progress, 0.0, 1.0)
		if GameState.exhaustion >= 1.0 and not is_collapsing:
			_collapse()
	else:
		GameState.exhaustion = 0.0

func _collapse() -> void:
	var finders := _report_collapse()
	if finders.is_empty():
		GameState.add_night_event("You collapsed in the street. Someone may have seen the doctor lying there.")
	else:
		GameState.add_night_event("You collapsed in the street. %s found you there at dawn." % " and ".join(PackedStringArray(finders)))
	GameState.collapsed_in_street = true
	EventBus.player_collapsed.emit()
	_skip_to_morning()

func _on_player_slept() -> void:
	if is_collapsing:
		return
	GameState.add_night_event("You slept at the clinic.")
	_skip_to_morning()  # Slept safely: no consequence

func _skip_to_morning() -> void:
	is_collapsing = true
	await get_tree().create_timer(2.0).timeout
	hour = day_start_hour
	is_collapsing = false


# The two neighbors living closest to where the doctor fell find him at dawn.
# They will mention it, and keep their distance for the day.
func _report_collapse() -> Array[String]:
	var names: Array[String] = []
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return names
	var spot := player.global_position
	var place := GameState.nearest_place(spot)
	var neighbors := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.is_alive():
			neighbors.append(npc)
	neighbors.sort_custom(func(a, b):
		return GameState.place_position(a.data.home).distance_to(spot) < GameState.place_position(b.data.home).distance_to(spot))
	for npc in neighbors.slice(0, 2):
		npc.add_sighting(GameState.day, "doctor_collapsed", "the doctor", place, hour)
		npc.wary_day = GameState.day + 1
		npc.change_affinity(-15.0)
		names.append(npc.data.npc_name)
	return names
