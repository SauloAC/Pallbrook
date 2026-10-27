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
const READING_TIME_SCALE := 0.25  # How fast the world runs while the casebook is open
const SUPPLIES := "#supplies"  # Coins, tonics, and how to get more
const NIGHTS := "#nights"      # Who was where each night, and the cross-check
const DIARY := "#diary"        # The old doctor's sheets (filled in a later step)

var filter := CHART_PICK  # NIGHTS, ALL, EVIDENCE... or a person's name
const PER_PAGE := 9  # 3x3 grid; more townsfolk spill onto extra pages
var townsfolk_page := 0
var filter_bar: HBoxContainer

# ---------- Bookmarks ----------
# Ribbons sticking out of the right edge of the book, one per section. Q/E turn to the
# previous/next one. Each opens a filter value (the person filters live inside Clues).
const RIBBONS := [["Patients", CHART_PICK], ["Visits", APPOINTMENTS], ["Supplies", SUPPLIES],
		["Diary", DIARY], ["Clues", ALL], ["Nights", NIGHTS]]
const RIBBON_SIZE := Vector2(134, 40)
const RIBBON_HIDDEN := 30.0   # How much of each ribbon is tucked under the book
const BOOK_SHIFT := -40.0     # The book sits a little left of centre, so the ribbons fit on screen
const RIBBON_PAPER := Color(0.87, 0.8, 0.66)
const RIBBON_EDGE := Color(0.42, 0.33, 0.24)
const RIBBON_RED := Color(0.55, 0.12, 0.09)
var ribbon_box: VBoxContainer

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

# ---------- Nights table and cross-check ----------
# Left page: one row per townsperson, one column per night. Right page: pick a mark, then a
# witness, and read what each said side by side. Marks only become ✓ or (!) once the doctor
# has compared them himself.
const NIGHTS_SHOWN := 6
const MARKS := {
	"match": preload("res://assets/ui/casebook/mark_check.png"),
	"conflict": preload("res://assets/ui/casebook/mark_conflict.png"),
	"alibi": preload("res://assets/ui/casebook/mark_alibi.png"),
	"dead": preload("res://assets/ui/casebook/mark_dead.png"),
	"refused": preload("res://assets/ui/casebook/mark_refused.png"),
	"victim": preload("res://assets/ui/casebook/mark_victim.png"),
	"": preload("res://assets/ui/casebook/mark_none.png"),
}
const MARK_SELECT := preload("res://assets/ui/casebook/mark_select.png")
const BOX_EMPTY := preload("res://assets/ui/casebook/box_empty.png")
const BOX_CHECKED := preload("res://assets/ui/casebook/box_checked.png")
# Ready-made phrases for the doctor's notes (Dark Souls style): click a blank to change it
const CLAIMS := ["says they stayed home", "says they were asleep", "claims to be ill", "saw someone at night",
		"saw nothing", "refused to talk"]
const CONNECTORS := [", but", ", and", ", so"]
const OBSERVATIONS := ["was out late at night", "was near a victim's house", "walked around by day",
		"may be lying", "may be mistaken", "may be covering for someone", "is telling the truth"]
var remark_choice := [0, 0, 0, 0]  # Person, claim, connector, observation
var nights_box: VBoxContainer
var nights_first := 0      # First night shown (0 = the latest nights)
var sel_person := ""       # The mark picked on the nights table
var sel_night := 0
var sel_witness := ""      # Who it is being compared with

var chart_layer: Control
var sheet: Control
var chart_npc := ""     # Whose chart is open
var chart_prev: Label   # Arrows beside the card to flip through the patients
var chart_next: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the game is paused
	add_to_group("casebook")  # The tutorial watches what the player opens
	panel.visible = false
	# Filter buttons, built in code right under the title
	filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 14)
	var vbox: VBoxContainer = $Panel/Pages/VBox
	vbox.add_child(filter_bar)
	vbox.move_child(filter_bar, title.get_index() + 1)
	nights_box = VBoxContainer.new()
	nights_box.add_theme_constant_override("separation", 6)
	nights_box.visible = false
	nights_box.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Keeps the key hints at the bottom of the page
	vbox.add_child(nights_box)
	vbox.move_child(nights_box, scroll.get_index())
	_layout_book(vbox)
	_build_ribbons()
	_build_chart_layer()
	_build_diary_layer()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Keeps the key hints at the bottom of the page


func _input(event: InputEvent) -> void:
	# With a chart open, left/right (A/D or the arrow keys) flip to the next patient
	if chart_layer.visible and not event.is_echo():
		var step := 0
		if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
			step = -1
		elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
			step = 1
		if step != 0:
			_step_chart(step)
			get_viewport().set_input_as_handled()
			return
	# Q/E: the previous/next bookmark (only while the book is open, not over a chart)
	# An open diary sheet: W/S pick a loose piece, A/D a gap, E puts it there
	if diary_layer.visible and not event.is_echo():
		var handled := true
		if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			_cycle_pick(-1)
		elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			_cycle_pick(1)
		elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
			_cycle_gap(-1)
		elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
			_cycle_gap(1)
		elif event.is_action_pressed("interact"):
			if diary_gap == "":
				_cycle_gap(1)
			_try_place(diary_gap)
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()
			return
	# An open diary sheet: Esc or Tab puts it down
	if diary_layer.visible and (event.is_action_pressed("notebook") or event.is_action_pressed("ui_cancel")):
		_close_sheet()
		get_viewport().set_input_as_handled()
		return
	if panel.visible and not chart_layer.visible and not diary_layer.visible and not event.is_echo():
		if event.is_action_pressed("accuse"):
			_turn_ribbon(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			_turn_ribbon(1)
			get_viewport().set_input_as_handled()
			return
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
	ribbon_box.visible = true
	Audio.play("book_open", -4.0)
	# Time doesn't stop while reading, it slows down: thinking is cheap, but not free.
	# 0 = full pause, 1 = normal speed.
	GameState.reading = true
	Engine.time_scale = READING_TIME_SCALE
	Playtest.reading_started()
	Playtest.count("casebook_opened")


func _close() -> void:
	panel.visible = false
	ribbon_box.visible = false
	Audio.play("book_close", -4.0)
	GameState.reading = false
	Engine.time_scale = 1.0
	Playtest.reading_stopped()


func _set_filter(value: String) -> void:
	if _is_person(value):
		if filter in [CHART_PICK, APPOINTMENTS, SUPPLIES, DIARY]:
			_open_chart(value)  # From the patients' page: their chart
			return
		clue_person = "" if clue_person == value else value  # Elsewhere: their clues
		filter = ALL
		Audio.play("page", -6.0)
		_refresh()
		return
	# Clicking the active person again goes back to everything (tabs just stay open)
	filter = ALL if value == filter and _is_person(value) else value
	Audio.play("page", -6.0)
	_refresh()


func _refresh() -> void:
	# The old person and clinic filters now live in the Clues chips
	if filter == EVIDENCE or _is_person(filter):
		clue_topic = "evidence" if filter == EVIDENCE else clue_topic
		clue_person = filter if _is_person(filter) else clue_person
		filter = ALL
	# The right page lists everyone the doctor looks after (set here, so it follows the language)
	for child in $Panel/Pages/Suspects.get_children():
		if child is Label:
			child.text = tr("Compare") if filter == NIGHTS else (tr("Loose pieces") if filter == DIARY else (tr("The clue") if filter in [ALL, EVIDENCE] else tr("Patients")))
			break
	_build_filter_bar()
	_build_suspects()
	_build_entries()
	_build_ribbons()
	var hint := get_node_or_null("Panel/Pages/VBox/Hint") as Label
	if hint:
		hint.text = tr("[Tab] Close") + "     " + tr("[Q/E] Turn bookmark")


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
	book.offset_left = -BOOK_SIZE.x / 2.0 + BOOK_SHIFT
	book.offset_right = BOOK_SIZE.x / 2.0 + BOOK_SHIFT
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
	# The sections moved to the bookmarks; what is left here are the filters of Clues
	_clear(filter_bar)
	filter_bar.visible = false  # The Clues page has its own filter chips now
	if not filter_bar.visible:
		return
	filter_bar.add_theme_constant_override("separation", 10)
	filter_bar.add_child(_link("All", ALL))
	filter_bar.add_child(_link("Clinic", EVIDENCE))
	if _is_person(filter):
		filter_bar.add_child(_link(filter, filter))
		# This person's chart, one click away
		var chart_link := _link("Patient chart", CHART_PICK)
		chart_link.add_theme_color_override("font_color", BLOOD_RED)
		for connection in chart_link.gui_input.get_connections():
			chart_link.gui_input.disconnect(connection["callable"])
		chart_link.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_chart_link.call_deferred())
		filter_bar.add_child(chart_link)


