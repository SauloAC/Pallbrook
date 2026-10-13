extends CanvasLayer

@onready var clock: Label = $Clock
@onready var controls: Label = $Controls


func _ready() -> void:
	controls.text = "WASD / Arrows  Move      E  Talk · Examine · Sleep      Q  Accuse      Tab  Casebook"


func _process(_delta: float) -> void:
	var hours := int(GameState.hour)
	var minutes := int((GameState.hour - hours) * 6.0) * 10  # Shown in 10-minute steps
	var phase := "Night" if GameState.is_night else "Day"
	clock.text = "Day %d   ·   %02d:%02d   ·   %s" % [GameState.day, hours, minutes, phase]
	# Turns red once exhaustion starts: a warning to head to the clinic
	clock.modulate = Color(1.0, 0.45, 0.45) if GameState.exhaustion > 0.0 else Color.WHITE
