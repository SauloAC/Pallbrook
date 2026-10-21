extends CanvasLayer

const INTRO := "Autumn.\n\nPallbrook's doctor vanished one night without a word. Since then, a strange anemia has spread through the town: people wake pale and weak, and some no longer wake at all.\n\nYou are the physician sent to stop the outbreak.\n\nBy day, visit the sick, examine them and ask what they saw. By night, get back to the clinic before 1 AM.\n\nThis sickness has a cause, and it walks among them. When you are sure who it is, accuse them. You only get one chance."

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
		Audio.start_game()  # Title theme fades out, the town's music fades in
		get_tree().paused = false
		var tween := create_tween()
		tween.tween_property(background, "modulate:a", 0.0, 1.5)  # Fade into the town
		await tween.finished
		background.visible = false
