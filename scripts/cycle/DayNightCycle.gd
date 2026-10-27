extends Node

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var seconds_per_hour := 60.0
@export var start_hour := 8.0
@export var day_start_hour := 6.0
@export var night_start_hour := 18.0
@export var exhaustion_start_hour := 0.0
@export var collapse_hour := 1.0
# Fog days: a thin haze over everything, thicker close to the ground so roofs rise out of it.
# Tweak these on the node in the inspector while the game runs.
@export var fog_density := 0.004
@export var fog_height := 2.5          # Above this the fog thins out
@export var fog_height_density := 0.2  # How fast it thickens below fog_height

var hour: float
var is_collapsing := false
var last_hour := -1

func _ready() -> void:
	add_to_group("day_night")  # Reading and brewing ask it to pass time
	hour = start_hour
	GameState.hour = hour
	# Test listener: shows the EventBus working
	EventBus.phase_changed.connect(func(is_night): print("Night " if is_night else "Day ", GameState.day))
	_update_lighting()
	EventBus.player_slept.connect(_on_player_slept)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


# Time spent in a conversation (an exam is an hour) passes once the talk is over
func _on_dialogue_ended() -> void:
	if GameState.pending_hours <= 0.0:
		return
	var hours := GameState.pending_hours
	GameState.pending_hours = 0.0
	if not GameState.is_night:
		pass_hours.call_deferred(hours)

func _process(delta: float) -> void:
	hour += delta / seconds_per_hour
	if hour >= 24.0:
		hour -= 24.0
	GameState.hour = hour  # Set first: phase listeners (dawn reports) read the new hour
	_check_phase()
	_update_exhaustion()
	_update_lighting()
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
	# The sky is already light at 6 AM (the sun rises at 5) and stays light until 7 PM;
	# full light from about 8 AM to 4 PM
	var sky_t := (hour - 5.0) / 14.0
	var daylight := clampf(sin(sky_t * PI) * 1.7, 0.0, 1.0)

	# Clouds and fog dim the sun and grey its colour (the weather is rolled at dawn)
	var sun_max := 1.0
	var grey := 0.0
	if GameState.weather == "cloudy":
		sun_max = 0.75
		grey = 0.6
	elif GameState.weather == "fog":
		sun_max = 0.85
		grey = 0.45
	if sun:
		# By day it crosses east to west; by night the moon swings slowly back, so the light never
		# jumps (at midnight it used to flip from one horizon to the other in a single frame)
		var angle := lerpf(15.0, 165.0, t)
		if t < 0.0 or t > 1.0:
			angle = lerpf(165.0, 15.0, fposmod(hour - 18.0, 24.0) / 12.0)
		sun.rotation_degrees.x = -angle
		sun.light_energy = lerpf(0.25, sun_max, daylight)  # Moonlight: dark, but streets still readable
		# Bluish moonlight at night, warm white during the day (greyer under clouds)
		var day_color := Color(1.0, 0.95, 0.85).lerp(Color(0.82, 0.85, 0.9), grey)
		sun.light_color = Color(0.5, 0.6, 1.0).lerp(day_color, daylight)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_energy_multiplier = lerpf(0.15, 1.0, daylight) * lerpf(1.0, 0.8, grey)
		env.ambient_light_energy = lerpf(0.7, 1.0, daylight)  # Night: dark blue, never pitch black
		env.fog_enabled = GameState.weather == "fog"
		if env.fog_enabled:
			env.fog_light_color = Color(0.72, 0.75, 0.8)
			env.fog_light_energy = lerpf(0.08, 1.0, daylight)
			env.fog_density = fog_density
			env.fog_height = fog_height
			env.fog_height_density = fog_height_density

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
	if GameState.doom_tonight and not _safe_here():
		EventBus.game_ended.emit(false, tr("You fell where it could reach you. It did not wait for dawn. Pallbrook will need another doctor."))
		return
	var building := GameState.open_building  # Fell inside a walk-in building ("" = in the street)
	var finders := _report_collapse(building)
	var who := PackedStringArray()
	for finder in finders:
		who.append(tr(finder))
	var args := {"who": tr(" and ").join(who), "place": GameState.place_name(building)}
	if building != "" and finders.is_empty():
		GameState.add_night_event(Lang.contract(tr("You collapsed inside {place}. Nobody was there to see it; you woke on the floor at dawn.").format(args)))
	elif building != "":
		GameState.add_night_event(Lang.contract(tr("You collapsed inside {place}. {who} found you there at dawn.").format(args)))
	elif finders.is_empty():
		GameState.add_night_event(tr("You collapsed in the street. Someone may have seen the doctor lying there."))
	else:
		GameState.add_night_event(Lang.contract(tr("You collapsed in the street. {who} found you there at dawn.").format(args)))
	GameState.collapsed_in_street = true
	EventBus.player_collapsed.emit()
	_skip_to_morning()