# ---------- Bookmarks ----------

# Which bookmark a filter value belongs to
func _ribbon_of(value: String) -> String:
	if value in [NIGHTS, CHART_PICK, DIARY, APPOINTMENTS, SUPPLIES]:
		return value
	return ALL  # Everything, the clinic's own findings, or one person: all part of Clues


func _build_ribbons() -> void:
	if ribbon_box == null:
		# Behind the book, sticking out of its right edge
		ribbon_box = VBoxContainer.new()
		ribbon_box.add_theme_constant_override("separation", 8)
		ribbon_box.set_anchors_preset(Control.PRESET_CENTER)
		ribbon_box.offset_left = BOOK_SIZE.x / 2.0 + BOOK_SHIFT - RIBBON_HIDDEN
		ribbon_box.offset_top = -BOOK_SIZE.y / 2.0 + 46.0
		ribbon_box.visible = panel.visible
		add_child(ribbon_box)
		move_child(ribbon_box, panel.get_index())  # Drawn before (under) the book
	_clear(ribbon_box)
	var active := _ribbon_of(filter)
	var font: Font = title.get_theme_font("font")
	for entry in RIBBONS:
		var value: String = entry[1]
		var on := value == active
		var tab := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = RIBBON_PAPER if on else RIBBON_PAPER.darkened(0.12)
		style.border_color = RIBBON_EDGE
		style.set_border_width_all(2)
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = RIBBON_HIDDEN  # The part hidden under the book
		style.content_margin_right = 6.0
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 3
		tab.add_theme_stylebox_override("panel", style)
		tab.custom_minimum_size = RIBBON_SIZE
		var label := Label.new()
		label.text = tr(entry[0])
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 13 if label.text.length() <= 8 else 11)
		label.clip_text = true
		label.add_theme_color_override("font_color", RIBBON_RED if on else INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(label)
		# The open one sticks out a little further
		var row := MarginContainer.new()
		row.add_theme_constant_override("margin_left", 8 if on else 0)
		row.add_child(tab)
		_make_ribbon_clickable(tab, value)
		ribbon_box.add_child(row)


func _make_ribbon_clickable(tab: Control, value: String) -> void:
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_ribbon.call_deferred(value))


func _open_ribbon(value: String) -> void:
	if _ribbon_of(filter) == value and value != ALL:
		return
	filter = value
	Audio.play("page", -6.0)
	_refresh()


func _turn_ribbon(step: int) -> void:
	var index := 0
	for i in RIBBONS.size():
		if RIBBONS[i][1] == _ribbon_of(filter):
			index = i
	_open_ribbon(RIBBONS[posmod(index + step, RIBBONS.size())][1])


func _is_person(value: String) -> bool:
	return value not in [ALL, EVIDENCE, APPOINTMENTS, CHART_PICK, SUPPLIES, NIGHTS, DIARY]


func _on_chart_link() -> void:
	if _is_person(filter):
		_open_chart(filter)
	else:
		filter = CHART_PICK
		Audio.play("page", -6.0)
		_refresh()


func _link(text: String, value: String) -> Label:
	var label := Label.new()
	label.text = tr(text)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", INK if filter == value else INK_FADED)
	if filter == value:
		label.text = "» " + tr(text)
	_make_clickable(label, value)
	return label


func _build_entries() -> void:
	if filter == EVIDENCE:
		filter = ALL
		clue_topic = "evidence"
	scroll.visible = filter not in [NIGHTS, DIARY, ALL]
	nights_box.visible = filter in [NIGHTS, DIARY, ALL]
	if filter == NIGHTS:
		_build_nights()
		return
	if filter == DIARY:
		_clear(nights_box)
		_build_diary_sheets()
		return
	if filter == ALL:
		_clear(nights_box)
		_build_clues()
		return
	if filter == APPOINTMENTS:
		_build_appointments()
		return
	if filter == SUPPLIES:
		_build_supplies()
		return
	if filter == CHART_PICK:
		title.text = tr("Patient chart")
		entries.text = tr("Choose a patient on the right page to open their chart.")
		scroll.scroll_vertical = 0
		return
	match filter:
		ALL:
			title.text = tr("Clues")
		EVIDENCE:
			title.text = tr("Clinic")
		_:
			title.text = filter

	var lines: Array[String] = []
	var last_day := -1
	for entry in GameState.entries:
		if not _matches(entry):
			continue
		if entry["day"] != last_day:
			last_day = entry["day"]
			lines.append(tr("— Day %d —") % last_day)
		lines.append("• " + entry["text"])

	if lines.is_empty():
		entries.text = tr("Nothing about %s yet.") % tr(filter) if filter not in [ALL, EVIDENCE] else tr("Nothing yet.")
	else:
		entries.text = "\n\n".join(PackedStringArray(lines))
	scroll.scroll_vertical = 0


