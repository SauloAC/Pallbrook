extends CanvasLayer

const INTRO := "Autumn.\n\nPallbrook's doctor vanished one night without a word. Since then, a strange anemia has spread through the town: people wake pale and weak, and some no longer wake at all.\n\nYou are the physician sent to stop the outbreak.\n\nBy day, visit the sick, examine them and ask what they saw. By night, get back to the clinic before 1 AM.\n\nThis sickness has a cause, and it walks among them. When you are sure who it is, accuse them. You only get one chance."

@onready var background: Control = $Background
@onready var title: Label = $Background/Title
@onready var body: Label = $Background/Body
@onready var hint: Label = $Background/Hint

const SCREEN_HEIGHT := 648.0  # Background is laid out at 1152 x 648
const ICON_LANGUAGE := preload("res://assets/ui/icon_language.png")
const ICON_BRIGHTNESS := preload("res://assets/ui/icon_brightness.png")
var language_note: Label      # "[L] Change language" in the top-right corner
var disclaimer: Label         # Work-in-progress notice along the bottom edge
var language_flag: TextureRect
var language_box: PanelContainer
var brightness_box: PanelContainer
var brightness_note: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameState.intro_seen:
		background.visible = false
		return
	_build_layout()
	_show_text()
	get_tree().paused = true  # The town waits until the player is ready


func _input(event: InputEvent) -> void:
	if not background.visible or GameState.intro_seen:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		get_viewport().set_input_as_handled()
		_switch_language()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # This E must not also trigger the player
		GameState.intro_seen = true
		Audio.start_game()  # Title theme fades out, the town's music fades in
		get_tree().paused = false
		var tween := create_tween()
		tween.tween_property(background, "modulate:a", 0.0, 1.5)  # Fade into the town
		await tween.finished
		background.visible = false


# A little more room for the story (some languages run longer than English),
# and the language note in the corner
func _build_layout() -> void:
	title.position.y = 36.0
	body.position.y = 128.0
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_constant_override("line_spacing", -2)
	# Top-right corner: [globe] [L] Change language [flag] English. A click works like L,
	# so someone who pressed L by accident can see what happened and switch back.
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.55)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	box.add_theme_stylebox_override("panel", style)
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_switch_language())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var globe := TextureRect.new()
	globe.texture = ICON_LANGUAGE
	globe.custom_minimum_size = Vector2(22, 22)
	globe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	globe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(globe)
	language_note = Label.new()
	language_note.add_theme_font_size_override("font_size", 15)
	language_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(language_note)
	language_flag = TextureRect.new()
	language_flag.custom_minimum_size = Vector2(27, 18)
	language_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	language_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	language_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(language_flag)
	background.add_child(box)
	language_box = box
	# Under it, the same kind of box for brightness (B also works during the game)
	brightness_box = PanelContainer.new()
	brightness_box.add_theme_stylebox_override("panel", style)
	brightness_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	brightness_box.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Settings.next_brightness())
	var sun_row := HBoxContainer.new()
	sun_row.add_theme_constant_override("separation", 8)
	sun_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brightness_box.add_child(sun_row)
	var sun_icon := TextureRect.new()
	sun_icon.texture = ICON_BRIGHTNESS
	sun_icon.custom_minimum_size = Vector2(22, 22)
	sun_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sun_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sun_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun_row.add_child(sun_icon)
	brightness_note = Label.new()
	brightness_note.add_theme_font_size_override("font_size", 15)
	brightness_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brightness_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun_row.add_child(brightness_note)
	background.add_child(brightness_box)
	Settings.changed.connect(_show_text)
	# Testers must know this is not the finished game
	disclaimer = Label.new()
	disclaimer.add_theme_font_size_override("font_size", 13)
	disclaimer.modulate = Color(1, 1, 1, 0.65)
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disclaimer.position = Vector2(126.0, SCREEN_HEIGHT - 40.0)
	disclaimer.size = Vector2(900.0, 34.0)
	disclaimer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	background.add_child(disclaimer)


# Text in the current language; "Begin" sits just under the story, wherever it ends
func _show_text() -> void:
	title.text = "PALLBROOK"  # The name stays in Latin letters, like a logo
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.text = tr(INTRO)
	hint.text = tr("[E] Begin")
	language_note.text = "[L] %s  ·  %s" % [tr("Change language"), Lang.locale_label()]
	language_flag.texture = Lang.flag()
	brightness_note.text = "[B] " + Settings.brightness_label()
	disclaimer.text = tr("Development build {version}. This game is still in development: this is not the final version, and every aspect of the game is subject to change.").format({"version": Playtest.VERSION})
	await get_tree().process_frame  # Let the labels grow to fit the new text first
	# Keep the language box in the top-right corner, however long the language name is
	# The background picture is wider than the screen, so measure the screen itself
	var screen_width := get_viewport().get_visible_rect().size.x
	language_box.reset_size()
	language_box.position = Vector2(screen_width - language_box.size.x - 14.0, 14.0)
	brightness_box.reset_size()
	brightness_box.position = Vector2(screen_width - brightness_box.size.x - 14.0, 14.0 + language_box.size.y + 6.0)
	body.size.y = 0.0
	var story_end := body.position.y + body.get_combined_minimum_size().y
	hint.position.y = minf(story_end + 14.0, SCREEN_HEIGHT - hint.size.y - 44.0)  # Clear of the notice below


func _switch_language() -> void:
	Lang.next_locale()
	Audio.play("click", -10.0)
	_show_text()
