extends CanvasLayer


@onready var panel: Control = $Panel
@onready var entries: Label = $Panel/Pages/VBox/Scroll/Entries
@onready var suspect_list: VBoxContainer = $Panel/Pages/Suspects/List

const INK := Color("2C2621")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Must work while the game is paused
	panel.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("notebook"):
		return
	if panel.visible:
		_close()
	elif not GameState.in_dialogue and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	if GameState.clues.is_empty():
		entries.text = "No clues yet."
	else:
		entries.text = "• " + "\n\n• ".join(PackedStringArray(GameState.clues))
	_build_suspects()
	panel.visible = true
	get_tree().paused = true  # Time stops while reading
	
	
func _close() -> void:
	panel.visible = false
	get_tree().paused = false


func _build_suspects() -> void:
	# Clear the old rows (the list is rebuilt every time the book opens)
	for child in suspect_list.get_children():
		suspect_list.remove_child(child)
		child.queue_free()

	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var pic := TextureRect.new()
		pic.texture = npc.data.portrait
		pic.custom_minimum_size = Vector2(56, 56)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(pic)

		var label := Label.new()
		label.text = "%s\n%s" % [npc.data.npc_name, npc.data.role]
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 18)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		if not npc.is_alive():
			label.text += " · deceased"
			row.modulate = Color(1, 1, 1, 0.45)  # Faded: no longer a suspect

		suspect_list.add_child(row)