func _build_supplies() -> void:
	# What the doctor has, and how the clinic's little economy works
	title.text = tr("Supplies")
	var lines: Array[String] = []
	lines.append(tr("Coins: %d") % GameState.coins)
	lines.append(tr("Iron tonics ready: %d") % GameState.tonics)
	if GameState.tonics_ordered > 0:
		lines.append(tr("Steeping, ready tomorrow morning: %d") % GameState.tonics_ordered)
	if GameState.ingredients > 0:
		lines.append(tr("Ingredients for: %d") % GameState.ingredients)
	lines.append(tr("— How it works —"))
	lines.append("• " + tr("Iron tonic: treats one weak or bitten patient. Ask them to come to the clinic, be there at the agreed time, and give it to them (talk to them)."))
	lines.append("• " + tr("Not every sick person was bitten: autumn chills bring fever, a strong pulse and a cough. The tonic does nothing for them; prescribe rest and good food instead (after an exam, or at the clinic). It costs nothing."))
	lines.append("• " + tr("To make more: learn the recipe from the materia medica in the library (once, three hours), buy the ingredients from the merchant beyond the bridge (mornings, {price} coins a tonic), then prepare them at your clinic cabinet (one hour). They are ready the next morning.").format({"price": GameState.TONIC_PRICE}))
	if not GameState.knows_tonic:
		lines.append("• " + tr("You don't know the recipe yet."))
	lines.append("• " + tr("Coins: the Town Hall pays you {salary} every morning, and each patient pays {fee} for their first exam of the day.").format({"salary": GameState.SALARY, "fee": GameState.EXAM_FEE}))
	lines.append("• " + tr("At night, sleep in the bed at your clinic (E) to rest; stay up too long and you collapse in the street."))
	entries.text = "\n\n".join(PackedStringArray(lines))
	scroll.scroll_vertical = 0


func _build_appointments() -> void:
	# Who needs the doctor today, then every clinic visit, newest first
	title.text = tr("Appointments")
	var lines: Array[String] = []
	var urgent: Array[String] = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_alive() and npc.marked and npc.talked_day >= npc.marked_day:
			urgent.append("• %s · " % tr(npc.data.npc_name) + tr("visited at night: treat today, or keep watch at the door tonight"))
	if not urgent.is_empty():
		lines.append(tr("— Urgent —"))
		lines.append_array(urgent)
	var last_day := -1
	for i in range(GameState.appointments.size() - 1, -1, -1):
		var a: Dictionary = GameState.appointments[i]
		if a["day"] != last_day:
			last_day = a["day"]
			lines.append(tr("— Today —") if last_day == GameState.day else tr("— Day %d —") % last_day)
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
			"rest":
				status = "rest prescribed"
		lines.append("• %s · %s – %s · %s" % [tr(a["name"]), GameState.format_time(a["from"]), GameState.format_time(a["until"]), tr(status)])
	if lines.is_empty():
		entries.text = tr("No appointments yet.") + "\n\n" + tr("Ask a sick patient to come to the clinic for a treatment.")
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
	if filter == NIGHTS:
		_build_compare()
		return
	if filter == ALL:
		_build_clue_detail()
		return
	if filter == DIARY:
		var holder := ScrollContainer.new()
		holder.custom_minimum_size = Vector2(0, 360)  # A long tray scrolls, the book never grows
		holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		suspect_list.add_child(holder)
		var tray := VBoxContainer.new()
		tray.add_theme_constant_override("separation", 6)
		tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(tray)
		_build_diary_tray(tray)
		return
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
		label.text = ("» " if filter == name_text else "") + tr(name_text)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 17)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)

		var role := Label.new()
		role.text = tr(npc.data.role) + ("" if npc.is_alive() else " · " + tr("deceased"))
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


# ---------- Nights table (left page) ----------

func _build_nights() -> void:
	title.text = tr("Where was everyone?")
	_clear(nights_box)
	var last := GameState.last_night()
	if last < 1:
		nights_box.add_child(_ink_label(tr("No nights yet. Tomorrow, ask people where they were tonight."), 16, true))
		return
	nights_box.add_child(_ink_label(tr("Pick a mark, then compare it with what someone else saw."), 13, true, INK_FADED))
	# The latest nights by default; older ones with the arrows
	var count := mini(NIGHTS_SHOWN, last)
	var first := nights_first if nights_first > 0 else last - count + 1
	first = clampi(first, 1, last - count + 1)
	var grid := GridContainer.new()
	grid.columns = count + 1
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 0)
	nights_box.add_child(grid)
	grid.add_child(_ink_label(tr("night"), 12, false, INK_FADED))
	for n in range(first, first + count):
		var head := _ink_label(str(n), 14, false, BLOOD_RED if n == sel_night else INK)
		head.custom_minimum_size = Vector2(36, 0)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(head)
	for npc in _chart_people_nodes():
		var who: String = npc.data.npc_name
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.custom_minimum_size = Vector2(118, 30)
		var pic := TextureRect.new()
		pic.texture = npc.data.portrait
		pic.custom_minimum_size = Vector2(24, 24)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		name_row.add_child(pic)
		var name_label := _ink_label(tr(who), 14, false, BLOOD_RED if who == sel_person else INK)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_row.add_child(name_label)
		grid.add_child(name_row)
		for n in range(first, first + count):
			grid.add_child(_night_cell(npc, n))
	# Older or newer nights
	if last > count:
		var bar := HBoxContainer.new()
		bar.alignment = BoxContainer.ALIGNMENT_CENTER
		bar.add_theme_constant_override("separation", 18)
		bar.add_child(_nights_arrow("‹", first - 1, first > 1))
		bar.add_child(_ink_label(tr("Nights {from}–{to}").format({"from": first, "to": first + count - 1}), 13, false))
		bar.add_child(_nights_arrow("›", first + 1, first + count - 1 < last))
		nights_box.add_child(bar)
	nights_box.add_child(_legend())


func _night_cell(npc: Node, night: int) -> Control:
	var who: String = npc.data.npc_name
	var mark := GameState.night_mark(night, who)
	var clickable := true
	if not npc.is_alive() and npc.found_day <= night:
		mark = "dead"
		clickable = false
	elif not npc.is_alive() and npc.found_day == night + 1:
		mark = "victim"  # Died that night
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(36, 30)
	if who == sel_person and night == sel_night:
		cell.add_child(_mark_rect(MARK_SELECT, 30.0))
	cell.add_child(_mark_rect(MARKS[mark], 22.0))
	if clickable:
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_mark.call_deferred(who, night))
	return cell


