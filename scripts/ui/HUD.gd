extends CanvasLayer

@onready var clock: Label = $Clock
@onready var controls: Label = $Controls


func _ready() -> void:
	controls.text = "WASD / Arrows  Move      E  Talk · Examine · Sleep      Q  Accuse      Tab  Casebook"


func _process(_delta: float) -> void:
	var phase := "Night" if GameState.is_night else "Day"
	clock.text = "Day %d   ·   %s   ·   %s" % [GameState.day, GameState.format_time(GameState.hour), phase]
	clock.modulate = Color(1.0, 0.45, 0.45) if GameState.exhaustion > 0.0 else Color.WHITE
