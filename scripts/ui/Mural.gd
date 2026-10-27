class_name Mural
extends CanvasLayer

# The outbreak map on the clinic wall (see the design doc, "Mural da Clínica").
# The cases pin themselves: every attack the town heard about and every bite the doctor found
# in an exam, at the victim's home, numbered by night. The rest is the player's: clues from the
# casebook pinned around the map, and red threads from a clue to a place on the map.
# It only exists here, at the clinic: a reason to come back.

const MAP_TEX := "res://assets/ui/mural/map.png"
const PAPER_TEX := "res://assets/ui/diary/sheet.png"  # Clean paper: the scrap art has scribbles of its own
const HAND_FONT := "res://assets/fonts/Caveat/Caveat-Regular.ttf"
const READING_TIME_SCALE := 0.25  # Same as the casebook: thinking is cheap, but not free
# The part of town the map shows, in world x and z (rendered from town.blend, art_source/mural)
const MAP_X := Vector2(-26.0, 20.0)
const MAP_Z := Vector2(-38.0, 26.0)  # North edge, south edge
const MAP_ASPECT := 702.0 / 977.0
const SLOTS_PER_SIDE := 4
const SNAP := 3.5               # Metres: a thread snaps to a place this close
const OLD_AFTER := 3            # Cases older than this many nights fade
const INK := Color("2C2621")
const THREAD := Color(0.6, 0.07, 0.05, 0.9)
const PIN := Color(0.72, 0.1, 0.08)
const PIN_EXAM := Color(0.42, 0.08, 0.1)
const WOOD := Color(0.2, 0.13, 0.08)
const CORK_DARK := Color(0.4, 0.28, 0.16)
const CORK_LIGHT := Color(0.62, 0.47, 0.3)

var is_open := false
var root: Control
var frame: Panel
var cork: TextureRect
var map_rect: TextureRect
var overlay: Control
var hint: Label
var tooltip: Label
var picker: PanelContainer
var picker_list: VBoxContainer
var picker_scroll: ScrollContainer
var picker_msg: Label
var hand: Font
var paper: Texture2D
var cards: Array[Control] = []
var selected := -1
var picker_items: Array[Dictionary] = []
var picker_index := 0
var cases: Array[Dictionary] = []   # {uv, label, lines, old, exam_only}
var places: Array[Dictionary] = []  # {name, label, pos (world), uv}


func _ready() -> void:
	layer = 6
	add_to_group("mural")
	if ResourceLoader.exists(HAND_FONT):
		hand = load(HAND_FONT)
	if ResourceLoader.exists(PAPER_TEX):
		paper = load(PAPER_TEX)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_board_input)
	root.resized.connect(_layout)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	frame = Panel.new()
	var wood := StyleBoxFlat.new()
	wood.bg_color = WOOD
	wood.set_corner_radius_all(4)
	wood.shadow_color = Color(0, 0, 0, 0.5)
	wood.shadow_size = 12
	frame.add_theme_stylebox_override("panel", wood)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	cork = TextureRect.new()
	cork.texture = _cork_texture()
	cork.stretch_mode = TextureRect.STRETCH_TILE
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cork)
	map_rect = TextureRect.new()
	if ResourceLoader.exists(MAP_TEX):
		map_rect.texture = load(MAP_TEX)
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_rect)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)  # Cards go above it (added later), threads start at their pins
	hint = Label.new()
	hint.text = tr("[E] Pin a clue    Click a clue, then the map: tie a thread    Right-click a clue: take it down    [Esc] Step back")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	tooltip = Label.new()
	tooltip.visible = false
	tooltip.add_theme_font_size_override("font_size", 17)
	tooltip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	tip_style.set_content_margin_all(8)
	tip_style.set_corner_radius_all(3)
	tooltip.add_theme_stylebox_override("normal", tip_style)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 10
	root.add_child(tooltip)
	_build_picker()


func _cork_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.09
	var ramp := Gradient.new()
	ramp.set_color(0, CORK_DARK)
	ramp.set_color(1, CORK_LIGHT)
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	return tex


# ---------- Opening and closing ----------

func open_board() -> void:
	if is_open:
		return
	is_open = true
	selected = -1
	_collect_places()
	_collect_cases()
	root.visible = true
	picker.visible = false
	_layout()
	Audio.play("page", -6.0)
	GameState.in_dialogue = true  # No talking, no casebook, no other prompts
	GameState.reading = true
	Engine.time_scale = READING_TIME_SCALE
	Playtest.count("mural_opened")