func _mark_rect(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2(side, side)
	rect.position = Vector2((36.0 - side) / 2.0, (30.0 - side) / 2.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _select_mark(who: String, night: int) -> void:
	sel_person = who
	sel_night = night
	sel_witness = ""
	remark_choice = [0, 0, 0, 0]
	Audio.play("page", -10.0)
	_refresh()


func _nights_arrow(symbol: String, first: int, enabled: bool) -> Label:
	var arrow := _ink_label(symbol, 24, false, INK if enabled else INK_FADED)
	if enabled:
		arrow.mouse_filter = Control.MOUSE_FILTER_STOP
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		arrow.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				nights_first = first
				_build_nights.call_deferred())
	return arrow


func _legend() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var rows := [[["match", "matches"], ["conflict", "doesn't match"], ["alibi", "told, not checked"]],
			[["", "not asked"], ["refused", "refused to say"], ["victim", "died that night"]],
			[["dead", "dead"]]]
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		for item in row:
			var pic := TextureRect.new()
			pic.texture = MARKS[item[0]]
			pic.custom_minimum_size = Vector2(16, 16)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line.add_child(pic)
			var words := _ink_label(tr(item[1]), 11, false, INK_FADED)
			words.custom_minimum_size.x = 96
			line.add_child(words)
		box.add_child(line)
	return box


# ---------- Cross-check (right page) ----------

func _build_compare() -> void:
	if sel_person == "" or sel_night < 1:
		suspect_list.add_child(_ink_label(tr("Choose a mark on the left page: a person on a night. Then pick a witness here to read what both of them said."), 15, true))
		return
	var subject := _npc(sel_person)
	var heading := _ink_label(tr("{name} · Night {night}").format({"name": tr(sel_person), "night": sel_night}), 20, false)
	suspect_list.add_child(heading)
	# What the person said about their own evening
	var alibi: Dictionary = GameState.alibis.get("%d|%s" % [sel_night, sel_person], {})
	if alibi.is_empty() and GameState.refused(sel_night, sel_person, "alibi"):
		suspect_list.add_child(_said_block(subject, tr("{name} said:").format({"name": tr(sel_person)}),
				tr("{name} refused to say where they were that night.").format({"name": tr(sel_person)}), true))
	elif alibi.is_empty():
		suspect_list.add_child(_said_block(subject, tr("{name} said:").format({"name": tr(sel_person)}),
				tr("You didn't ask {name} where they were that night.").format({"name": tr(sel_person)}), true))
	else:
		suspect_list.add_child(_said_block(subject, tr("{name} said:").format({"name": tr(sel_person)}),
				tr("“{text}”").format({"text": alibi["text"]}), false))
	suspect_list.add_child(_ink_label("— " + tr("compare with") + " —", 13, false, BLOOD_RED))
	suspect_list.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Everyone else; those who weren't asked what they saw that night are faded
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	suspect_list.add_child(grid)
	for npc in _chart_people_nodes():
		var who: String = npc.data.npc_name
		if who == sel_person:
			continue
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 0)
		card.custom_minimum_size.x = 54
		var pic := TextureRect.new()
		pic.texture = npc.data.portrait
		pic.custom_minimum_size = Vector2(36, 36)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		var label := _ink_label(tr(who), 11, false, BLOOD_RED if who == sel_witness else INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		if not GameState.has_report(sel_night, who):
			card.modulate = Color(1, 1, 1, 0.4)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_compare_with.call_deferred(who))
		grid.add_child(card)
	if sel_witness == "":
		return
	# What the witness said about this person that night
	var witness := _npc(sel_witness)
	var words := ""
	var faded := false
	if GameState.refused(sel_night, sel_witness, "seen"):
		words = tr("{witness} refused to say what they saw that night.").format({"witness": tr(sel_witness)})
		faded = true
	elif not GameState.has_report(sel_night, sel_witness):
		words = tr("You didn't ask {witness} what they saw that night.").format({"witness": tr(sel_witness)})
		faded = true
	else:
		var seen := GameState.sightings_of(sel_night, sel_witness, sel_person)
		if seen.is_empty():
			words = tr("{witness} didn't mention {name}.").format({"witness": tr(sel_witness), "name": tr(sel_person)})
			faded = true
		else:
			var lines: Array = []
			for s in seen:
				lines.append(witness._describe(s) if witness else "")
			words = tr("“{text}”").format({"text": Lang.join_sentences(lines)})
	suspect_list.add_child(_said_block(witness, tr("{name} said:").format({"name": tr(sel_witness)}), words, faded))
	# The verdict, once both sides were heard
	var result: String = GameState.crosschecks.get("%d|%s|%s" % [sel_night, sel_person, sel_witness], "")
	if result == "conflict":
		suspect_list.add_child(_ink_label(tr("This doesn't match what {name} said.").format({"name": tr(sel_person)}), 15, true, BLOOD_RED))
	elif result == "match":
		suspect_list.add_child(_ink_label(tr("This matches what {name} said.").format({"name": tr(sel_person)}), 15, true))
	elif alibi.is_empty() and not GameState.sightings_of(sel_night, sel_witness, sel_person).is_empty():
		suspect_list.add_child(_ink_label(tr("Ask {name} where they were that night, then compare.").format({"name": tr(sel_person)}), 14, true, INK_FADED))
	if result == "match" or result == "conflict":
		suspect_list.add_child(_belief_block())
	suspect_list.add_child(_remark_block())


# "Who do you believe?" The game never says who is right: servants lie too.
func _belief_block() -> Control:
	var key := "%d|%s|%s" % [sel_night, sel_person, sel_witness]
	var current: String = GameState.beliefs.get(key, "unsure")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_ink_label(tr("Who do you believe?"), 15, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for option in [["subject", tr(sel_person)], ["witness", tr(sel_witness)], ["unsure", tr("Not sure yet")]]:
		var choice := HBoxContainer.new()
		choice.add_theme_constant_override("separation", 3)
		var tick := TextureRect.new()
		tick.texture = BOX_CHECKED if current == option[0] else BOX_EMPTY
		tick.custom_minimum_size = Vector2(22, 22)
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(tick)
		var words := _ink_label(option[1], 14, false)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(words)
		choice.mouse_filter = Control.MOUSE_FILTER_STOP
		choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var value: String = option[0]
		choice.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.beliefs[key] = value
				Playtest.count("belief_" + value)
				Audio.play("click", -10.0)
				_build_suspects.call_deferred())
		row.add_child(choice)
	box.add_child(row)
	if GameState.knows("servants"):  # Only once he has learned that the bitten can serve it
		box.add_child(_ink_label(tr("Either one could be lying: servants lie too."), 12, false, INK_FADED))
	return box


