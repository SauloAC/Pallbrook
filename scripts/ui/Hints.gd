class_name Hints
extends CanvasLayer

# Small one-time tips for the optional daytime activities, so players learn they exist without
# a tutorial step. Each shows once per session (like the tutorial, it survives restarts), sits
# below the tutorial panel and fades away on its own.

const SHOW_FOR := 9.0
const CHECK_EVERY := 0.5

var panel: PanelContainer
var label: Label
var timer := 0.0
var showing := 0.0


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.82)
	style.border_color = Color(0.55, 0.62, 0.7, 0.8)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -380.0
	panel.offset_right = -14.0
	panel.offset_top = 250.0   # Below the tutorial panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 340.0
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)


func _process(delta: float) -> void:
	if get_tree().paused or not GameState.intro_seen:
		panel.visible = false
		return
	if showing > 0.0:
		showing -= delta
		panel.visible = not GameState.reading
		if showing <= 0.0:
			var tween := create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.6)
			tween.tween_callback(func(): panel.visible = false)
		return
	timer += delta
	if timer < CHECK_EVERY:
		return
	timer = 0.0
	if GameState.is_night:
		return
	if GameState.day <= 2 and GameState.hour >= 11.5 and GameState.hour < 12.6:
		_show("lunch", "At noon the town eats at the tavern. Sit at the patio tables and you will hear a great deal.")
	elif GameState.open_building == "Prefeitura":
		_show("records", "The town register is on the clerk's desk. Going through it takes two hours.")


func _show(key: String, text: String) -> void:
	if GameState.hints_seen.has(key):
		return
	GameState.hints_seen[key] = true
	label.text = tr(text)
	panel.modulate = Color(1, 1, 1, 0)
	panel.visible = true
	showing = SHOW_FOR
	Audio.play("page", -10.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