func close_board() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	GameState.in_dialogue = false
	GameState.reading = false
	Engine.time_scale = 1.0


func _notes() -> Array:
	if not GameState.mural.has("notes"):
		GameState.mural["notes"] = []
	return GameState.mural["notes"]


# ---------- What goes on the board ----------

func _collect_places() -> void:
	places.clear()
	for marker in get_tree().get_nodes_in_group("locations"):
		var node := marker as Node3D
		if node == null:
			continue
		# A map label, not a sentence: no article, capitalised ("the Clinic" -> "Clinic")
		var label := GameState.place_name(String(node.name))
		for article in ["the ", "a ", "o ", "la ", "el "]:
			if label.begins_with(article):
				label = label.trim_prefix(article)
				break
		label = label.left(1).to_upper() + label.substr(1)
		# Homes go by who lives there: shorter, and the names are what the player thinks in
		if String(node.name).begins_with("Casa"):
			var owners := PackedStringArray()
			for npc in get_tree().get_nodes_in_group("npcs"):
				if npc.data and npc.data.home == String(node.name):
					owners.append(tr(npc.data.npc_name))
			if not owners.is_empty():
				label = ", ".join(owners)
		var uv := _uv(node.global_position)
		if uv.x < 0.02 or uv.x > 0.98 or uv.y < 0.02 or uv.y > 0.98:
			continue
		places.append({"name": String(node.name), "label": label, "pos": node.global_position, "uv": uv})


func _collect_cases() -> void:
	cases.clear()
	var by_home := {}
	for attack: Dictionary in GameState.attacks:
		var home: String = attack["home"]
		var c: Dictionary = by_home.get(home, {"home": home, "nights": [], "lines": [], "latest": 0})
		c["nights"].append(int(attack["night"]))
		c["latest"] = maxi(int(c["latest"]), int(attack["night"]))
		if int(attack["night"]) <= 0:
			c["lines"].append(tr("Before you came: {name} died").format({"name": tr(attack["victim"])}))
		else:
			c["lines"].append(tr("Night {night}: {name} was attacked").format({"night": attack["night"], "name": tr(attack["victim"])}))
		by_home[home] = c
	# Bites the doctor found himself, the first time for each patient
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data == null:
			continue
		for record: Dictionary in npc.exams:
			if record.get("marks", false) or String(record.get("trace", "")) != "":
				var home: String = npc.data.home
				var c: Dictionary = by_home.get(home, {"home": home, "nights": [], "lines": [], "latest": 0})
				c["lines"].append(tr("Day {day}: you found bite marks on {name}").format({"day": record["day"], "name": tr(npc.data.npc_name)}))
				c["latest"] = maxi(int(c["latest"]), int(record["day"]) - 1)
				by_home[home] = c
				break
	for c: Dictionary in by_home.values():
		var nights: Array = c["nights"]
		nights.sort()
		# Night 0: before the doctor came (Clara's husband)
		var label: String = ", ".join(PackedStringArray(nights.map(func(n): return "†" if int(n) <= 0 else str(n)))) if not nights.is_empty() else "?"
		cases.append({"uv": _uv(GameState.place_position(c["home"])), "label": label, "lines": c["lines"],
				"old": int(c["latest"]) < GameState.last_night() - OLD_AFTER, "exam_only": nights.is_empty()})


# ---------- Layout ----------

func _layout() -> void:
	if not root.visible:
		return
	var screen := root.size
	var outer := Rect2(screen * Vector2(0.04, 0.04), screen * Vector2(0.92, 0.84))
	frame.position = outer.position
	frame.size = outer.size
	var inner := outer.grow(-18.0)
	cork.position = inner.position
	cork.size = inner.size
	var map_h := inner.size.y * 0.94
	var map_w := map_h * MAP_ASPECT
	if map_w > inner.size.x * 0.42:
		map_w = inner.size.x * 0.42
		map_h = map_w / MAP_ASPECT
	map_rect.size = Vector2(map_w, map_h)
	map_rect.position = inner.position + (inner.size - map_rect.size) * 0.5
	hint.position = Vector2(0, outer.end.y + 14)
	hint.size = Vector2(screen.x, 30)
	if picker:
		picker.position = (screen - picker.size) * 0.5
	_rebuild_cards()


