extends Node

# Player settings that aren't the language (see Lang.gd), saved in user://settings.cfg.
# Brightness: B cycles it anywhere in the game (the town at night can be too dark on some
# screens). It is a gamma curve over the 3D picture: dark areas lift a lot, bright ones
# barely move, and the menus and text stay as they are. Works with any renderer.

signal changed

const SETTINGS := "user://settings.cfg"
const BRIGHTNESS_STEPS := [0.8, 1.0, 1.2, 1.4, 1.6]

var brightness := 1.0
var toast: Label
var toast_timer := 0.0
var gamma_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works on the title screen, while the town is paused
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		brightness = float(cfg.get_value("video", "brightness", 1.0))
	# Gamma pass: drawn over the 3D world but under every other screen layer (HUD, dialogue...)
	var gamma_layer := CanvasLayer.new()
	gamma_layer.layer = -10
	add_child(gamma_layer)
	gamma_rect = ColorRect.new()
	gamma_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	gamma_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/gamma.gdshader")
	gamma_rect.material = material
	gamma_layer.add_child(gamma_rect)
	_apply_gamma()
	# A small notice in the middle of the screen when brightness changes
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(326.0, 120.0)
	toast.size = Vector2(500.0, 40.0)
	toast.visible = false
	layer.add_child(toast)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		next_brightness()
		get_viewport().set_input_as_handled()


func next_brightness() -> void:
	var i := BRIGHTNESS_STEPS.find(brightness)
	brightness = BRIGHTNESS_STEPS[(i + 1) % BRIGHTNESS_STEPS.size()]
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)  # Keep the language and anything else already saved
	cfg.set_value("video", "brightness", brightness)
	cfg.save(SETTINGS)
	_apply_gamma()
	toast.text = brightness_label()
	toast.visible = true
	toast_timer = 1.5
	Audio.play("click", -10.0)
	changed.emit()


func _apply_gamma() -> void:
	(gamma_rect.material as ShaderMaterial).set_shader_parameter("gamma", brightness)
	gamma_rect.visible = not is_equal_approx(brightness, 1.0)  # No extra pass at 100%


func brightness_label() -> String:
	return tr("Brightness: %d%%") % roundi(brightness * 100.0)


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast.visible = false
