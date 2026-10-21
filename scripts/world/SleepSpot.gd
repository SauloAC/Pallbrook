extends Area3D

# The clinic door: sleep here at night; by day, order tonic ingredients from the cabinet

const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_CABINET := preload("res://assets/ui/icon_examine.png")

@onready var prompt: Sprite3D = $Prompt
var player_inside := false

func _ready() -> void:
	body_entered.connect(func(body): if body.name == "Jogador": player_inside = true)
	body_exited.connect(func(body): if body.name == "Jogador": player_inside = false)

func _process(_delta: float) -> void:
	prompt.visible = player_inside and not GameState.in_dialogue
	prompt.texture = ICON_SLEEP if GameState.is_night else ICON_CABINET

func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if GameState.is_night:
		EventBus.player_slept.emit()
		return
	# Day: one tonic per press
	var text := ""
	if GameState.order_tonic():
		text = "You ordered the ingredients for one iron tonic (%d coins). It will be ready tomorrow morning.\nCoins left: %d · Tonics ordered: %d" % [GameState.TONIC_PRICE, GameState.coins, GameState.tonics_ordered]
	else:
		text = "Iron salts, herbs, a little wine... one tonic costs %d coins, and you have %d." % [GameState.TONIC_PRICE, GameState.coins]
	EventBus.dialogue_started.emit("Supply cabinet", text)
