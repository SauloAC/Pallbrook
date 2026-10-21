extends CanvasLayer

# The casebook. Left page: entries, filtered. Right page: suspects (click one to
# see only what involves them). Filters: All, Evidence, or one person.

@onready var panel: Control = $Panel
@onready var title: Label = $Panel/Pages/VBox/Title
@onready var scroll: ScrollContainer = $Panel/Pages/VBox/Scroll
@onready var entries: Label = $Panel/Pages/VBox/Scroll/Entries
@onready var suspect_list: VBoxContainer = $Panel/Pages/Suspects/List

const INK := Color("2C2621")
const INK_FADED := Color(0.17, 0.15, 0.13, 0.45)
const ALL := ""
const EVIDENCE := "#evidence"
const APPOINTMENTS := "#appointments"
const CHART_PICK := "#chart"  # Waiting for the player to pick whose chart to open

var filter := ALL  # ALL, EVIDENCE or a person's name
const PER_PAGE := 9  # 3x3 grid; more townsfolk spill onto extra pages
var townsfolk_page := 0
var filter_bar: HBoxContainer

# ---------- Patient chart ----------
const CHART := preload("res://assets/ui/patient_chart.png")
const CHART_SIZE := Vector2(994, 1400)  # Positions below are in the chart image's pixels
const PHOTO_RECT := Rect2(104, 120, 220, 296)
const LINE_X := 410.0
const TOP_LINES := [153, 207, 261, 314, 368, 422]
const BOX_RECTS := [Rect2(82, 558, 190, 69), Rect2(298, 558, 189, 69), Rect2(514, 558, 189, 69), Rect2(729, 558, 189, 69)]
const BLOOD_BAR := Rect2(250, 694, 580, 44)        # Classic blood bar (a thermometer read as body heat)
const BLOOD_DROP := preload("res://assets/ui/chart/blood_drop.png")
const BITE := preload("res://assets/ui/chart/bite_marks.png")
const WRIST_NOTE := preload("res://assets/ui/chart/wrist_note.png")  # Close-up pinned under the clip
const CLIP := preload("res://assets/ui/chart/chart_clip.png")
const WRIST_NOTE_POS := Vector2(690, 40)
const CLIP_POS := Vector2(790, 0)
const BITE_RECT := Rect2(266, 1152, 66, 51)          # On the side of the neck sketch
const NOTE_X := 474.0
const NOTE_LINES := [861, 913, 965, 1018, 1070, 1123, 1175, 1227, 1280]
const BLOOD_RED := Color(0.48, 0.07, 0.07)

var chart_layer: Control
var sheet: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the game is paused
	panel.visible = false
	# Filter buttons, built in code right under the title
	filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 14)
	var vbox: VBoxContainer = $Panel/Pages/VBox
	vbox.add_child(filter_bar)
	vbox.move_child(filter_bar, title.get_index() + 1)
	_layout_book(vbox)
	# The right page lists everyone the doctor looks after
	for child in $Panel/Pages/Suspects.get_children():
		if child is Label:
			child.text = "Patients"
			break
	_build_chart_layer()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("notebook"):
		return
	if chart_layer.visible:
		chart_layer.visible = false  # Back to the casebook first
	elif panel.visible:
		_close()
	elif not GameState.in_dialogue and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	_refresh()
	panel.visible = true
	Audio.play("book_open", -4.0)
	get_tree().paused = true  # Time stops while reading


func _close() -> void:
	panel.visible = false
	Audio.play("book_close", -4.0)
	get_tree().paused = false


func _set_filter(value: String) -> void:
	if filter == CHART_PICK and _is_person(value):
		filter = value
		_refresh()
		_open_chart(value)
		return
	# Clicking the active person again goes back to everything
	filter = ALL if value == filter and value != ALL else value
	Audio.play("page", -6.0)
	_refresh()


func _refresh() -> void:
	_build_filter_bar()
	_build_suspects()
	_build_entries()


