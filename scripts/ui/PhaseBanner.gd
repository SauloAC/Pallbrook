extends CanvasLayer

@onready var label: Label = $Label
@onready var fade: ColorRect = $Fade
@onready var vignette: ColorRect = $Vignette

func _ready() -> void:
	label.modulate.a = 0.0
	fade.modulate.a = 0.0
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.player_collapsed.connect(_on_player_collapsed)
	EventBus.player_slept.connect(_on_player_collapsed)

func _on_player_collapsed() -> void:
	create_tween().tween_property(fade, "modulate:a", 1.0, 1.5)  # Fade to black

func _on_phase_changed(is_night: bool) -> void:
	label.text = ("Noite %d" if is_night else "Dia %d") % GameState.day
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.0)
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	if not is_night:
		# Wake up: black screen slowly fades away
		create_tween().tween_property(fade, "modulate:a", 0.0, 3.0)
		
func _process(_delta: float) -> void:
	# Slight pulse, like a heartbeat, stronger when more exhausted
	var pulse := sin(Time.get_ticks_msec() / 300.0) * 0.12 * GameState.exhaustion
	vignette.material.set_shader_parameter("intensity", clampf(GameState.exhaustion + pulse, 0.0, 1.0))
