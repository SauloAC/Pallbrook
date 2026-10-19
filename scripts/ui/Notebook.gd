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

var filter := ALL  # ALL, EVIDENCE or a person's name
var filter_bar: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the game is paused
	panel.visible = false
	# Filter buttons, built in code right under the title
	filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 18)
	var vbox := $Panel/Pages/VBox
	vbox.add_child(filter_bar)
	vbox.move_child(filter_bar, title.get_index() + 1)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("notebook"):
		return
	if panel.visible:
		_close()
	elif not GameState.in_dialogue and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	_refresh()
	panel.visible = true
	get_tree().paused = true  # Time stops while reading


func _close() -> void:
	panel.visible = false
	get_tree().paused = false


func _set_filter(value: String) -> void:
	# Clicking the active person again goes back to everything
	filter = ALL if value == filter and value != ALL else value
	_refresh()


func _refresh() -> void:
	_build_filter_bar()
	_build_suspects()
	_build_entries()


# ---------- Left page ----------

func _build_filter_bar() -> void:
	_clear(filter_bar)
	filter_bar.add_child(_link("All", ALL))
	filter_bar.add_child(_link("Evidence", EVIDENCE))


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
	match filter:
		ALL:
			title.text = "Casebook"
		EVIDENCE:
			title.text = "Evidence"
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


func _matches(entry: Dictionary) -> bool:
	match filter:
		ALL:
			return true
		EVIDENCE:
			return entry["kind"] == "evidence"
	return filter in entry["people"]


# ---------- Right page ----------

func _build_suspects() -> void:
	_clear(suspect_list)
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data == null:
			continue
		var name_text: String = npc.data.npc_name
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var pic := TextureRect.new()
		pic.texture = npc.data.portrait
		pic.custom_minimum_size = Vector2(56, 56)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)

		var label := Label.new()
		label.text = "%s\n%s" % [name_text, npc.data.role]
		if filter == name_text:
			label.text = "» " + label.text
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 18)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		if not npc.is_alive():
			label.text += " · deceased"
			row.modulate = Color(1, 1, 1, 0.45)  # Faded: no longer a suspect
		elif filter != ALL and filter != EVIDENCE and filter != name_text:
			row.modulate = Color(1, 1, 1, 0.7)   # Someone else is selected

		_make_clickable(row, name_text)
		suspect_list.add_child(row)


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