func _on_player_slept() -> void:
	if is_collapsing:
		return
	if GameState.doom_tonight:
		EventBus.game_ended.emit(false, tr("It came for you at the clinic while you slept. Pallbrook will need another doctor."))
		return
	GameState.add_night_event(tr("You slept at the clinic."))
	_skip_to_morning()  # Slept safely: no consequence

func _safe_here() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var zones := get_tree().get_first_node_in_group("safe_zones")
	return player != null and zones != null and zones.is_safe(player.global_position)


# Hours spent on something (reading, brewing): the screen fades out, the clock jumps, the town
# catches up with its schedule, then the result is shown. Only used by day.
var passing := false

# The clock jumps forward (never past dusk) and the town catches up with its schedule.
# No fade here: whoever calls it covers the screen (pass_hours, the exam in DialogueBox).
func advance_clock(hours: float) -> void:
	hour = minf(hour + hours, night_start_hour - 0.05)
	GameState.hour = hour
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("catch_up"):
			npc.catch_up()
	_update_lighting()


func pass_hours(hours: float, note := "", on_done := Callable()) -> void:
	if passing:
		return
	passing = true
	GameState.in_dialogue = true  # The doctor is busy: he stands still and nobody talks to him
	var fade := CanvasLayer.new()
	fade.layer = 30
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(veil)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(veil, "color:a", 1.0, 0.6)
	await tween.finished
	advance_clock(hours)
	if on_done.is_valid():
		on_done.call()
	await get_tree().create_timer(0.4).timeout
	tween = create_tween()
	tween.tween_property(veil, "color:a", 0.0, 0.6)
	await tween.finished
	fade.queue_free()
	GameState.in_dialogue = false
	passing = false
	if note != "":
		EventBus.dialogue_started.emit("Doctor", note)


func _skip_to_morning() -> void:
	is_collapsing = true
	await get_tree().create_timer(2.0).timeout
	hour = day_start_hour
	is_collapsing = false


# In the street: the two neighbors living closest to where the doctor fell find him at dawn.
# Inside a building: only whoever is in that building (awake or asleep there) finds him;
# an empty building keeps the secret. Someone who saw him walk in can only say that.
# Those who find him will mention it, and keep their distance for the day.
func _report_collapse(building := "") -> Array[String]:
	var names: Array[String] = []
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return names
	var spot := player.global_position
	var place := GameState.nearest_place(spot)
	var neighbors := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.is_alive() and (building == "" or npc.current_place == building):
			neighbors.append(npc)
	if building != "":
		place = building
	else:
		neighbors.sort_custom(func(a, b):
			return GameState.place_position(a.data.home).distance_to(spot) < GameState.place_position(b.data.home).distance_to(spot))
		neighbors = neighbors.slice(0, 2)
	for npc in neighbors:
		npc.add_sighting(GameState.day, "doctor_collapsed", "the doctor", place, hour, building != "")
		npc.wary_day = GameState.day + 1
		npc.change_affinity(-15.0)
		names.append(npc.data.npc_name)
	return names
