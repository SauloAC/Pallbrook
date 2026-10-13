extends CanvasLayer

enum Mode { HIDDEN, CONFIRM, RESULT }

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var body: Label = $Panel/VBox/Body
@onready var hint: Label = $Panel/VBox/Hint

var mode := Mode.HIDDEN
var suspect: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while the game is paused
	panel.visible = false
	EventBus.accusation_requested.connect(_on_accusation_requested)
	EventBus.game_ended.connect(_on_game_ended)


func _on_accusation_requested(npc: Node) -> void:
	if GameState.game_over or get_tree().paused:
		return
	suspect = npc
	var accused: String = npc.data.npc_name
	_show(Mode.CONFIRM, "Accuse %s?" % accused,
		"You are about to name %s as the vampire in front of the whole town.\nThere is no going back." % accused,
		"[E] Accuse      [Esc] Cancel")


func _on_game_ended(won: bool, message: String) -> void:
	GameState.game_over = true
	var heading := "Pallbrook is saved" if won else "Pallbrook is lost"
	_show(Mode.RESULT, heading, message, "[E] Play again")


func _show(new_mode: Mode, heading: String, text: String, keys: String) -> void:
	mode = new_mode
	title.text = heading
	body.text = text
	hint.text = keys
	panel.visible = true
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if mode == Mode.CONFIRM:
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_resolve()
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			mode = Mode.HIDDEN
			panel.visible = false
			get_tree().paused = false
	elif mode == Mode.RESULT and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		GameState.reset()
		get_tree().paused = false
		get_tree().reload_current_scene()  # Fresh town, new vampire


func _resolve() -> void:
	var accused: String = suspect.data.npc_name
	if accused == GameState.vampire_name:
		EventBus.game_ended.emit(true, "You unmasked %s on Day %d. %d townspeople survived." % [accused, GameState.day, _survivors()])
	else:
		EventBus.game_ended.emit(false, "%s was innocent. The real vampire was %s, and now they know you're onto them." % [accused, GameState.vampire_name])


func _survivors() -> int:
	var count := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_alive() and not npc.is_servant and npc.data.npc_name != GameState.vampire_name:
			count += 1
	return count
