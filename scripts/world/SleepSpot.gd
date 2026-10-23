extends Area3D

# Inside the clinic: by day, order tonic ingredients at the supply cabinet;
# at night, sleep in the bed. The spot moves to whichever one is in use.

const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_CABINET := preload("res://assets/ui/icon_examine.png")

@export var bed_position := Vector3(-1.2, -1.5, -0.4)     # Relative to the Clinica node
const SLEEP_FROM_HOUR := 22.0  # The first hours of the night are for watching the streets

@export var cabinet_position := Vector3(1.4, -1.5, -1.2)

@onready var prompt: Sprite3D = $Prompt
var player_inside := false

func _ready() -> void:
	body_entered.connect(func(body): if body.name == "Jogador": player_inside = true)
	body_exited.connect(func(body): if body.name == "Jogador": player_inside = false)
	position = bed_position if GameState.is_night else cabinet_position

func _process(_delta: float) -> void:
	var target := bed_position if GameState.is_night else cabinet_position
	if position != target:
		position = target  # Overlap signals catch up on the next physics frame
	prompt.visible = player_inside and not GameState.in_dialogue
	prompt.texture = ICON_SLEEP if GameState.is_night else ICON_CABINET

func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if GameState.is_night:
		if GameState.hour >= 12.0 and GameState.hour < SLEEP_FROM_HOUR:
			EventBus.dialogue_started.emit("Bed", "Too early to sleep. The night is when things happen.")
			return
		EventBus.player_slept.emit()
		return
	# Day: one tonic per press
	var text := ""
	if GameState.order_tonic():
		text = "You ordered the ingredients for one iron tonic (%d coins). It will be ready tomorrow morning.\nCoins left: %d · Tonics ordered: %d" % [GameState.TONIC_PRICE, GameState.coins, GameState.tonics_ordered]
	else:
		text = "Iron salts, herbs, a little wine... one tonic costs %d coins, and you have %d." % [GameState.TONIC_PRICE, GameState.coins]
	EventBus.dialogue_started.emit("Supply cabinet", text)
