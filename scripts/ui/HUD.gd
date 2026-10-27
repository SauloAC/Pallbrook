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
var chase_note: Label     # Shown while the vampire is chasing him
var doom_note: Label      # It knows his face: nights left before it comes for him


func _ready() -> void:
	_build_hints()
	add_child(Tutorial.new())  # The guided first day (top-right corner)
	hidden_note = Label.new()
	hidden_note.position = Vector2(20.0, 38.0)  # Just under the clock
	hidden_note.add_theme_font_size_override("font_size", 18)
	hidden_note.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	hidden_note.add_theme_color_override("font_outline_color", Color.BLACK)
	hidden_note.add_theme_constant_override("outline_size", 8)
	hidden_note.visible = false
	add_child(hidden_note)
	chase_note = Label.new()
	chase_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chase_note.position = Vector2(276.0, 90.0)
	chase_note.size = Vector2(600.0, 40.0)
	chase_note.add_theme_font_size_override("font_size", 26)
	chase_note.add_theme_color_override("font_outline_color", Color.BLACK)
	chase_note.add_theme_constant_override("outline_size", 10)
	chase_note.visible = false
	add_child(chase_note)
	doom_note = Label.new()
	doom_note.position = Vector2(20.0, 62.0)  # Under the hidden note
	doom_note.add_theme_font_size_override("font_size", 18)
	doom_note.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	doom_note.add_theme_color_override("font_outline_color", Color.BLACK)
	doom_note.add_theme_constant_override("outline_size", 8)
	add_child(doom_note)


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
	chase_note.visible = GameState.chased
	if GameState.chased:
		var zones := get_tree().get_first_node_in_group("safe_zones")
		var safe: bool = player != null and zones != null and zones.is_safe(player.global_position)
		chase_note.text = tr("It won't follow you here.") if safe else tr("It's coming after you. Run!")
		chase_note.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7) if safe else Color(0.9, 0.25, 0.2))
		hidden_note.visible = false  # A bush won't hide him from something that saw him go in
	var left := GameState.nights_left()
	doom_note.visible = left >= 0 and not GameState.game_over
	if left > 0:
		doom_note.text = tr("It knows your face. Nights left: %d") % left
	elif left == 0:
		doom_note.text = tr("It knows your face. Tonight it comes for you.")
	if not GameState.hearing.is_empty():
		doom_note.visible = true
		doom_note.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		doom_note.text = Lang.contract(tr("Hearing against {name}: Day {day}, 7 PM").format({"name": tr(GameState.hearing["accused"]), "day": GameState.hearing["day"]})) + \
				(("   ·   " + doom_note.text) if left >= 0 else "")
	else:
		doom_note.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
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
