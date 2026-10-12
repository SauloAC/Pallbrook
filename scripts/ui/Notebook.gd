extends CanvasLayer


@onready var panel: Control = $Panel
@onready var entries: Label = $Panel/VBox/Scroll/Entries

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the game is paused
	panel.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("notebook"):
		return
	if panel.visible:
		_close()
	elif not GameState.in_dialogue and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	if GameState.clues.is_empty():
		entries.text = "Nenhuma pista ainda."
	else:
		entries.text = "• " + "\n\n• ".join(PackedStringArray(GameState.clues))
	panel.visible = true
	get_tree().paused = true  # Time stops while reading
	
	
func _close() -> void:
	panel.visible = false
	get_tree().paused = false
	