# ---------- Book layout ----------

const BOOK_SIZE := Vector2(1000, 560)   # Fixed size, so content never stretches the book
const PAGE_MARGIN := 100.0              # Keeps text off the burnt, worn edges
const FOLD_GUTTER := 70.0               # Empty band over the fold

func _layout_book(left_page: Control) -> void:
	# Same margin on both outer edges and two equal pages: the fold falls exactly between them
	var book := panel as PanelContainer
	var style := book.get_theme_stylebox("panel").duplicate() as StyleBoxTexture
	style.content_margin_left = PAGE_MARGIN
	style.content_margin_right = PAGE_MARGIN
	style.content_margin_top = 46.0
	style.content_margin_bottom = 40.0
	book.add_theme_stylebox_override("panel", style)
	book.custom_minimum_size = BOOK_SIZE
	book.offset_left = -BOOK_SIZE.x / 2.0
	book.offset_right = BOOK_SIZE.x / 2.0
	book.offset_top = -BOOK_SIZE.y / 2.0
	book.offset_bottom = BOOK_SIZE.y / 2.0
	var pages: HBoxContainer = $Panel/Pages
	var right_page: Control = $Panel/Pages/Suspects
	pages.add_theme_constant_override("separation", int(FOLD_GUTTER))
	var page_width := (BOOK_SIZE.x - 2.0 * PAGE_MARGIN - FOLD_GUTTER) / 2.0
	for page: Control in [left_page, right_page]:
		page.custom_minimum_size.x = page_width
		page.size_flags_horizontal = Control.SIZE_FILL
	entries.custom_minimum_size.x = page_width - 20.0  # Room for the scrollbar


# ---------- Left page ----------

func _build_filter_bar() -> void:
	_clear(filter_bar)
	filter_bar.add_child(_link("All", ALL))
	filter_bar.add_child(_link("Clinic", EVIDENCE))
	filter_bar.add_child(_link("Appointments", APPOINTMENTS))
	# Patient chart is always there: opens the selected patient, or asks you to pick one
	var chart_link := _link("Patient chart", CHART_PICK)
	if _is_person(filter):
		chart_link.add_theme_color_override("font_color", BLOOD_RED)
	for connection in chart_link.gui_input.get_connections():
		chart_link.gui_input.disconnect(connection["callable"])
	chart_link.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_chart_link.call_deferred())
	filter_bar.add_child(chart_link)


func _is_person(value: String) -> bool:
	return value not in [ALL, EVIDENCE, APPOINTMENTS, CHART_PICK]


func _on_chart_link() -> void:
	if _is_person(filter):
		_open_chart(filter)
	else:
		filter = CHART_PICK
		Audio.play("page", -6.0)
		_refresh()


func _link(text: String, value: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK if filter == value else INK_FADED)
	if filter == value:
		label.text = "» " + text
	_make_clickable(label, value)
	return label


func _build_entries() -> void:
	if filter == APPOINTMENTS:
		_build_appointments()
		return
	if filter == CHART_PICK:
		title.text = "Patient chart"
		entries.text = "Choose a patient on the right page to open their chart."
		scroll.scroll_vertical = 0
		return
	match filter:
		ALL:
			title.text = "Casebook"
		EVIDENCE:
			title.text = "Clinic"
		_:
			title.text = filter

	var lines: Array[String] = []
	var last_day := -1
	for entry in GameState.entries:
		if not _matches(entry):
			continue
		if entry["day"] != last_day:
			last_day = entry["day"]
			lines.append("— Day %d —" % last_day)
		lines.append("• " + entry["text"])

	if lines.is_empty():
		entries.text = "Nothing about %s yet." % filter if filter not in [ALL, EVIDENCE] else "Nothing yet."
	else:
		entries.text = "\n\n".join(PackedStringArray(lines))
	scroll.scroll_vertical = 0