# A note made of blanks: [person] [claim] [connector] [observation]. Left click changes a blank,
# right click goes back; "Write it down" files it in the casebook.
func _remark_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_ink_label(tr("Remark"), 15, false))
	var people := [sel_person, sel_witness]
	var options := [people, CLAIMS, CONNECTORS, OBSERVATIONS]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.custom_minimum_size.x = 300
	for i in 4:
		var list: Array = options[i]
		var pick: int = posmod(remark_choice[i], list.size())
		var text: String = tr(list[pick])
		flow.add_child(_blank(text, i, list.size()))
	box.add_child(flow)
	var write := _ink_label(tr("[Write it down]"), 14, false, BLOOD_RED)
	write.mouse_filter = Control.MOUSE_FILTER_STOP
	write.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	write.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_write_remark.call_deferred(options))
	box.add_child(write)
	box.add_child(_ink_label(tr("Click a word to change it (right click goes back)."), 12, false, INK_FADED))
	return box


# One blank of the note: the word, underlined in ink
func _blank(text: String, index: int, count: int) -> Control:
	var blank := VBoxContainer.new()
	blank.add_theme_constant_override("separation", -2)
	var word := _ink_label(text, 14, false, BLOOD_RED if index != 2 else INK)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_child(word)
	var line := ColorRect.new()
	line.color = Color(0.17, 0.15, 0.13, 0.55)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.add_child(line)
	blank.mouse_filter = Control.MOUSE_FILTER_STOP
	blank.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	blank.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			var step := 1 if event.button_index == MOUSE_BUTTON_LEFT else (-1 if event.button_index == MOUSE_BUTTON_RIGHT else 0)
			if step != 0:
				remark_choice[index] = posmod(remark_choice[index] + step, count)
				Audio.play("click", -14.0)
				_build_suspects.call_deferred())
	return blank


func _write_remark(options: Array) -> void:
	var words := []
	for i in 4:
		var list: Array = options[i]
		words.append(tr(list[posmod(remark_choice[i], list.size())]))
	var text := Lang.contract(tr("{person} {claim}{connector} {observation}.").format(
			{"person": words[0], "claim": words[1], "connector": words[2], "observation": words[3]}))
	var person: String = options[0][posmod(remark_choice[0], 2)]
	GameState.add_remark(sel_night, [person], text)
	Audio.play("page", -6.0)
	_refresh()


func _compare_with(witness: String) -> void:
	sel_witness = witness
	remark_choice = [0, 0, 0, 0]
	if GameState.has_alibi(sel_night, sel_person) and GameState.has_report(sel_night, witness):
		var key := "%d|%s|%s" % [sel_night, sel_person, witness]
		var first_time := not GameState.crosschecks.has(key)
		var result := GameState.cross_check(sel_night, sel_person, witness)
		if result == "conflict" and first_time:
			Audio.play("clue", -4.0)  # Found a lie (or a mistake)
		else:
			Audio.play("page", -10.0)
	else:
		Audio.play("page", -10.0)
	_refresh()


# A portrait beside "Name said:" and their words
func _said_block(npc: Node, who_said: String, words: String, faded: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pic := TextureRect.new()
	if npc and npc.data:
		pic.texture = npc.data.portrait
	pic.custom_minimum_size = Vector2(44, 44)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_ink_label(who_said, 12, false, INK_FADED))
	text.add_child(_ink_label(words, 14, true, INK_FADED if faded else INK))
	row.add_child(text)
	return row


func _ink_label(text: String, size: int, wrap_text: bool, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # Already translated
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap_text:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 300
	return label


func _npc(person: String) -> Node:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == person:
			return npc
	return null


func _chart_people_nodes() -> Array:
	var people := get_tree().get_nodes_in_group("npcs").filter(func(n): return n.data != null)
	people.sort_custom(func(a, b): return a.data.npc_name.naturalnocasecmp_to(b.data.npc_name) < 0)
	return people


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
	chart_prev = _chart_arrow("‹", -1)
	chart_next = _chart_arrow("›", 1)


func _chart_arrow(symbol: String, step: int) -> Label:
	var arrow := Label.new()
	arrow.text = symbol
	arrow.add_theme_font_size_override("font_size", 120)
	arrow.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	arrow.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	arrow.add_theme_constant_override("outline_size", 14)
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arrow.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_step_chart(step))
	chart_layer.add_child(arrow)
	return arrow


# Everyone with a chart, in the same order as the patients page
func _chart_people() -> Array:
	var people := get_tree().get_nodes_in_group("npcs").filter(func(n): return n.data != null)
	people.sort_custom(func(a, b): return a.data.npc_name.naturalnocasecmp_to(b.data.npc_name) < 0)
	return people.map(func(n): return n.data.npc_name)


func _step_chart(step: int) -> void:
	var names := _chart_people()
	var i := names.find(chart_npc)
	if i < 0 or names.size() < 2:
		return
	var next: String = names[(i + step + names.size()) % names.size()]
	filter = next  # The casebook behind follows along
	_refresh()
	Audio.play("page", -6.0)
	_open_chart(next)


func _open_chart(npc_name: String) -> void:
	var npc: Node = null
	for person in get_tree().get_nodes_in_group("npcs"):
		if person.data and person.data.npc_name == npc_name:
			npc = person
	if npc == null:
		return
	chart_npc = npc_name
	Playtest.count("charts_opened")
	_clear(sheet)
	# Fit the card to 92% of the screen height, centered
	var view := get_viewport().get_visible_rect().size
	var s := view.y * 0.92 / CHART_SIZE.y
	sheet.scale = Vector2(s, s)
	sheet.position = (view - CHART_SIZE * s) / 2.0
	var arrow_y := view.y / 2.0 - 90.0
	chart_prev.position = Vector2(sheet.position.x - 90.0, arrow_y)
	chart_next.position = Vector2(sheet.position.x + CHART_SIZE.x * s + 30.0, arrow_y)

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
	_line_text(tr(npc.data.npc_name), LINE_X, TOP_LINES[0], 44, title_font)
	_line_text(tr(npc.data.role), LINE_X, TOP_LINES[1], 30)
	if not npc.is_alive():
		_line_text(tr("Deceased") + (" · " + tr("buried") if npc.buried else ""), LINE_X, TOP_LINES[2], 30, null, BLOOD_RED)
	elif last.is_empty():
		_line_text(tr("Not examined yet"), LINE_X, TOP_LINES[2], 30)
	else:
		var age: int = GameState.day - int(last["day"])
		var when := tr("today") if age == 0 else (tr("yesterday") if age == 1 else tr("%d days ago") % age)
		_line_text(tr("Last examined {when} (Day {day})").format({"when": when, "day": last["day"]}), LINE_X, TOP_LINES[2], 30)
	if not last.is_empty() and last["trace"] != "":
		_line_text(tr("Traces: %s") % _tr_value(last["trace"]), LINE_X, TOP_LINES[3], 28)
	if not last.is_empty() and last["old_marks"]:
		_line_text(tr("Old, healed punctures"), LINE_X, TOP_LINES[4], 28, null, BLOOD_RED)
	elif npc.is_alive() and npc.marked and npc.talked_day >= npc.marked_day:
		_line_text(tr("Visited at night: treat today!"), LINE_X, TOP_LINES[4], 28, null, BLOOD_RED)
	if npc.is_alive():
		_line_text(tr(npc.trust_word()), LINE_X, TOP_LINES[5], 28)

	# Vital signs boxes: pulse, temperature, appearance, sleep
	var values := ["—", "—", "—", "—"]
	if not last.is_empty():
		values = [_tr_value(last["pulse"]), _tr_value(last["temp"]), _tr_value(last["look"]), _tr_value(last.get("sleep", "—"))]
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
		var note := tr("Day {day} · {look}, pulse {pulse}").format({"day": e["day"], "look": _tr_value(e["look"]), "pulse": _tr_value(e["pulse"])})
		if e["dead"]:
			note = tr("Day {day} · found dead").format({"day": e["day"]})
		elif e.get("treated", false):
			note = tr("Day {day} · Treated at the clinic, now {look}").format({"day": e["day"], "look": _tr_value(e["look"]).to_lower()})
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
	var blood_title := _label(tr("Blood"), 30)
	blood_title.position = Vector2(130, bar.position.y)
	blood_title.size = Vector2(115, bar.size.y)
	blood_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sheet.add_child(blood_title)

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


