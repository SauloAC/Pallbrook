extends Area3D

@onready var prompt: Label3D = $Prompt
var player_inside := false

func _ready() -> void:
	body_entered.connect(func(body): if body.name == "Jogador": player_inside = true)
	body_exited.connect(func(body): if body.name == "Jogador": player_inside = false)

func _process(_delta: float) -> void:
	# Only offer sleep at night, when the player is at the door
	prompt.visible = player_inside and GameState.is_night

func _unhandled_input(event: InputEvent) -> void:
	if prompt.visible and event.is_action_pressed("interact"):
		EventBus.player_slept.emit()