func _build_appointments() -> void:
	# Who needs the doctor today, then every clinic visit, newest first
	title.text = "Appointments"
	var lines: Array[String] = []
	var urgent: Array[String] = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_alive() and npc.marked and npc.talked_day >= npc.marked_day:
			urgent.append("• %s · visited at night: treat today, or keep watch at the door tonight" % npc.data.npc_name)
	if not urgent.is_empty():
		lines.append("— Urgent —")
		lines.append_array(urgent)
	var last_day := -1
	for i in range(GameState.appointments.size() - 1, -1, -1):
		var a: Dictionary = GameState.appointments[i]
		if a["day"] != last_day:
			last_day = a["day"]
			lines.append("— Today —" if last_day == GameState.day else "— Day %d —" % last_day)
		var status := "expected at the clinic"
		match a["status"]:
			"treated":
				status = "treated"
			"missed":
				status = "missed"
			"absent":
				status = "absent"
			"no tonic":
				status = "no tonic"
		lines.append("• %s · %s – %s · %s" % [a["name"], GameState.format_time(a["from"]), GameState.format_time(a["until"]), status])
	if lines.is_empty():
		entries.text = "No appointments yet.\n\nAsk a sick patient to come to the clinic for a treatment."
	else:
		entries.text = "\n\n".join(PackedStringArray(lines))
	scroll.scroll_vertical = 0


func _matches(entry: Dictionary) -> bool:
	match filter:
		ALL:
			return true
		EVIDENCE:
			return entry["kind"] == "evidence"
	return filter in entry["people"]  # A person's name


# ---------- Right page ----------

func _build_suspects() -> void:
	_clear(suspect_list)
	# Small cards in three columns: portrait, name, role underneath
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Centered on the right page
	suspect_list.add_child(grid)
	# Alphabetical, nine per page
	var people := get_tree().get_nodes_in_group("npcs").filter(func(n): return n.data != null)
	people.sort_custom(func(a, b): return a.data.npc_name.naturalnocasecmp_to(b.data.npc_name) < 0)
	var page_count := maxi(1, ceili(people.size() / float(PER_PAGE)))
	townsfolk_page = clampi(townsfolk_page, 0, page_count - 1)
	for npc in people.slice(townsfolk_page * PER_PAGE, (townsfolk_page + 1) * PER_PAGE):
		var name_text: String = npc.data.npc_name
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 0)
		card.custom_minimum_size.x = 104

		var pic := TextureRect.new()
		pic.texture = npc.data.portrait
		pic.custom_minimum_size = Vector2(72, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)

		var label := Label.new()
		label.text = ("» " if filter == name_text else "") + name_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 17)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)

		var role := Label.new()
		role.text = npc.data.role + ("" if npc.is_alive() else " · deceased")
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.add_theme_color_override("font_color", Color(0.17, 0.15, 0.13, 0.7))
		role.add_theme_font_size_override("font_size", 13)
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(role)

		if not npc.is_alive():
			card.modulate = Color(1, 1, 1, 0.45)  # Faded: no longer a suspect
		elif _is_person(filter) and filter != name_text:
			card.modulate = Color(1, 1, 1, 0.7)   # Someone else is selected

		_make_clickable(card, name_text)
		grid.add_child(card)

	if page_count > 1:
		suspect_list.add_child(_page_turner(page_count))


func _page_turner(page_count: int) -> HBoxContainer:
	# "‹  2 / 3  ›" under the grid: flips to the next set of townsfolk
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	var prev := _turn_arrow("‹", -1, townsfolk_page > 0)
	var count := Label.new()
	count.text = "%d / %d" % [townsfolk_page + 1, page_count]
	count.add_theme_color_override("font_color", INK)
	count.add_theme_font_size_override("font_size", 16)
	var next := _turn_arrow("›", 1, townsfolk_page < page_count - 1)
	bar.add_child(prev)
	bar.add_child(count)
	bar.add_child(next)
	return bar