func _slot_rect(slot: int) -> Rect2:
	var inner := Rect2(cork.position, cork.size)
	var column_w := (map_rect.position.x - inner.position.x) - 40.0
	var w := minf(column_w, 340.0)
	var gap := 14.0
	var h := (inner.size.y - gap * (SLOTS_PER_SIDE + 1)) / SLOTS_PER_SIDE
	var side := floori(slot / float(SLOTS_PER_SIDE))  # 0 left, 1 right
	var row := slot % SLOTS_PER_SIDE
	var x := inner.position.x + (column_w + 40.0 - w) * 0.5
	if side == 1:
		var map_right := map_rect.position.x + map_rect.size.x
		x = map_right + (inner.end.x - map_right - w) * 0.5
	return Rect2(Vector2(x, inner.position.y + gap + row * (h + gap)), Vector2(w, h))


func _rebuild_cards() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()
	var notes := _notes()
	for i in notes.size():
		var note: Dictionary = notes[i]
		var rect := _slot_rect(int(note["slot"]))
		var card := Panel.new()
		var style: StyleBox
		if paper:
			var tex_style := StyleBoxTexture.new()
			tex_style.texture = paper
			style = tex_style
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0.93, 0.89, 0.8)
			style = flat
		card.add_theme_stylebox_override("panel", style)
		card.position = rect.position
		card.size = rect.size
		card.rotation_degrees = [-1.5, 1.0, -0.6, 1.4][i % 4]
		card.pivot_offset = rect.size * 0.5
		card.modulate = Color(1.0, 0.86, 0.8) if i == selected else Color.WHITE
		var words := Label.new()
		words.text = String(note["text"])
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.clip_text = true
		words.add_theme_color_override("font_color", INK)
		words.add_theme_font_size_override("font_size", 22)
		if hand:
			words.add_theme_font_override("font", hand)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(words)
		words.position = Vector2(22, 24)
		words.size = rect.size - Vector2(44, 34)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var index := i
		card.gui_input.connect(func(event: InputEvent): _on_card_input(index, event))
		# The whole clue on hover: the paper only fits a few lines
		card.mouse_entered.connect(func(): _show_tip(String(note["text"]), rect.position + Vector2(0, rect.size.y + 6)))
		card.mouse_exited.connect(func(): tooltip.visible = false)
		root.add_child(card)
		root.move_child(card, overlay.get_index())  # Under the threads, so they show
		cards.append(card)
	overlay.queue_redraw()


# ---------- Drawing ----------

func _uv(world: Vector3) -> Vector2:
	return Vector2((world.x - MAP_X.x) / (MAP_X.y - MAP_X.x), (world.z - MAP_Z.x) / (MAP_Z.y - MAP_Z.x))


func _on_map(uv: Vector2) -> Vector2:
	return map_rect.position + uv * map_rect.size


func _card_pin(i: int) -> Vector2:
	var rect := _slot_rect(int(_notes()[i]["slot"]))
	return Vector2(rect.get_center().x, rect.position.y + 10.0)


