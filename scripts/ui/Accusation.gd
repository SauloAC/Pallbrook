extends CanvasLayer

enum Mode { HIDDEN, CONFIRM, RESULT }

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var body: Label = $Panel/VBox/Body
@onready var hint: Label = $Panel/VBox/Hint

const FIRST_ACCUSATION_DAY := 2

var mode := Mode.HIDDEN
var suspect: Node = null
var hearing: Hearing  # The hearing itself, at 7 PM at the Town Hall


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while the game is paused
	panel.visible = false
	EventBus.accusation_requested.connect(_on_accusation_requested)
	EventBus.game_ended.connect(_on_game_ended)
	hearing = Hearing.new()
	hearing.setup(panel.get_theme_stylebox("panel"), title.get_theme_font("font"))
	add_child(hearing)


func _on_accusation_requested(npc: Node) -> void:
	if GameState.game_over or get_tree().paused or GameState.reading:
		return
	if GameState.day < FIRST_ACCUSATION_DAY:
		# The first day is for getting to know the town
		EventBus.dialogue_started.emit("Doctor", tr("It's too soon to accuse anyone. Examine people, ask where they were, and watch the town tonight. (Accusations open on Day %d.)") % FIRST_ACCUSATION_DAY)
		return
	if GameState.hearings_held >= GameState.MAX_HEARINGS:
		EventBus.dialogue_started.emit("Doctor", tr("The town will not gather for you again. You will have to stop it some other way."))
		return
	if not GameState.hearing.is_empty():
		EventBus.dialogue_started.emit("Doctor", Lang.contract(tr("A hearing is already called against {name}.").format({"name": tr(GameState.hearing["accused"])})))
		return
	suspect = npc
	var accused: String = npc.data.npc_name
	var args := {"name": tr(accused), "day": hearing.day_if_called_now(), "left": GameState.MAX_HEARINGS - GameState.hearings_held}
	_show(Mode.CONFIRM, Lang.contract(tr("Call a hearing against {name}?").format(args)),
		Lang.contract(tr("At 7 PM on Day {day} the town will gather at the Town Hall. You will present your evidence and call witnesses, then the town will vote.\nWord travels fast: {name} will know. Hearings left: {left}.").format(args)),
		tr("[E] Call the hearing      [Esc] Cancel"))


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
	mode = Mode.HIDDEN
	panel.visible = false
	get_tree().paused = false
	var accused: String = suspect.data.npc_name
	var day := hearing.day_if_called_now()
	GameState.hearing = {"accused": accused, "day": day}
	Playtest.count("hearings_called")
	var args := {"name": tr(accused), "day": day}
	GameState.add_clue(Lang.contract(tr("Day {day} · You called a hearing against {name}, at 7 PM at the Town Hall.").format(args)), "evidence")
	EventBus.dialogue_started.emit("Doctor", Lang.contract(tr("The hearing against {name} is set: Day {day}, 7 PM, at the Town Hall. Gather what you can until then.").format(args)))
