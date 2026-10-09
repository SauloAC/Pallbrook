extends Node

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var seconds_per_hour := 60.0
@export var start_hour := 8.0
@export var day_start_hour := 6.0
@export var night_start_hour := 20.0
@export var exhaustion_start_hour := 0.0
@export var collapse_hour := 1.0

var hour: float
var is_collapsing := false

func _ready() -> void:
	hour = start_hour
	# Test listener: shows the EventBus working
	EventBus.phase_changed.connect(func(is_night): print("Night " if is_night else "Day ", GameState.day))
	_update_lighting()

func _process(delta: float) -> void:
	hour += delta / seconds_per_hour
	if hour >= 24.0:
		hour -= 24.0
	_check_phase()
	_update_exhaustion()
	_update_lighting()

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
	is_collapsing = true
	GameState.collapsed_in_street = true
	EventBus.player_collapsed.emit()
	await get_tree().create_timer(2.0).timeout  # Time for the screen to go black
	hour = day_start_hour  # Jump to sunrise; _check_phase will start the new day
	is_collapsing = false
