extends Node

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var seconds_per_hour := 10.0
@export var start_hour := 8.0
@export var day_start_hour := 6.0
@export var night_start_hour := 20.0

var hour: float

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