func _turn_arrow(symbol: String, step: int, enabled: bool) -> Label:
	var arrow := Label.new()
	arrow.text = symbol
	arrow.add_theme_font_size_override("font_size", 30)
	arrow.add_theme_color_override("font_color", INK if enabled else INK_FADED)
	if enabled:
		arrow.mouse_filter = Control.MOUSE_FILTER_STOP
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		arrow.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				townsfolk_page += step
				_build_suspects.call_deferred())
	return arrow


# ---------- Helpers ----------

func _make_clickable(control: Control, value: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_filter.call_deferred(value))  # Deferred: the clicked row is rebuilt


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ---------- Patient chart ----------

func _build_chart_layer() -> void:
	chart_layer = Control.new()
	chart_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	chart_layer.visible = false
	add_child(chart_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			chart_layer.visible = false)  # Click outside the card to close it
	chart_layer.add_child(dim)
	sheet = Control.new()
	sheet.size = CHART_SIZE
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	chart_layer.add_child(sheet)


func _open_chart(npc_name: String) -> void:
	var npc: Node = null
	for person in get_tree().get_nodes_in_group("npcs"):
		if person.data and person.data.npc_name == npc_name:
			npc = person
	if npc == null:
		return
	_clear(sheet)
	# Fit the card to 92% of the screen height, centered
	var view := get_viewport().get_visible_rect().size
	var s := view.y * 0.92 / CHART_SIZE.y
	sheet.scale = Vector2(s, s)
	sheet.position = (view - CHART_SIZE * s) / 2.0

	var paper := TextureRect.new()
	paper.texture = CHART
	paper.size = CHART_SIZE
	sheet.add_child(paper)

	var photo := TextureRect.new()
	photo.texture = npc.data.portrait
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.position = PHOTO_RECT.position
	photo.size = PHOTO_RECT.size
	photo.clip_contents = true
	if not npc.is_alive():
		photo.modulate = Color(0.6, 0.6, 0.6)
	sheet.add_child(photo)

	var exams: Array = npc.exams
	var last: Dictionary = exams[-1] if not exams.is_empty() else {}
	var title_font := title.get_theme_font("font")

	# Header lines
	_line_text(npc.data.npc_name, LINE_X, TOP_LINES[0], 44, title_font)
	_line_text(npc.data.role, LINE_X, TOP_LINES[1], 30)
	if not npc.is_alive():
		_line_text("Deceased" + (" · buried" if npc.buried else ""), LINE_X, TOP_LINES[2], 30, null, BLOOD_RED)
	elif last.is_empty():
		_line_text("Not examined yet", LINE_X, TOP_LINES[2], 30)
	else:
		var age: int = GameState.day - int(last["day"])
		var when := "today" if age == 0 else ("yesterday" if age == 1 else "%d days ago" % age)
		_line_text("Last examined %s (Day %d)" % [when, last["day"]], LINE_X, TOP_LINES[2], 30)
	if not last.is_empty() and last["trace"] != "":
		_line_text("Traces: %s" % last["trace"], LINE_X, TOP_LINES[3], 28)
	if not last.is_empty() and last["old_marks"]:
		_line_text("Old, healed punctures", LINE_X, TOP_LINES[4], 28, null, BLOOD_RED)
	elif npc.is_alive() and npc.marked and npc.talked_day >= npc.marked_day:
		_line_text("Visited at night: treat today!", LINE_X, TOP_LINES[4], 28, null, BLOOD_RED)
	if npc.is_alive():
		_line_text(npc.trust_word(), LINE_X, TOP_LINES[5], 28)

	# Vital signs boxes: pulse, temperature, appearance, sleep
	var values := ["—", "—", "—", "—"]
	if not last.is_empty():
		values = [last["pulse"], last["temp"], last["look"], last.get("sleep", "—")]
	for i in 4:
		var box: Rect2 = BOX_RECTS[i]
		var label := _label(values[i], 28 if str(values[i]).length() <= 11 else 23)  # Long words shrink to fit
		label.position = box.position
		label.size = box.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sheet.add_child(label)

	# Blood left: a classic bar with a label and a percentage (faded if the exam is old)
	_blood_bar(-1.0 if last.is_empty() else float(last["vitality"]), not last.is_empty() and int(last["day"]) < GameState.day)

	# The bite drawn on the neck sketch once the doctor has found it
	if not last.is_empty() and (last["marks"] or last["old_marks"]):
		var bite := TextureRect.new()
		bite.texture = BITE
		bite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bite.position = BITE_RECT.position
		bite.size = BITE_RECT.size
		bite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if last["old_marks"]:
			bite.modulate = Color(0.8, 0.7, 0.6, 0.55)  # Old, healed: brown and faded
		sheet.add_child(bite)

	# Wrist bite found: a close-up sketch pinned under the paper clip
	if not last.is_empty() and str(last["trace"]).ends_with("(wrist)"):
		var note := TextureRect.new()
		note.texture = WRIST_NOTE
		note.position = WRIST_NOTE_POS
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(note)
		var clip := TextureRect.new()
		clip.texture = CLIP
		clip.position = CLIP_POS
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(clip)

	# Exam history, newest first
	var row := 0
	for i in range(exams.size() - 1, -1, -1):
		if row >= NOTE_LINES.size():
			break
		var e: Dictionary = exams[i]
		var note := "Day %d · %s, %s" % [e["day"], e["look"], "pulse " + e["pulse"]]
		if e["dead"]:
			note = "Day %d · found dead" % e["day"]
		elif e.get("treated", false):
			note = "Day %d · Treated at the clinic, now %s" % [e["day"], e["look"].to_lower()]
		_line_text(note, NOTE_X, NOTE_LINES[row], 24)
		row += 1

	chart_layer.visible = true


