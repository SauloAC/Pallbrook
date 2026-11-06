class_name RecordBook
extends Node3D

# The town's books (see the design doc, "Registros da cidade"). The past they hold is written at
# the start of each run by TownHistory, to fit whoever the vampire is.
# - "hall": the Town Hall register on the clerk's desk. Deaths and who came to live here when.
#   Two hours, while the hall is open. Wrote the first pale death down as a fever.
# - "church": Father Elias's burial book, on the lectern. Only once he trusts the doctor
#   (or once he is gone). One hour. His notes show every pale death, the first one too.
# The first reading costs the hours and copies what matters into the casebook; after that the
# book opens again for free.

const ICON := preload("res://assets/ui/icon_examine.png")
const BOOKS := {
	"hall": {"at": Vector3(12.46, 0.0, -9.25), "use": Vector3(12.46, 0.0, -8.55), "hours": 2.0, "opens": 9.0, "closes": 17.0},
	"church": {"at": Vector3(-4.96, 0.0, -2.93), "use": Vector3(-5.3, 0.0, -2.3), "hours": 1.0, "opens": 7.0, "closes": 18.0},
}
const USE_RANGE := 1.0
const PRIEST := "Elias"
const CHURCH_TRUST := 60.0

var kind := "hall"
var prompt: Sprite3D
var panel: CanvasLayer
var title_label: Label
var body_label: Label
var page_label: Label
var pages: Array[Dictionary] = []   # {title, text}
var page := 0
var is_open_ui := false
var opened_frame := -1


func _ready() -> void:
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	add_child(prompt)
	prompt.global_position = BOOKS[kind]["at"] + Vector3(0.0, 2.0, 0.0)
	_build_panel()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap: Vector3 = player.global_position - BOOKS[kind]["use"]
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	prompt.visible = near and not GameState.in_dialogue and not GameState.reading and not is_open_ui


func _try_open(event: InputEvent) -> void:
	# Test shortcut, only when run from the editor: F9 makes Father Elias trust the doctor
	if kind == "church" and OS.has_feature("editor") and event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_F9:
		var priest = _priest()
		if priest:
			priest.affinity = 100.0
			print("[DEBUG] Elias trusts the doctor (affinity 100)")
		return
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	# Handled before the doctor's own E (talking): someone standing by the book doesn't get in the way
	get_viewport().set_input_as_handled()
	if GameState.history.is_empty():
		return
	if GameState.records_read.has(kind):
		_open_ui()
		return
	var book: Dictionary = BOOKS[kind]
	if GameState.is_night or GameState.hour < book["opens"] or GameState.hour + book["hours"] > book["closes"]:
		var text := tr("The Town Hall register: births, deaths, who came to live here and when. Going through it properly would take about two hours. Come back while the hall is open, before 3 PM.") if kind == "hall" \
				else tr("The church's burial book. Reading it with care would take about an hour. Come back during the day.")
		EventBus.dialogue_started.emit("Doctor", text)
		return
	if kind == "church":
		var refusal := _church_refusal()
		if refusal != "":
			if _priest_nearby():
				EventBus.dialogue_started.emit(PRIEST, refusal)
			else:  # He isn't here to say so: the book is simply locked away
				EventBus.dialogue_started.emit("Doctor", tr("The burial book is locked in the vestry. Only Father Elias has the key."))
			return
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle == null:
		return
	Playtest.count("records_read_" + kind)
	await cycle.pass_hours(book["hours"], "", _first_read)
	_open_ui()


# Elias keeps the book from a stranger, the same way whether or not he is the vampire (a different
# excuse would give him away on a second playthrough). As the vampire he still shows it once he
# trusts the doctor, but his notes on the pale dead are harmless ones: next to the Town Hall's
# "anemia", that is the clue.
func _church_refusal() -> String:
	var priest = _priest()  # Untyped: NPC methods
	if priest == null or not priest.is_alive():
		return ""  # Nobody guards it any more: it lies open on the lectern
	if priest.affinity < CHURCH_TRUST:
		return tr("Those are the town's dead, doctor. I keep their book locked in the vestry. After what was done to the Town Hall register, I have to be careful with these records. It is still too early to show them to you.")
	return ""


func _note_for(d: Dictionary, index: int) -> String:
	if GameState.vampire_name == PRIEST and d["pale"] and d["name"] != "Jonas":
		return TownHistory.PLAIN_NOTES[index % TownHistory.PLAIN_NOTES.size()]
	return d["note"]


func _priest_nearby() -> bool:
	var priest = _priest()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return priest != null and player != null and not priest.in_bed \
			and priest.global_position.distance_to(player.global_position) < 6.0


func _priest() -> Node:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == PRIEST:
			return npc
	return null