# Exam readings are stored in English ("88, quick", "chalk dust (wrist)"); show them in the
# current language: the number stays, the words are translated.
func _tr_value(value) -> String:
	var text := str(value)
	if text.ends_with(" (wrist)"):
		return _tr_value(text.trim_suffix(" (wrist)")) + " " + tr("(wrist)")
	var comma := text.find(", ")
	if comma > 0 and text.left(comma).is_valid_int():
		return text.left(comma) + ", " + tr(text.substr(comma + 2))
	return tr(text)


# ---------- The old doctor's diary ----------
# Left page: the sheets, in order, with the pieces each still misses. Right page: the loose
# pieces found in town. Open a sheet, pick a loose piece and click the gap it fits.

const SHEET_SIZE := Vector2(470, 520)
const SHEET_VIEW := preload("res://scripts/ui/DiarySheetView.gd")
const PAPER_ART := "res://assets/ui/diary/sheet.png"
const PIECE_PAPER := {"A": Color(0.95, 0.91, 0.82), "B": Color(0.91, 0.86, 0.74), "C": Color(0.93, 0.88, 0.78),
		"W": Color(0.95, 0.91, 0.82)}
var diary_pick := ""        # The loose piece in hand ("5C")
var diary_sheet := 0        # The sheet open on top of the book
var diary_layer: Control
var diary_gap := ""         # The gap chosen with the keys on the open sheet ("B")
var diary_paper: VBoxContainer   # The sheet's heading
var diary_view                    # The sheet itself, torn into its pieces (DiarySheetView)
var diary_learned: Label
var paper_art: Texture2D
var diary_tray: VBoxContainer
var diary_msg: Label
const HAND_FONT := "res://assets/fonts/Caveat/Caveat-Regular.ttf"  # The old doctor's handwriting
var hand_font: Font


func _build_diary_sheets() -> void:
	title.text = tr("The Old Doctor's Diary")
	nights_box.add_child(_ink_label(tr("Click a sheet to open it. Pick a loose piece, then click the gap it fits."), 13, true, INK_FADED))
	var shown := 0
	for p: Dictionary in Diary.pages():
		var id := int(p["id"])
		# A sheet shows up once the doctor has found some of it
		if not (Diary.is_found("%dW" % id) or Diary.is_found("%dA" % id) or Diary.is_found("%dB" % id) or Diary.is_found("%dC" % id)):
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var head := _ink_label(tr("Sheet %d") % id, 15, false, BLOOD_RED if id == diary_sheet else INK)
		head.custom_minimum_size.x = 70
		row.add_child(head)
		var done := Diary.is_complete(p)
		var words := Diary.title(p) if done else Diary.piece_text(p, "A").get_slice("\n", 0)
		var label := _ink_label(words, 13, false, INK if done else INK_FADED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		if not p.get("whole", false):
			var status := PackedStringArray()
			for letter in ["A", "B", "C"]:
				status.append(letter + ("✓" if Diary.is_placed("%d%s" % [id, letter]) else "·"))
			row.add_child(_ink_label(" ".join(status), 13, false, INK if done else INK_FADED))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_sheet.call_deferred(id))
		nights_box.add_child(row)
	if shown == 0:
		nights_box.add_child(_ink_label(tr("No sheets yet. Your predecessor must have left something at the clinic."), 14, true, INK_FADED))


# The loose pieces: found in town, not yet fitted
func _loose_pieces() -> Array[String]:
	var list: Array[String] = []
	for piece: String in GameState.diary.get("found", {}):
		if not Diary.is_placed(piece):
			list.append(piece)
	list.sort()
	return list


func _build_diary_tray(box: VBoxContainer) -> void:
	_clear(box)
	var loose := _loose_pieces()
	if loose.is_empty():
		box.add_child(_ink_label(tr("No torn pieces yet. They could be anywhere in town."), 14, true, INK_FADED))
		return
	for piece in loose:
		var p := Diary.page(int(piece.left(-1)))
		var card := PanelContainer.new()
		var style: StyleBox
		if paper_art:
			var paper_style := StyleBoxTexture.new()
			paper_style.texture = paper_art
			paper_style.modulate_color = Color(1.0, 0.8, 0.74) if piece == diary_pick else Color.WHITE
			style = paper_style
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = PIECE_PAPER[piece.right(1)]
			style = flat
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
		var inside := VBoxContainer.new()
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview := Diary.piece_text(p, piece.right(1)).split("\n")
		var short := "\n".join(preview.slice(0, 2)) + ("\n…" if preview.size() > 2 else "")
		var words := _hand(_ink_label(("» " if piece == diary_pick else "") + short, 17, true, BLOOD_RED if piece == diary_pick else INK))
		words.custom_minimum_size.x = 230
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(words)
		var where := _ink_label(Lang.contract(tr("Found at {place} · Day {day}")).format({"place": Diary.place_words(GameState.diary["spots"].get(piece, "")),
				"day": GameState.diary["found"][piece]}), 11, false, INK_FADED)
		where.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(where)
		card.add_child(inside)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pick_piece.call_deferred(piece))
		box.add_child(card)


func _pick_piece(piece: String) -> void:
	diary_pick = "" if diary_pick == piece else piece
	Audio.play("page", -10.0)
	if diary_layer.visible:
		_fill_sheet()
	_refresh()


