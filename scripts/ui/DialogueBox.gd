extends CanvasLayer

@onready var panel: Control = $Panel
@onready var speaker: Label = $Panel/VBox/Speaker
@onready var body: Label = $Panel/VBox/Body

var opened_frame := -1


func _ready() -> void:
	panel.visible = false
	EventBus.dialogue_started.connect(_on_dialogue_started)


func _on_dialogue_started(speaker_name: String, line: String) -> void:
	speaker.text = speaker_name
	body.text = line
	panel.visible = true
	GameState.in_dialogue = true
	opened_frame = Engine.get_process_frames()


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the same key press that opened the box
	if not panel.visible or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("interact"):
		panel.visible = false
		GameState.in_dialogue = false
		EventBus.dialogue_ended.emit()
		get_viewport().set_input_as_handled()
