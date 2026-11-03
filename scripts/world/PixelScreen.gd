class_name PixelScreen
extends CanvasLayer

# Test (3 Nov): the whole town drawn at the painted buildings' pixel size. Every frame the finished
# 3D picture is redrawn in blocks of one town pixel (0.04375 m) each, with the block grid fixed to the
# world, so the 3D grass, trees, water and props become pixel art of the same grain as the 2D
# buildings, and nothing crawls when the camera glides. The UI draws above it, untouched.
# F7 turns it on and off, to compare (it starts off).

const PX := 0.04375                # The buildings' pixel, in metres (32 px a unit, town scaled 1.4)
const LEVELS := 0.0                # Colour steps per channel (0 = off; 12-24 gives a posterised look)
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float rows = 365.0;     // Town pixels from the top of the screen to the bottom
uniform vec2 phase = vec2(0.0); // Where a town pixel starts on screen, in screen pixels
uniform float levels = 0.0;
void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	float block = size.y / rows;
	vec2 cell = floor((FRAGCOORD.xy - phase) / block);
	vec2 at = (cell + 0.5) * block + phase;
	vec3 c = textureLod(screen, at * SCREEN_PIXEL_SIZE, 0.0).rgb;
	if (levels > 0.0) {
		c = floor(c * levels + 0.5) / levels;
	}
	COLOR = vec4(c, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var camera: Camera3D


func _ready() -> void:
	layer = -1  # Over the 3D town, under every UI layer
	camera = get_parent() as Camera3D
	var shader := Shader.new()
	shader.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("levels", LEVELS)
	rect = ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	rect.visible = false  # Off to start: with the painted greenery (Nature2D) it isn't needed


func _process(_delta: float) -> void:
	if camera == null or not rect.visible:
		return
	var rows := camera.size / PX
	var screen := get_viewport().get_visible_rect().size * get_viewport().get_final_transform().get_scale()
	var block := screen.y / rows
	# The world's pixel lines, as the camera sees them: east-west along the camera's x, and up the
	# screen along its up axis (the ground's rows and the facades' rows both land there, one per PX)
	var up := camera.global_basis.y
	var across := camera.global_position.x / PX
	var along := camera.global_position.dot(up) / PX
	var phase := Vector2(fposmod(screen.x / 2.0 - across * block, block), fposmod(screen.y / 2.0 + along * block, block))
	mat.set_shader_parameter("rows", rows)
	mat.set_shader_parameter("phase", phase)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7 and OS.is_debug_build():
		rect.visible = not rect.visible
		get_viewport().set_input_as_handled()
