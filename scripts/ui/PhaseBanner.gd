extends CanvasLayer

@onready var label: Label = $Label

func _ready() -> void:
	label.modulate.a = 0.0  # Start invisible
	EventBus.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(is_night: bool) -> void:
	label.text = ("Noite %d" if is_night else "Dia %d") % GameState.day
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.0)  # Fade in
	tween.tween_interval(2.0)                            # Hold
	tween.tween_property(label, "modulate:a", 0.0, 1.0)  # Fade out