func _build_diary_layer() -> void:
	if ResourceLoader.exists(HAND_FONT):
		hand_font = load(HAND_FONT)
	if ResourceLoader.exists(PAPER_ART):
		paper_art = load(PAPER_ART)
	diary_layer = Control.new()
	diary_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	diary_layer.visible = false
	add_child(diary_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_sheet())  # Click outside to put the sheet down
	diary_layer.add_child(dim)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.offset_left = -(SHEET_SIZE.x + 24.0 + 300.0) / 2.0
	row.offset_top = -SHEET_SIZE.y / 2.0 - 40.0
	diary_layer.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	diary_paper = VBoxContainer.new()
	column.add_child(diary_paper)
	diary_view = SHEET_VIEW.new()
	diary_view.custom_minimum_size = SHEET_SIZE
	diary_view.paper = paper_art
	diary_view.hand = hand_font
	diary_view.gap_clicked.connect(func(letter: String): _try_place.call_deferred(letter))
	column.add_child(diary_view)
	diary_learned = _ink_label("", 15, true, Color(0.95, 0.8, 0.45))
	diary_learned.custom_minimum_size.x = SHEET_SIZE.x
	column.add_child(diary_learned)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size.x = 300
	row.add_child(side)
	var tray_title := _ink_label(tr("Loose pieces"), 18, false, Color(0.93, 0.91, 0.86))
	tray_title.add_theme_font_override("font", title.get_theme_font("font"))
	side.add_child(tray_title)
	var tray_scroll := ScrollContainer.new()
	tray_scroll.custom_minimum_size = Vector2(300, 380)
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(tray_scroll)
	diary_tray = VBoxContainer.new()
	diary_tray.add_theme_constant_override("separation", 6)
	diary_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_scroll.add_child(diary_tray)
	diary_msg = _ink_label("", 14, true, Color(0.95, 0.8, 0.45))
	side.add_child(diary_msg)
	side.add_child(_ink_label(tr("[W/S] Pick a piece    [A/D] Choose a gap") + "\n" + tr("[E] Put it there    [Esc] Back"), 13, true, Color(0.93, 0.91, 0.86)))


func _open_sheet(id: int) -> void:
	diary_sheet = id
	diary_gap = ""
	diary_msg.text = ""
	diary_layer.visible = true
	Audio.play("page", -6.0)
	_fill_sheet()
	_refresh()


func _close_sheet() -> void:
	diary_layer.visible = false
	diary_sheet = 0
	_refresh()


func _fill_sheet() -> void:
	_clear(diary_paper)
	_build_diary_tray(diary_tray)
	for child in diary_view.get_children():
		if child is ScrollContainer:
			child.queue_free()
	var p := Diary.page(diary_sheet)
	if p.is_empty():
		return
	var head := _ink_label(tr("Sheet %d") % diary_sheet + ("  ·  " + Diary.title(p) if Diary.is_complete(p) else ""), 18, false, Color(0.93, 0.91, 0.86))
	head.add_theme_font_override("font", title.get_theme_font("font"))
	diary_paper.add_child(head)
	diary_learned.text = Diary.learned(p) if Diary.is_complete(p) else ""
	if p.get("whole", false):
		diary_view.show_sheet(diary_sheet, [], [], {}, "")
		var holder := ScrollContainer.new()  # A long letter scrolls inside the sheet
		holder.position = Vector2(34, 30)
		holder.size = SHEET_SIZE - Vector2(68, 60)
		holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		diary_view.add_child(holder)
		var text := _hand(_ink_label(Diary.whole_text(p), 20, true))
		text.custom_minimum_size.x = SHEET_SIZE.x - 90.0
		holder.add_child(text)
		return
	var placed := {}
	for letter in ["A", "B", "C"]:
		if Diary.is_placed("%d%s" % [diary_sheet, letter]):
			placed[letter] = true
	diary_view.show_sheet(diary_sheet, p["layout"], Diary.lines(p), placed, diary_gap)


func _try_place(letter: String) -> void:
	if letter == "":
		return
	diary_gap = letter
	var gap_piece := "%d%s" % [diary_sheet, letter]
	if diary_pick == "":
		diary_msg.text = tr("Pick a loose piece first, then click the gap it fits.")
	elif diary_pick == gap_piece:
		GameState.diary["placed"][gap_piece] = true
		diary_pick = ""
		Audio.play("page", -4.0)
		Playtest.count("diary_pieces_fitted")
		diary_msg.text = ""
		diary_gap = ""
		var p := Diary.page(diary_sheet)
		if Diary.is_complete(p):
			_sheet_completed(p)
	elif diary_pick.left(-1) == str(diary_sheet):
		diary_msg.text = tr("Right sheet, wrong gap.")
	else:
		diary_msg.text = tr("The tear doesn't match: this piece belongs to another sheet.")
	_fill_sheet()
	_refresh()


func _sheet_completed(p: Dictionary) -> void:
	diary_msg.text = tr("The sheet is whole again.")
	if p.has("lore"):
		GameState.learn(p["lore"])
	Playtest.count("diary_sheets_completed")
	Playtest.log_line("Completed diary sheet %d" % int(p["id"]))
	GameState.add_clue(tr("Day {day} · The old doctor's diary, sheet {n} ({title}): {learned}").format({"day": GameState.day,
			"n": int(p["id"]), "title": Diary.title(p), "learned": Diary.learned(p)}), "evidence")


func _cycle_pick(step: int) -> void:
	var loose := _loose_pieces()
	if loose.is_empty():
		return
	var at := loose.find(diary_pick)
	diary_pick = loose[posmod(at + step, loose.size()) if at >= 0 else (0 if step > 0 else loose.size() - 1)]
	Audio.play("page", -12.0)
	_fill_sheet()
	_refresh()


# The gaps still open on this sheet, left to right, top to bottom
func _open_gaps() -> Array[String]:
	var gaps: Array[String] = []
	var p := Diary.page(diary_sheet)
	for pair: Array in p.get("layout", []):
		for letter: String in pair:
			if not Diary.is_placed("%d%s" % [diary_sheet, letter]) and letter not in gaps:
				gaps.append(letter)
	return gaps


func _cycle_gap(step: int) -> void:
	var gaps := _open_gaps()
	if gaps.is_empty():
		diary_gap = ""
		return
	var at := gaps.find(diary_gap)
	diary_gap = gaps[posmod(at + step, gaps.size()) if at >= 0 else 0]
	_fill_sheet()


# The old doctor's words in his own hand (falls back to the book's font if the file is missing)
func _hand(label: Label) -> Label:
	if hand_font:
		label.add_theme_font_override("font", hand_font)
	return label


# ---------- Clues: filters and marks ----------
# Every clue in the casebook, newest first, narrowed by person, day, place and topic (click a
# chip to step through its options, right-click to step back). Pick one to mark it important,
# doubtful or discarded: important clues about the accused are offered as evidence at a hearing.

const TOPICS := ["", "testimony", "evidence", "remark", "important", "doubtful"]
const TOPIC_NAMES := {"": "All", "testimony": "What people said", "evidence": "Your findings",
		"remark": "Your notes", "important": "Marked important", "doubtful": "Marked doubtful"}
