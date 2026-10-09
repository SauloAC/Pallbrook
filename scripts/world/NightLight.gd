extends Light3D

# Any light with this script turns on at night and off during the day

var on_energy: float

func _ready() -> void:
	on_energy = light_energy  # The brightness set in the Inspector
	light_energy = on_energy if GameState.is_night else 0.0
	EventBus.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(is_night: bool) -> void:
	var tween := create_tween()
	# Small random delay so the lights don't all switch at once
	tween.tween_interval(randf_range(0.0, 1.5))
	tween.tween_property(self, "light_energy", on_energy if is_night else 0.0, 2.0)
