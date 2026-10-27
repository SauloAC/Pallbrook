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
	["rest", "You need rest and good food."],
	["chat", "How are things?"],
	["bye", "Goodbye."],
]
const SELECTED_COLOR := Color("C2A65B")
const ASKED_ALPHA := 0.5

var opened_frame := -1
var npc: Node = null  # Who we are talking to (null = a plain message, like examining a body)
var choice := 0
var choices_box: VBoxContainer
var questions: Array = []  # This conversation's list (the tonic shows up at the clinic)
var busy := false          # The exam hour is passing: keys wait
var veil: ColorRect        # Covers the screen while it does

const EXAM_HOURS := 1.0
const EXAM_PAUSE := 2.2    # Seconds of dark, with the heartbeat


# Asked to come to the clinic: when
const CLINIC_WHEN := [
	["clinic_today", "Today, as soon as you can."],
	["clinic_tomorrow", "Tomorrow morning."],
	["clinic_back", "Never mind."],
]
var picking_when := false


const CONSULT_QUESTIONS := [
	["exam", "Let me examine you."],
	["tonic", "Give the iron tonic."],
	["rest", "You need rest and good food."],
	["bye", "Goodbye."],
]


# The list changes as the talk goes on: a patient waiting at the clinic gets a consultation,
# and rest is only offered once the doctor has examined them today
func _questions_for(who: Node) -> Array:
	if picking_when:
		var when: Array = []
		for q in CLINIC_WHEN:
			if q[0] == "clinic_today" and not who.clinic_today_possible():
				continue
			when.append(q)
		return when
	var consult: bool = who.has_method("awaiting_treatment") and who.awaiting_treatment()
	var examined: bool = who.has_method("examined_today") and who.examined_today()
	var list: Array = []
	for q in (CONSULT_QUESTIONS if consult else QUESTIONS):
		if q[0] == "rest" and not examined:
			continue
		list.append(q)
	return list


func _ready() -> void:
	panel.visible = false
	veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.visible = false
	add_child(veil)  # Last child: drawn over the panel
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
	hint.text = tr("[E] Close")


func _on_conversation_started(who: Node) -> void:
	npc = who
	picking_when = false
	questions = _questions_for(who)
	choice = 0
	_open(who.data.npc_name, who.greeting())
	choices_box.visible = true
	hint.text = tr("[W/S] Navigate    [E] Ask/Select    [Esc] Leave")
	_refresh_choices()


func _open(speaker_name: String, line: String) -> void:
	speaker.text = tr(speaker_name)  # Names and titles (Doctor, Bed...) in the current language
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
	for i in questions.size():
		var key: String = questions[i][0]
		var label := Label.new()
		label.text = ("» " if i == choice else "   ") + tr(questions[i][1])
		label.add_theme_font_size_override("font_size", 20)
		if i == choice:
			label.add_theme_color_override("font_color", SELECTED_COLOR)
		elif key != "bye" and not key.begins_with("clinic_") and npc.was_asked(key):
			label.modulate.a = ASKED_ALPHA  # Already asked today
		choices_box.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the same key press that opened the box
	if not panel.visible or Engine.get_process_frames() == opened_frame:
		return
	if busy:
		get_viewport().set_input_as_handled()
		return
	if npc == null:
		if event.is_action_pressed("interact"):
			_close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		choice = wrapi(choice - 1, 0, questions.size())
		Audio.play("click", -10.0)
		_refresh_choices()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		choice = wrapi(choice + 1, 0, questions.size())
		Audio.play("click", -10.0)
		_refresh_choices()
	elif event.is_action_pressed("interact"):
		_ask(questions[choice][0])
	elif event.is_action_pressed("ui_cancel"):
		if picking_when:
			_ask("clinic_back")
		else:
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
			if not GameState.is_night and npc.can_examine():
				await _exam_hour()
			if npc == null:
				return  # The talk was closed meanwhile (night fell, the doctor collapsed)
			body.text = npc.answer_exam()
		"clinic":
			var no: String = npc.clinic_refusal()
			if no != "":
				body.text = no
			else:
				picking_when = true
				body.text = tr("When should I come, doctor?")
		"clinic_today", "clinic_tomorrow":
			picking_when = false
			body.text = npc.answer_clinic(key == "clinic_tomorrow")
			key = "clinic"
		"clinic_back":
			picking_when = false
			key = "clinic"
		"rest":
			body.text = npc.answer_rest()
		"tonic":
			body.text = npc.answer_tonic()
		"chat":
			body.text = npc.answer_chat()
		"bye":
			_close()
			return
	# Rebuild the list (exam unlocks rest, treatment ends the consultation), keeping the cursor on the same question
	questions = _questions_for(npc)
	choice = 0
	for i in questions.size():
		if questions[i][0] == key:
			choice = i
	_refresh_choices()


# A proper exam takes an hour: the screen goes dark, a heartbeat through the stethoscope,
# the clock moves on, and the talk comes back with the findings
func _exam_hour() -> void:
	busy = true
	body.text = "..."
	veil.visible = true
	var tween := create_tween()
	tween.tween_property(veil, "color:a", 1.0, 0.5)
	await tween.finished
	Audio.play("exam", -4.0)
	await get_tree().create_timer(EXAM_PAUSE).timeout
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle:
		cycle.advance_clock(EXAM_HOURS)
	tween = create_tween()
	tween.tween_property(veil, "color:a", 0.0, 0.5)
	await tween.finished
	veil.visible = false
	busy = false


func _close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	npc = null
	picking_when = false
	GameState.in_dialogue = false
	EventBus.dialogue_ended.emit()


func _find_portrait(speaker_name: String) -> Texture2D:
	for person in get_tree().get_nodes_in_group("npcs"):
		if person.data and person.data.npc_name == speaker_name:
			return person.data.portrait
	return null