func _draw_overlay() -> void:
	var font: Font = hand if hand else ThemeDB.fallback_font
	# Place names on little paper tags, in print so they read at a glance
	var print_font: Font = hint.get_theme_font("font")
	var placed_tags: Array[Rect2] = []
	for p: Dictionary in places:
		var at := _on_map(p["uv"])
		var label: String = p["label"]
		var text_size := print_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var tag := Rect2(at + Vector2(-text_size.x * 0.5 - 4, 10), text_size + Vector2(8, 0))
		# Neighbours close together: slide the tag below, then above, until it is clear
		for offset in [0.0, tag.size.y + 2.0, -(tag.size.y + 22.0), 2.0 * (tag.size.y + 2.0), -2.0 * (tag.size.y + 12.0)]:
			var tried := Rect2(tag.position + Vector2(0, offset), tag.size)
			var clear := true
			for other in placed_tags:
				if other.grow(1.0).intersects(tried):
					clear = false
					break
			if clear:
				tag = tried
				break
		placed_tags.append(tag)
		overlay.draw_rect(tag, Color(0.96, 0.92, 0.82, 0.92))
		overlay.draw_rect(tag, Color(INK, 0.5), false, 1.0)
		overlay.draw_string(print_font, tag.position + Vector2(4, text_size.y - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	# Threads: from each clue's pin to the places it is tied to, sagging a little
	var notes := _notes()
	for i in notes.size():
		var from := _card_pin(i)
		for link: Vector2 in notes[i].get("links", []):
			var to := _on_map(_uv(Vector3(link.x, 0.0, link.y)))
			var points := PackedVector2Array()
			var sag := minf(from.distance_to(to) * 0.06, 26.0)
			for s in 17:
				var t := s / 16.0
				points.append(from.lerp(to, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
			overlay.draw_polyline(points, Color(THREAD, 1.0 if i == selected else 0.85), 2.5 if i == selected else 2.0, true)
			overlay.draw_circle(to, 4.0, THREAD)
	# The cases: a red pin at each victim's home, with the nights
	for c: Dictionary in cases:
		var at := _on_map(c["uv"])
		var fade := 0.45 if c["old"] else 1.0
		var color: Color = PIN_EXAM if c["exam_only"] else PIN
		overlay.draw_circle(at + Vector2(1.5, 2.5), 9.0, Color(0, 0, 0, 0.35 * fade))
		overlay.draw_circle(at, 9.0, Color(color, fade))
		overlay.draw_circle(at + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.45 * fade))
		var label: String = c["label"]
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var box := Rect2(at + Vector2(11, -size.y * 0.5 - 2), size + Vector2(10, 4))
		overlay.draw_rect(box, Color(0.97, 0.94, 0.86, fade))
		overlay.draw_rect(box, Color(color, fade), false, 1.5)
		overlay.draw_string(font, box.position + Vector2(5, size.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, fade))
	# A pin at the top of each clue
	for i in notes.size():
		var pin := _card_pin(i)
		overlay.draw_circle(pin + Vector2(1.5, 2.5), 7.0, Color(0, 0, 0, 0.35))
		overlay.draw_circle(pin, 7.0, PIN)
		overlay.draw_circle(pin + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.5))


# ---------- Input ----------

func _on_card_input(index: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		selected = -1 if selected == index else index
		Audio.play("page", -12.0)
		_rebuild_cards()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_notes().remove_at(index)
		selected = -1
		Audio.play("page", -8.0)
		_rebuild_cards()


func _on_board_input(event: InputEvent) -> void:
	if picker.visible:
		return
	if event is InputEventMouseMotion:
		_update_tooltip(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var on_map := Rect2(map_rect.position, map_rect.size).has_point(event.position)
		if on_map and selected >= 0:
			_toggle_thread(selected, event.position)
		elif on_map:
			_flash_hint(tr("Click a clue first, then the place on the map it points to."))


func _show_tip(text: String, at: Vector2) -> void:
	tooltip.text = text
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.custom_minimum_size.x = 420
	tooltip.reset_size()
	tooltip.position = Vector2(clampf(at.x, 8.0, root.size.x - tooltip.size.x - 8.0), clampf(at.y, 8.0, root.size.y - tooltip.size.y - 8.0))
	tooltip.visible = true


func _update_tooltip(at: Vector2) -> void:
	for c: Dictionary in cases:
		if _on_map(c["uv"]).distance_to(at) < 14.0:
			_show_tip("\n".join(PackedStringArray(c["lines"])), at + Vector2(18, 12))
			return
	if tooltip.visible and not _over_card(at):
		tooltip.visible = false


func _over_card(at: Vector2) -> bool:
	for card in cards:
		if Rect2(card.position, card.size).has_point(at):
			return true
	return false


func _toggle_thread(index: int, screen_point: Vector2) -> void:
	var uv := (screen_point - map_rect.position) / map_rect.size
	var world := Vector2(MAP_X.x + uv.x * (MAP_X.y - MAP_X.x), MAP_Z.x + uv.y * (MAP_Z.y - MAP_Z.x))
	# Snap to the nearest place, so threads land on buildings
	var best := SNAP
	for p: Dictionary in places:
		var pos: Vector3 = p["pos"]
		var d := Vector2(pos.x, pos.z).distance_to(world)
		if d < best:
			best = d
			world = Vector2(pos.x, pos.z)
	var note: Dictionary = _notes()[index]
	var links: Array = note.get("links", [])
	for i in links.size():
		var existing: Vector2 = links[i]
		if existing.distance_to(world) < 1.0:
			links.remove_at(i)  # Tied there already: untie
			note["links"] = links
			Audio.play("click", -8.0)
			overlay.queue_redraw()
			return
	links.append(world)
	note["links"] = links
	Audio.play("click", -6.0)
	Playtest.count("mural_threads")
	overlay.queue_redraw()


var hint_tween: Tween

func _flash_hint(text: String) -> void:
	var normal := tr("[E] Pin a clue    Click a clue, then the map: tie a thread    Right-click a clue: take it down    [Esc] Step back")
	hint.text = text
	if hint_tween:
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.set_ignore_time_scale(true)
	hint_tween.tween_interval(2.5)
	hint_tween.tween_callback(func(): hint.text = normal)


func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if picker.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("notebook"):
			picker.visible = false
		elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			_pick_step(-1)
		elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			_pick_step(1)
		elif event.is_action_pressed("interact"):
			if picker_index >= 0 and picker_index < picker_items.size():
				_pin(picker_items[picker_index])
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("notebook"):
		close_board()
	elif event.is_action_pressed("interact"):
		_open_picker()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_select_step(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_select_step(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _select_step(step: int) -> void:
	var count := _notes().size()
	if count == 0:
		return
	selected = posmod(selected + step, count) if selected >= 0 else (0 if step > 0 else count - 1)
	_rebuild_cards()


# ---------- Pinning a clue from the casebook ----------

func _build_picker() -> void:
	picker = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	picker.add_theme_stylebox_override("panel", style)
	picker.custom_minimum_size = Vector2(760, 520)
	picker.visible = false
	picker.z_index = 20
	root.add_child(picker)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	picker.add_child(box)
	var title := Label.new()
	title.text = tr("Pin a clue to the wall")
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(716, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	picker_scroll = scroll
	picker_list = VBoxContainer.new()
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.add_theme_constant_override("separation", 4)
	scroll.add_child(picker_list)
	picker_msg = Label.new()
	picker_msg.text = tr("[W/S] Choose    [E] Pin    [Esc] Back")
	picker_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker_msg.add_theme_font_size_override("font_size", 17)
	box.add_child(picker_msg)


func _open_picker() -> void:
	if _free_slot() < 0:
		_flash_hint(tr("The wall is full. Right-click a clue to take it down first."))
		return
	picker_items.clear()
	var pinned := {}
	for note: Dictionary in _notes():
		pinned[note["text"]] = true
	var important: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for i in range(GameState.entries.size() - 1, -1, -1):  # Newest first
		var entry: Dictionary = GameState.entries[i]
		if pinned.has(entry["text"]) or entry.get("mark", "") == "discard":
			continue
		if entry.get("mark", "") == "important":
			important.append(entry)
		else:
			rest.append(entry)
	picker_items.append_array(important)
	picker_items.append_array(rest)
	picker_index = 0
	_fill_picker()
	picker.visible = true
	picker.reset_size()
	picker.position = (root.size - picker.size) * 0.5


func _fill_picker() -> void:
	for child in picker_list.get_children():
		child.queue_free()
	if picker_items.is_empty():
		var none := Label.new()
		none.text = tr("Your casebook has nothing to pin yet.")
		picker_list.add_child(none)
		return
	for i in picker_items.size():
		var entry: Dictionary = picker_items[i]
		var line := Label.new()
		var mark := "(!) " if entry.get("mark", "") == "important" else ""
		line.text = ("» " if i == picker_index else "   ") + mark + String(entry["text"])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 690
		line.add_theme_font_size_override("font_size", 18)
		if i == picker_index:
			line.add_theme_color_override("font_color", Color("C2A65B"))
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		line.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		line.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pin.call_deferred(entry))
		picker_list.add_child(line)
		if i == picker_index:
			picker_scroll.ensure_control_visible.call_deferred(line)  # W/S scrolls along


func _pick_step(step: int) -> void:
	if picker_items.is_empty():
		return
	picker_index = posmod(picker_index + step, picker_items.size())
	Audio.play("click", -10.0)
	_fill_picker()


func _free_slot() -> int:
	var used := {}
	for note: Dictionary in _notes():
		used[int(note["slot"])] = true
	for slot in SLOTS_PER_SIDE * 2:
		if not used.has(slot):
			return slot
	return -1


func _pin(entry: Dictionary) -> void:
	var slot := _free_slot()
	if slot < 0:
		return
	_notes().append({"text": entry["text"], "slot": slot, "links": []})
	picker.visible = false
	selected = _notes().size() - 1  # Ready to tie a thread from it
	Audio.play("page", -6.0)
	Playtest.count("mural_clues_pinned")
	_rebuild_cards()
	_flash_hint(tr("Now click the place on the map this clue points to."))
