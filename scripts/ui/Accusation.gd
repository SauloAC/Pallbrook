extends CanvasLayer

enum Mode { HIDDEN, CONFIRM, RESULT }

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var body: Label = $Panel/VBox/Body
@onready var hint: Label = $Panel/VBox/Hint

const FIRST_ACCUSATION_DAY := 2

var mode := Mode.HIDDEN
var suspect: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while the game is paused
	panel.visible = false
	EventBus.accusation_requested.connect(_on_accusation_requested)
	EventBus.game_ended.connect(_on_game_ended)


func _on_accusation_requested(npc: Node) -> void:
	if GameState.game_over or get_tree().paused or GameState.reading:
		return
	if GameState.day < FIRST_ACCUSATION_DAY:
		# The first day is for getting to know the town
		EventBus.dialogue_started.emit("Doctor", tr("It's too soon to accuse anyone. Examine people, ask where they were, and watch the town tonight. (Accusations open on Day %d.)") % FIRST_ACCUSATION_DAY)
		return
	suspect = npc
	var accused: String = npc.data.npc_name
	_show(Mode.CONFIRM, tr("Accuse %s?") % tr(accused),
		tr("You are about to name %s as the vampire in front of the whole town.\nThere is no going back.") % tr(accused),
		tr("[E] Accuse      [Esc] Cancel"))


func _on_game_ended(won: bool, message: String) -> void:
	GameState.game_over = true
	var heading := tr("Pallbrook is saved") if won else tr("Pallbrook is lost")
	_show(Mode.RESULT, heading, message, tr("[E] Play again"))


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
		mode = Mode.HIDDEN
		panel.visible = false
		# A few playtest questions first, then a fresh town with a new vampire
		Playtest.show_survey(func():
			GameState.reset()
			Playtest.start_run()
			get_tree().paused = false
			get_tree().reload_current_scene())


func _resolve() -> void:
	var accused: String = suspect.data.npc_name
	Playtest.note_accused(accused)
	if accused == GameState.vampire_name:
		EventBus.game_ended.emit(true, tr("You unmasked {name} on Day {day}. {alive} townspeople survived.").format({"name": tr(accused), "day": GameState.day, "alive": _survivors()}))
	else:
		EventBus.game_ended.emit(false, tr("{accused} was innocent. The real vampire was {vampire}, and now they know you're onto them.").format({"accused": tr(accused), "vampire": tr(GameState.vampire_name)}))


func _survivors() -> int:
	var count := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_alive() and not npc.is_servant and npc.data.npc_name != GameState.vampire_name:
			count += 1
	return count