# What the doctor copies into the casebook on his first reading
func _first_read() -> void:
	GameState.records_read[kind] = GameState.day
	var history: Dictionary = GameState.history
	if kind == "hall":
		for d: Dictionary in history["deaths"]:
			if d["cause"] in ["anemia", "weakness of the blood"]:
				GameState.add_clue(tr("Town records: {name} died in {year}. Cause written down: {cause}.").format(
						{"name": d["name"], "year": d["year"], "cause": tr(d["cause"])}), "evidence")
		for person: String in history["people"]:
			GameState.add_clue(tr("Town records: {line}").format({"line": _resident_line(person, history["people"][person])}), "evidence")
	else:
		var deaths: Array = history["deaths"]
		for i in deaths.size():
			var d: Dictionary = deaths[i]
			if d["pale"] and d["name"] != "Jonas":
				GameState.add_clue(tr("Church book: {name}, buried in {year}. Father Elias wrote: \"{note}\"").format(
						{"name": d["name"], "year": d["year"], "note": tr(_note_for(d, i))}), "evidence")


func _resident_line(person: String, entry: Dictionary) -> String:
	var who := tr(person)
	var line := ""
	match String(entry["kind"]):
		"arrived":
			line = tr("{name} came to live in Pallbrook in {year}.").format({"name": who, "year": entry["year"]})
		"returned":
			line = tr("{name} was born in Pallbrook, left in {left} and came back in {year}.").format({"name": who, "left": entry["left"], "year": entry["year"]})
		_:
			line = tr("{name} was born in Pallbrook.").format({"name": who})
	return line


# ---------- The open book ----------

func _fill_pages() -> void:
	pages.clear()
	var history: Dictionary = GameState.history
	if kind == "hall":
		var lines := PackedStringArray([tr("The pages before {year} have been torn out.").format({"year": TownHistory.RECORDS_FROM}), ""])
		for d: Dictionary in history["deaths"]:
			lines.append("%d  ·  %s  ·  %s" % [d["year"], d["name"], tr(d["cause"])])
		pages.append({"title": tr("Deaths"), "text": "\n".join(lines)})
		lines = PackedStringArray()
		var names: Array = history["people"].keys()
		names.sort()
		for person: String in names:
			lines.append(_resident_line(person, history["people"][person]))
		lines.append("")
		lines.append(tr("{doctor} took up the town practice in {year}.").format({"doctor": TownHistory.OLD_DOCTOR, "year": TownHistory.DOCTOR_CAME}))
		pages.append({"title": tr("Residents"), "text": "\n".join(lines)})
	else:
		var lines := PackedStringArray()
		var deaths: Array = history["deaths"]
		for i in deaths.size():
			var d: Dictionary = deaths[i]
			lines.append("%d  ·  %s" % [d["year"], d["name"]])
			lines.append("      “%s”" % tr(_note_for(d, i)))
		pages.append({"title": tr("Burials"), "text": "\n".join(lines)})


func _build_panel() -> void:
	panel = CanvasLayer.new()
	panel.layer = 20
	panel.visible = false
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.88, 0.76)       # Old paper
	style.border_color = Color(0.36, 0.24, 0.14)   # Leather binding
	style.set_border_width_all(10)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(34)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	var ink := Color(0.16, 0.11, 0.08)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", ink)
	box.add_child(title_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 19)
	body_label.add_theme_color_override("font_color", ink)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(740, 0)
	scroll.add_child(body_label)
	page_label = Label.new()
	page_label.add_theme_font_size_override("font_size", 16)
	page_label.add_theme_color_override("font_color", Color(ink, 0.7))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(page_label)


func _open_ui() -> void:
	_fill_pages()
	page = 0
	is_open_ui = true
	opened_frame = Engine.get_process_frames()
	GameState.in_dialogue = true
	panel.visible = true
	Audio.play("page", -8.0)
	_show_page()


func _show_page() -> void:
	var book_title := tr("Town Hall register") if kind == "hall" else tr("Church burial book")
	title_label.text = book_title + "  ·  " + String(pages[page]["title"])
	body_label.text = pages[page]["text"]
	var hint := tr("[Esc] Close")
	if pages.size() > 1:
		hint = tr("Page {n} of {total}").format({"n": page + 1, "total": pages.size()}) + "    " + tr("[A/D] Turn the page    [Esc] Close")
	page_label.text = hint


func _close_ui() -> void:
	is_open_ui = false
	panel.visible = false
	GameState.in_dialogue = false


func _input(event: InputEvent) -> void:
	if not is_open_ui:
		_try_open(event)
		return
	if Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if page > 0:
			page -= 1
			Audio.play("page", -10.0)
			_show_page()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		if page < pages.size() - 1:
			page += 1
			Audio.play("page", -10.0)
			_show_page()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close_ui()
	else:
		return
	get_viewport().set_input_as_handled()
