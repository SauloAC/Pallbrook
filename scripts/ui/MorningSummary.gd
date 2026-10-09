extends CanvasLayer

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var body: Label = $Panel/VBox/Body

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keeps working while the game is paused
	panel.visible = false
	EventBus.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(is_night: bool) -> void:
	if is_night:
		return
	# Wait for the "Dia X" banner to finish before showing the summary
	await get_tree().create_timer(4.5).timeout
	_show_summary()

func _show_summary() -> void:
	title.text = "Manhã do Dia %d" % GameState.day
	if GameState.night_events.is_empty():
		body.text = "A noite passou em silêncio."
	else:
		body.text = "• " + "\n• ".join(PackedStringArray(GameState.night_events))
	panel.visible = true
	get_tree().paused = true  # Time stops while the player reads

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("interact"):
		panel.visible = false
		get_tree().paused = false
