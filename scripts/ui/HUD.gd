extends CanvasLayer

@onready var clock: Label = $Clock
@onready var controls: HBoxContainer = $Controls

const ICON_TALK := preload("res://assets/ui/icon_talk.png")
const ICON_EXAMINE := preload("res://assets/ui/icon_examine.png")
const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_ACCUSE := preload("res://assets/ui/icon_accuse.png")
const ICON_BOOK := preload("res://assets/ui/casebook.png")

var accuse_hint: Control  # Hidden on Day 1: no accusations yet
var hidden_note: Label    # Shown while the doctor is hidden in a bush or tall grass


func _ready() -> void:
	_build_hints()
	hidden_note = Label.new()
	hidden_note.position = Vector2(20.0, 38.0)  # Just under the clock
	hidden_note.add_theme_font_size_override("font_size", 18)
	hidden_note.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	hidden_note.add_theme_color_override("font_outline_color", Color.BLACK)
	hidden_note.add_theme_constant_override("outline_size", 8)
	hidden_note.visible = false
	add_child(hidden_note)


# The language can change on the title screen, after the HUD is built
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_build_hints()


func _build_hints() -> void:
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	_add_hint(null, "WASD", tr("Move"))
	_add_hint(ICON_TALK, "E", tr("Talk"))
	_add_hint(ICON_EXAMINE, "E", tr("Examine"))
	_add_hint(ICON_SLEEP, "E", tr("Sleep"))
	accuse_hint = _add_hint(ICON_ACCUSE, "Q", tr("Accuse"))
	_add_hint(ICON_BOOK, "Tab", tr("Casebook"))


func _process(_delta: float) -> void:
	var parts := PackedStringArray([tr("Day %d") % GameState.day, GameState.format_time(GameState.hour),
			tr("Night") if GameState.is_night else tr("Day")])
	if not GameState.is_night:
		parts.append(tr(GameState.weather_name()))
	parts.append(tr("%d coins") % GameState.coins)
	parts.append(tr("1 tonic") if GameState.tonics == 1 else tr("%d tonics") % GameState.tonics)
	clock.text = "   ·   ".join(parts)
	clock.modulate = Color(1.0, 0.45, 0.45) if GameState.exhaustion > 0.0 else Color.WHITE
	var player := get_tree().get_first_node_in_group("player")
	hidden_note.visible = player != null and player.has_method("is_hidden") and player.is_hidden()
	if hidden_note.visible:
		hidden_note.text = tr("Hidden: nobody can see you here")
	controls.visible = not GameState.in_dialogue
	accuse_hint.visible = GameState.day >= 2


# One control hint: [icon] KEY Action
func _add_hint(icon: Texture2D, key: String, action: String) -> Control:
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
	return box