const MARK_GLYPHS := {"important": "(!)", "doubtful": "?", "discarded": "–", "": "·"}
var clue_person := ""
var clue_day := 0
var clue_place := ""
var clue_topic := ""
var clue_sel := -1        # Index in GameState.entries of the clue picked on the left


func _build_clues() -> void:
	title.text = tr("Clues")
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	nights_box.add_child(chips)
	var people := [""]
	for npc in _chart_people_nodes():
		people.append(npc.data.npc_name)
	var days := [0]
	for d in range(GameState.day, 0, -1):
		days.append(d)
	var places := [""]
	places.append_array(GameState.PLACE_NAMES.keys())
	chips.add_child(_chip(tr("Person"), tr(clue_person) if clue_person != "" else tr("All"), func(step: int):
		clue_person = people[posmod(people.find(clue_person) + step, people.size())]))
	chips.add_child(_chip(tr("Day"), str(clue_day) if clue_day > 0 else tr("All"), func(step: int):
		clue_day = days[posmod(days.find(clue_day) + step, days.size())]))
	chips.add_child(_chip(tr("Place"), GameState.place_name(clue_place) if clue_place != "" else tr("All"), func(step: int):
		clue_place = places[posmod(places.find(clue_place) + step, places.size())]))
	chips.add_child(_chip(tr("Topic"), tr(TOPIC_NAMES[clue_topic]), func(step: int):
		clue_topic = TOPICS[posmod(TOPICS.find(clue_topic) + step, TOPICS.size())]))
	var holder := ScrollContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nights_box.add_child(holder)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(list)
	var shown := 0
	for i in range(GameState.entries.size() - 1, -1, -1):
		var entry: Dictionary = GameState.entries[i]
		if not _clue_matches(entry):
			continue
		shown += 1
		list.add_child(_clue_row(i, entry))
	if shown == 0:
		list.add_child(_ink_label(tr("Nothing yet.") if GameState.entries.is_empty() else tr("No clue matches these filters."), 15, true, INK_FADED))


func _clue_matches(entry: Dictionary) -> bool:
	if clue_person != "" and clue_person not in entry["people"]:
		return false
	if clue_day > 0 and int(entry["day"]) != clue_day:
		return false
	var mark: String = entry.get("mark", "")
	match clue_topic:
		"testimony", "evidence", "remark":
			if entry["kind"] != clue_topic:
				return false
		"important", "doubtful":
			if mark != clue_topic:
				return false
	if clue_place != "":
		# Place names come with their article ("the Tavern", "a taverna"): match the name itself
		var words := GameState.place_name(clue_place).split(" ", false)
		if words.size() > 1 and words[0].to_lower() in ["the", "a", "o", "la", "el", "os", "as"]:
			words.remove_at(0)
		if not String(entry["text"]).to_lower().contains(" ".join(words).to_lower()):
			return false
	return true


func _clue_row(index: int, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var mark: String = entry.get("mark", "")
	var glyph := _ink_label(MARK_GLYPHS[mark], 15, false, BLOOD_RED if mark == "important" else INK_FADED)
	glyph.custom_minimum_size.x = 26
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	text.add_theme_color_override("default_color", INK_FADED if mark == "discarded" else INK)
	var words := String(entry["text"]).replace("[", "[lb]")
	if mark == "discarded":
		words = "[s]" + words + "[/s]"
	elif index == clue_sel:
		words = "[b]" + words + "[/b]"
	text.text = words
	row.add_child(text)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clue_sel = index
			Audio.play("page", -12.0)
			_refresh.call_deferred())
	return row


# A filter chip: "Person: Sarah". Left click steps forward, right click back.
func _chip(label: String, value: String, step: Callable) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.15, 0.13, 0.06 if value == tr("All") else 0.14)
	style.border_color = Color(0.42, 0.33, 0.24, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	chip.add_theme_stylebox_override("panel", style)
	var text := _ink_label(label + ": " + value, 13, false, INK if value != tr("All") else INK_FADED)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(text)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			step.call(1 if event.button_index == MOUSE_BUTTON_LEFT else -1)
			Audio.play("page", -12.0)
			_refresh.call_deferred())
	return chip


# Right page: the clue picked, its marks, and what would go before the town
func _build_clue_detail() -> void:
	if clue_sel < 0 or clue_sel >= GameState.entries.size():
		suspect_list.add_child(_ink_label(tr("Pick a clue on the left to mark it."), 15, true, INK_FADED))
	else:
		var entry: Dictionary = GameState.entries[clue_sel]
		var text := _ink_label(entry["text"], 16, true)
		text.custom_minimum_size.x = 320
		suspect_list.add_child(text)
		var who := PackedStringArray()
		for person: String in entry["people"]:
			who.append(tr(person))
		suspect_list.add_child(_ink_label((tr("Day %d") % int(entry["day"])) + ("  ·  " + ", ".join(who) if not who.is_empty() else ""), 12, false, INK_FADED))
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		for pair in [["important", "Important"], ["doubtful", "Doubtful"], ["discarded", "Discard"]]:
			buttons.add_child(_mark_button(pair[0], tr(pair[1]), entry))
		suspect_list.add_child(buttons)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	suspect_list.add_child(spacer)
	var head := _ink_label(tr("For the hearing"), 15, false)
	head.add_theme_font_override("font", title.get_theme_font("font"))
	suspect_list.add_child(head)
	suspect_list.add_child(_ink_label(tr("Clues you mark important are offered as evidence when you bring someone before the town. Up to 3 go before them."), 12, true, INK_FADED))
	var marked := 0
	for i in range(GameState.entries.size() - 1, -1, -1):
		var e: Dictionary = GameState.entries[i]
		if e.get("mark", "") == "important":
			marked += 1
			if marked <= 5:
				var line := _ink_label("(!) " + String(e["text"]), 12, true, INK)
				line.max_lines_visible = 2
				suspect_list.add_child(line)
	if marked == 0:
		suspect_list.add_child(_ink_label(tr("None marked yet."), 12, false, INK_FADED))
	elif marked > 5:
		suspect_list.add_child(_ink_label(tr("…and %d more.") % (marked - 5), 12, false, INK_FADED))


func _mark_button(mark: String, text: String, entry: Dictionary) -> Control:
	var on: bool = entry.get("mark", "") == mark
	var button := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BLOOD_RED, 0.12) if on else Color(0, 0, 0, 0)
	style.border_color = BLOOD_RED if on else Color(0.42, 0.33, 0.24, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("panel", style)
	var label := _ink_label(text, 14, false, BLOOD_RED if on else INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			entry["mark"] = "" if on else mark
			Playtest.count("clues_marked_" + mark)
			Audio.play("page", -10.0)
			_refresh.call_deferred())
	return button
