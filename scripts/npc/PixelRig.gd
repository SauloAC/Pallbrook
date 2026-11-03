class_name PixelRig
extends Node3D

# Prototype (3 Nov): a 3D body drawn as pixel art. The model and its rig animations stay as they
# are, but it is rendered in a tiny world of its own (a SubViewport) at the painted buildings'
# pixel size, and that picture stands in the town like the PixelLab sprites do. So every clip of
# the shared rig (walk, sit, fall, pick up...) and every direction come for free.
# Flat colours: toon shading in two bands, no smoothing, and a 1 px dark outline drawn around the
# finished picture (a second little 2D pass), so only the silhouette is outlined, not every piece.

const PX := 0.04375            # Metres per pixel: the painted buildings' (32 px a unit, town scaled 1.4)
const STEP_FPS := 12.0         # The picture is redrawn this many times a second, like hand-drawn frames:
                               # in between it holds still, so the edge pixels don't crawl every frame
const SIN50 := 0.76604444      # The town camera's pitch: a step of PX / SIN50 north is one pixel up the screen
const COS50 := 0.64278761
const VIEW_PULL := 0.6         # Metres toward the camera (see build)
const SIZE := Vector2i(72, 80) # The picture: room for arms out and a body lying down
const FOOT_ROW := 26           # Pixels from the bottom of the picture to the feet (room to fall forward)
const PITCH := 25.0            # Degrees the little camera looks down: the buildings are painted nearly
                               # from the front, so a steeper view makes the body look short
const UPRIGHT := 1.5557238     # 1 / cos(50 deg), as for the sprites
const OUTLINE_COLOR := Color(0.09, 0.07, 0.07)
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform sampler2D src : filter_nearest;
uniform vec4 line : source_color;
void fragment() {
	vec4 c = texture(src, UV);
	if (c.a >= 0.5) {
		COLOR = vec4(c.rgb, 1.0);
	} else {
		vec2 px = 1.0 / vec2(textureSize(src, 0));
		float n = max(max(texture(src, UV + vec2(px.x, 0.0)).a, texture(src, UV - vec2(px.x, 0.0)).a),
				max(texture(src, UV + vec2(0.0, px.y)).a, texture(src, UV - vec2(0.0, px.y)).a));
		COLOR = n >= 0.5 ? line : vec4(0.0);
	}
}
"""

var viewport: SubViewport
var pivot: Node3D              # Holds the body inside the little world; turned like the character
var sprite: Sprite3D           # The picture, standing in the town
var outlined: SubViewport      # The picture with its outline (what the sprite shows)
var body_mat: ShaderMaterial
const BODY_SHADER := preload("res://assets/characters/pixel_body.gdshader")
var step_time := 0.0


func build(body: Node3D) -> void:
	top_level = true  # Placed by hand each frame: the character's turns go to the body, not the picture
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # It follows the interpolated character itself (sync)
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.scaling_3d_scale = 1.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # Then once per step (see _process)
	add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.95)
	env.ambient_light_energy = 0.75  # Bright in here: the town's own light and shadow darken the picture after
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)  # From the upper left, toward the viewer
	light.light_energy = 0.7
	viewport.add_child(light)

	pivot = Node3D.new()
	viewport.add_child(pivot)
	pivot.add_child(body)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = SIZE.y * PX
	cam.near = 0.1
	cam.far = 60.0
	var p := deg_to_rad(PITCH)
	var forward := Vector3(0.0, -sin(p), -cos(p))
	# The point the camera centres on: chosen so the feet land FOOT_ROW pixels above the bottom
	var target := Vector3(0.0, (SIZE.y / 2.0 - FOOT_ROW) * PX / cos(p), 0.0)
	cam.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), target - forward * 20.0)
	viewport.add_child(cam)

	# The outline pass: the picture again, with a dark pixel wherever an empty pixel touches the body
	outlined = SubViewport.new()
	outlined.size = SIZE
	outlined.transparent_bg = true
	outlined.disable_3d = true
	outlined.render_target_update_mode = SubViewport.UPDATE_ONCE  # Then the frame after each step (see _process)
	add_child(outlined)
	var line_shader := Shader.new()
	line_shader.code = OUTLINE_SHADER
	var line_mat := ShaderMaterial.new()
	line_mat.shader = line_shader
	line_mat.set_shader_parameter("src", viewport.get_texture())
	line_mat.set_shader_parameter("line", OUTLINE_COLOR)
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE)
	rect.material = line_mat
	outlined.add_child(rect)

	sprite = Sprite3D.new()
	sprite.texture = outlined.get_texture()
	sprite.pixel_size = PX
	# Lit like the painted buildings (see pixel_body.gdshader). No billboard needed: the town camera
	# never turns, and an unturned sprite already faces it
	body_mat = ShaderMaterial.new()
	body_mat.shader = BODY_SHADER
	body_mat.set_shader_parameter("tex", outlined.get_texture())
	sprite.material_override = body_mat
	sprite.scale.y = UPRIGHT
	sprite.position.y = (SIZE.y / 2.0 - FOOT_ROW) * PX * UPRIGHT  # Feet on the ground
	# ...and pulled toward the town camera along its line of sight: it looks exactly the same, but
	# the ground and the bench he sits on no longer cut into the feet and legs
	sprite.position += Vector3(0.0, SIN50, COS50) * VIEW_PULL
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)


# Two-band shading and no shine on every surface of a body (also the night shade). The outline is
# drawn around the finished picture instead (OUTLINE_SHADER)
func flatten(body: Node3D) -> void:
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			if mi.get_surface_override_material(i) != m:
				m = m.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(i, m)
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = 1.0
			m.metallic = 0.0


var outline_due := false

func _process(delta: float) -> void:
	if outline_due:  # The body was drawn last frame: now its outline
		outline_due = false
		outlined.render_target_update_mode = SubViewport.UPDATE_ONCE
	step_time += delta
	if step_time >= 1.0 / STEP_FPS:
		step_time = fmod(step_time, 1.0 / STEP_FPS)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		outline_due = true


# Pallor and greys (CharacterVisual.tint), and the dithered see-through of a hidden doctor
func set_tint(color: Color) -> void:
	body_mat.set_shader_parameter("tint", color)


func set_fade(amount: float) -> void:
	body_mat.set_shader_parameter("fade", amount)


# Every frame: follow the character, and turn (or lay down) the body the way the character is turned.
# The picture moves in whole pixels of the town (east-west by PX, north-south by what makes one
# pixel on screen; not up-down, which could sink the feet), so it doesn't swim against the painted buildings as it walks.
func sync(owner_node: Node3D) -> void:
	var xf := owner_node.get_global_transform_interpolated()  # Where it is drawn this frame, between physics ticks
	var p := xf.origin
	global_position = Vector3(snappedf(p.x, PX), p.y, snappedf(p.z, PX / SIN50))
	pivot.basis = Basis(xf.basis.get_rotation_quaternion())