func _blood_bar(vitality: float, old: bool) -> void:
	var bar := BLOOD_BAR
	var drop := TextureRect.new()
	drop.texture = BLOOD_DROP
	drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drop.position = Vector2(84, bar.position.y - 10)
	drop.size = Vector2(38, 64)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(drop)
	var title := _label("Blood", 30)
	title.position = Vector2(130, bar.position.y)
	title.size = Vector2(115, bar.size.y)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sheet.add_child(title)

	# Frame drawn in ink, the red fill inside it
	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.45, 0.38, 0.18)
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = bar.position
	frame.size = bar.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(frame)

	var amount := clampf(vitality, 0.0, 1.0)
	if vitality >= 0.0 and amount > 0.0:
		var fill := ColorRect.new()
		fill.color = BLOOD_RED
		fill.position = bar.position + Vector2(5, 5)
		fill.size = Vector2((bar.size.x - 10) * amount, bar.size.y - 10)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if old:
			fill.modulate.a = 0.45  # Old news: things may be worse now
		sheet.add_child(fill)
	# Quarter marks so the level reads at a glance
	for q in [0.25, 0.5, 0.75]:
		var tick := ColorRect.new()
		tick.color = INK_FADED
		tick.position = bar.position + Vector2(bar.size.x * q - 1, 5)
		tick.size = Vector2(2, bar.size.y - 10)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(tick)

	var percent := _label("—" if vitality < 0.0 else "%d%%" % roundi(amount * 100.0), 30, BLOOD_RED if amount < 0.5 and vitality >= 0.0 else INK)
	percent.position = Vector2(bar.end.x + 14, bar.position.y)
	percent.size = Vector2(90, bar.size.y)
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if old:
		percent.modulate.a = 0.6
	sheet.add_child(percent)


func _line_text(text: String, x: float, baseline: float, font_size: int, font: Font = null, color := INK) -> void:
	var label := _label(text, font_size, color)
	if font:
		label.add_theme_font_override("font", font)
	label.position = Vector2(x, baseline - font_size * 1.35)  # Sit on the ruled line
	sheet.add_child(label)


func _label(text: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
