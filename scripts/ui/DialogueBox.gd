extends CanvasLayer

@onready var panel: Control = $Panel
@onready var speaker: Label = $Panel/HBox/VBox/Speaker
@onready var body: Label = $Panel/HBox/VBox/Body
@onready var portrait: TextureRect = $Panel/HBox/Portrait
@onready var hint: Label = $Panel/HBox/VBox/Hint

# What the doctor can ask a living townsperson
const QUESTIONS := [
	["alibi", "Where were you last night?"],
	["seen", "Did you see anything unusual last night?"],
	["exam", "Let me examine you."],
	["clinic", "Come to the clinic for a treatment."],
	["chat", "How are things?"],
	["bye", "Goodbye."],
]
const SELECTED_COLOR := Color("C2A65B")
const ASKED_ALPHA := 0.5

var opened_frame := -1
var npc: Node = null  # Who we are talking to (null = a plain message, like examining a body)
var choice := 0
var choices_box: VBoxContainer


func _ready() -> void:
	panel.visible = false
	# The list of questions is built in code, right above the hint
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 2)
	var vbox := $Panel/HBox/VBox
	vbox.add_child(choices_box)
	vbox.move_child(choices_box, hint.get_index())
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.conversation_started.connect(_on_conversation_started)
	EventBus.player_slept.connect(_close)
	EventBus.player_collapsed.connect(_close)


func _on_dialogue_started(speaker_name: String, line: String) -> void:
	npc = null
	_open(speaker_name, line)
	choices_box.visible = false
	hint.text = "[E] Close"


func _on_conversation_started(who: Node) -> void:
	npc = who
	choice = 0
	_open(who.data.npc_name, who.greeting())
	choices_box.visible = true
	hint.text = "[W/S] Choose    [E] Ask    [Esc] Leave"
	_refresh_choices()


func _open(speaker_name: String, line: String) -> void:
	speaker.text = speaker_name
	body.text = line
	panel.visible = true
	GameState.in_dialogue = true
	opened_frame = Engine.get_process_frames()
	var tex := _find_portrait(speaker_name)
	portrait.texture = tex
	portrait.visible = tex != null


func _refresh_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	for i in QUESTIONS.size():
		var key: String = QUESTIONS[i][0]
		var label := Label.new()
		label.text = ("» " if i == choice else "   ") + QUESTIONS[i][1]
		label.add_theme_font_size_override("font_size", 20)
		if i == choice:
			label.add_theme_color_override("font_color", SELECTED_COLOR)
		elif key != "bye" and npc.was_asked(key):
			label.modulate.a = ASKED_ALPHA  # Already asked today
		choices_box.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the same key press that opened the box
	if not panel.visible or Engine.get_process_frames() == opened_frame:
		return
	if npc == null:
		if event.is_action_pressed("interact"):
			_close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		choice = wrapi(choice - 1, 0, QUESTIONS.size())
		_refresh_choices()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		choice = wrapi(choice + 1, 0, QUESTIONS.size())
		_refresh_choices()
	elif event.is_action_pressed("interact"):
		_ask(QUESTIONS[choice][0])
	elif event.is_action_pressed("ui_cancel"):
		_close()
	else:
		return
	get_viewport().set_input_as_handled()


func _ask(key: String) -> void:
	match key:
		"alibi":
			body.text = npc.answer_alibi()
		"seen":
			body.text = npc.answer_seen()
		"exam":
			body.text = npc.answer_exam()
		"clinic":
			body.text = npc.answer_clinic()
		"chat":
			body.text = npc.answer_chat()
		"bye":
			_close()
			return
	_refresh_choices()


func _close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	npc = null
	GameState.in_dialogue = false
	EventBus.dialogue_ended.emit()


func _find_portrait(speaker_name: String) -> Texture2D:
	for person in get_tree().get_nodes_in_group("npcs"):
		if person.data and person.data.npc_name == speaker_name:
			return person.data.portrait
	return null
