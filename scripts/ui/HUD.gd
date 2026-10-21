extends CanvasLayer

@onready var clock: Label = $Clock
@onready var controls: HBoxContainer = $Controls

const ICON_TALK := preload("res://assets/ui/icon_talk.png")
const ICON_EXAMINE := preload("res://assets/ui/icon_examine.png")
const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_ACCUSE := preload("res://assets/ui/icon_accuse.png")
const ICON_BOOK := preload("res://assets/ui/casebook.png")


func _ready() -> void:
	_add_hint(null, "WASD", "Move")
	_add_hint(ICON_TALK, "E", "Talk")
	_add_hint(ICON_EXAMINE, "E", "Examine")
	_add_hint(ICON_SLEEP, "E", "Sleep")
	_add_hint(ICON_ACCUSE, "Q", "Accuse")
	_add_hint(ICON_BOOK, "Tab", "Casebook")


func _process(_delta: float) -> void:
	var phase := "Night" if GameState.is_night else "Day"
	clock.text = "Day %d   ·   %s   ·   %s   ·   %d coins   ·   %d tonic%s" % [GameState.day,
			GameState.format_time(GameState.hour), phase, GameState.coins, GameState.tonics,
			"" if GameState.tonics == 1 else "s"]
	clock.modulate = Color(1.0, 0.45, 0.45) if GameState.exhaustion > 0.0 else Color.WHITE
	controls.visible = not GameState.in_dialogue


# One control hint: [icon] KEY Action
func _add_hint(icon: Texture2D, key: String, action: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	if icon:
		var pic := TextureRect.new()
		pic.texture = icon
		pic.custom_minimum_size = Vector2(40, 40)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(pic)

	var label := Label.new()
	label.text = "%s  %s" % [key, action]
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_font_size_override("font_size", 16)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)

	controls.add_child(box)
