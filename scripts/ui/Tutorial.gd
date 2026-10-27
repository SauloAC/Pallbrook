class_name Tutorial
extends CanvasLayer

# The guided first day (see the design doc: "O Dia 1 vira um tutorial de chegada guiado").
# One small task at a time in the top-right corner. Each one is checked by watching the game
# (nothing else has to report to it), so doing things out of order just ticks them off.
# Night 1 is quiet (the vampire fed on Jonas the week before), so there is time to learn.
# Shown once per session; F1 skips it.

const STEPS := [
	["sheet", "Your predecessor left something for you here in the clinic. Look around and pick it up (E)."],
	["read", "Open your casebook (Tab), go to the Diary bookmark and click the first sheet to read his letter."],
	["talk", "Go into town. Talk to someone (E) and ask how things are."],
	["exam", "Examine someone: talk to them and choose \"Let me examine you\". Note the pulse, the colour and the neck."],
	["chart", "Open the casebook on Patients and click that person: their chart keeps every exam."],
	["clinic", "Anyone weak? Ask them to come to the clinic for a treatment. You have one tonic; the Supplies bookmark explains how to make more."],
	["mural", "At the clinic, study the map on the back wall (E). Every case in town gets pinned there."],
	["night", "Night falls at 6 PM. Watch the streets if you dare, but be back at the clinic before 1 AM and sleep in your bed (E)."],
	["alibi", "A new day. Ask people where they were last night: their answers fill the Nights bookmark, where you can compare them."],
	["done", "From here on you are on your own. When you are sure who it is, call a hearing (Q)."],
]
const NIGHT_STEP := 7
const DONE_SHOWN := 12.0   # Seconds the last note stays up
const CHECK_EVERY := 0.25

var step := 0
var panel: PanelContainer
var heading: Label
var body: Label
var footer: Label
var timer := 0.0
var done_timer := 0.0
var slept := false


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS  # Hides itself under the title screen and pauses
	if GameState.tutorial_done:
		return
	_build()
	EventBus.player_slept.connect(_on_slept)
	_show_step()


func _build() -> void:
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.82)
	style.border_color = Color(0.76, 0.65, 0.36, 0.8)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -380.0
	panel.offset_right = -14.0
	panel.offset_top = 14.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45))
	box.add_child(heading)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 340.0
	body.add_theme_font_size_override("font_size", 17)
	box.add_child(body)
	footer = Label.new()
	footer.add_theme_font_size_override("font_size", 13)
	footer.modulate = Color(1, 1, 1, 0.55)
	footer.text = tr("[F1] Skip the tutorial")
	box.add_child(footer)


func _show_step() -> void:
	heading.text = tr("First day · {n} of {total}").format({"n": step + 1, "total": STEPS.size()})
	body.text = tr(STEPS[step][1])
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)


func _on_slept() -> void:
	slept = true


func _process(delta: float) -> void:
	if GameState.tutorial_done or panel == null:
		return
	# Out of the way while reading, talking or at a pause screen
	panel.visible = GameState.intro_seen and not GameState.reading and not get_tree().paused
	if get_tree().paused:
		return
	if STEPS[step][0] == "done":
		done_timer += delta
		if done_timer > DONE_SHOWN:
			_finish()
		return
	timer += delta
	if timer < CHECK_EVERY:
		return
	timer = 0.0
	# Nightfall skips whatever daytime steps are left
	if GameState.is_night and step < NIGHT_STEP:
		_advance_to(NIGHT_STEP)
		return
	if _step_done(STEPS[step][0]):
		Audio.play("page", -10.0)
		_advance_to(step + 1)


func _advance_to(next: int) -> void:
	step = next
	Playtest.log_line("Tutorial step %d" % step)
	_show_step()


func _step_done(key: String) -> bool:
	match key:
		"sheet":
			return Diary.is_found("1W")
		"read":
			var book = get_tree().get_first_node_in_group("casebook")  # Untyped: Notebook has no class_name
			return book != null and book.diary_layer.visible and book.diary_sheet == 1
		"talk":
			return _anyone(func(npc): return npc.asked.has("chat"))
		"exam":
			return _anyone(func(npc): return not npc.exams.is_empty())
		"chart":
			var book = get_tree().get_first_node_in_group("casebook")  # Untyped: Notebook has no class_name
			return book != null and book.chart_layer.visible
		"clinic":
			return not GameState.appointments.is_empty() or GameState.tonics_ordered > 0
		"mural":
			var board = get_tree().get_first_node_in_group("mural")
			return board != null and board.is_open
		"night":
			return slept or GameState.day >= 2 and not GameState.is_night
		"alibi":
			return _anyone(func(npc): return npc.asked.get("alibi", 0) >= 2)
	return false


func _anyone(test: Callable) -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and test.call(npc):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if GameState.tutorial_done or panel == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		Playtest.log_line("Tutorial skipped at step %d" % step)
		_finish()


func _finish() -> void:
	GameState.tutorial_done = true
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)
