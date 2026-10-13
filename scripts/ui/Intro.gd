extends CanvasLayer

const INTRO := "Autumn.\n\nYou are a country doctor, summoned to the quiet town of Pallbrook. Its last physician left without a word.\n\nThe townsfolk are pale and tired, and some of them no longer wake up.\n\nBy day, talk to people and examine what the night leaves behind. By night, get back to the clinic before 1 AM.\n\nOne of them is not what they seem. When you are sure, accuse them. You only get one chance."

@onready var background: Control = $Background
@onready var body: Label = $Background/Body


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameState.intro_seen:
		background.visible = false
		return
	body.text = INTRO
	get_tree().paused = true  # The town waits until the player is ready


func _input(event: InputEvent) -> void:
	if not background.visible or GameState.intro_seen:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # This E must not also trigger the player
		GameState.intro_seen = true
		get_tree().paused = false
		var tween := create_tween()
		tween.tween_property(background, "modulate:a", 0.0, 1.5)  # Fade into the town
		await tween.finished
		background.visible = false
