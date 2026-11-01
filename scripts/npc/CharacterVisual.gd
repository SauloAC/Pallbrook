class_name CharacterVisual
extends Node3D

# A townsperson's 3D body: model, colors, animations and the night tints.
# Models are the Quaternius "Ultimate Animated Character Pack" (CC0).

const MODEL_DIR := "res://assets/models/characters/"
const SCALE := 0.51         # The pack's people are ~3.3 m tall; this makes them ~1.7 m, so the kit's doors and rooms read right
const TURN_SPEED := 10.0
const PALE := Color(0.92, 0.9, 0.88)

# Who wears what: model file and colors per material name
const LOOKS := {
	"Elias":  ["Suit_Male", {"Skin": Color(0.86, 0.70, 0.60), "Black": Color(0.10, 0.10, 0.11), "Shirt": Color(0.12, 0.12, 0.13),
			"Details": Color(0.10, 0.10, 0.11), "Belt": Color(0.10, 0.10, 0.11), "Hair": Color(0.62, 0.62, 0.62)}],
	"Hugo":   ["OldClassy_Male", {"Skin": Color(0.88, 0.72, 0.62), "Pants": Color(0.14, 0.25, 0.14), "Detail": Color(0.30, 0.20, 0.10),
			"Hair": Color(0.80, 0.80, 0.80)}],
	"Marta":  ["Chef_Female", {"Skin": Color(0.42, 0.27, 0.19), "Clothes": Color(0.36, 0.24, 0.17), "Band": Color(0.50, 0.10, 0.12),
			"DarkClothes": Color(0.48, 0.12, 0.14), "Hair": Color(0.10, 0.07, 0.05)}],
	"Clara":  ["Casual_Female", {"Skin": Color(0.90, 0.75, 0.65), "Shirt": Color(0.20, 0.32, 0.55), "Pants": Color(0.16, 0.20, 0.32),
			"Hair": Color(0.38, 0.22, 0.12)}],
	"Tomas":  ["Worker_Male", {"Skin": Color(0.80, 0.60, 0.48), "Shirt": Color(0.55, 0.50, 0.42), "Vest": Color(0.28, 0.17, 0.10),
			"Pants": Color(0.20, 0.16, 0.12), "Hat": Color(0.18, 0.16, 0.14)}],
	"Sophia": ["Casual3_Female", {"Skin": Color(0.40, 0.26, 0.18), "Shirt": Color(0.78, 0.60, 0.18), "Pants": Color(0.15, 0.15, 0.18),
			"Hair": Color(0.08, 0.06, 0.05)}],
	"Sarah":  ["Suit_Female", {"Skin": Color(0.88, 0.72, 0.58), "Black": Color(0.15, 0.16, 0.18), "Shirt": Color(0.20, 0.48, 0.46),
			"Details": Color(0.15, 0.16, 0.18), "Hair": Color(0.06, 0.05, 0.05)}],
	# The merchant beyond the bridge (not a townsperson: no schedule, never a suspect)
	"Gideon": ["Worker_Male", {"Skin": Color(0.78, 0.6, 0.48), "Shirt": Color(0.72, 0.68, 0.58), "Vest": Color(0.22, 0.3, 0.2),
			"Pants": Color(0.28, 0.22, 0.16), "Hat": Color(0.32, 0.3, 0.27)}],
	"Doctor": ["Doctor_Male_Young", {"Skin": Color(0.85, 0.68, 0.56), "Main": Color(0.88, 0.86, 0.80), "Black": Color(0.35, 0.30, 0.25),
			"Brown": Color(0.18, 0.15, 0.13), "Hair": Color(0.25, 0.17, 0.10)}],
}

# At night the hunter wears no face: a plain, shared body instead of their own
const SHADE_MODEL := "BaseCharacter"

# Test (31 Oct): pixel-art sprites from PixelLab instead of the 3D body, for whoever has a
# folder here (rotations/<dir>.png, animations/walk/<dir>/frame_NNN.png, animations/idle/<dir>/...).
# The sprite always faces the camera; directions without their own walk are borrowed (west
# mirrors east). Everything else (bed, death, pallor, the night shade) works as for the bodies.
# Test over (31 Oct): the 3D bodies animate better, so nobody uses a sprite now. To try one again:
# "Tomas": "res://assets/characters/sprites/tomas/", "Doctor": "res://assets/characters/sprites/doctor/"
const SPRITES := {}
const DIRS := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
const SPRITE_PIXEL := 0.0215   # 80 px canvas, ~79 px of body -> about 1.7 m
const SPRITE_FPS := {"walk": 10.0, "idle": 5.0}
var sprite: AnimatedSprite3D
var facing := "south"
var sprite_tint := Color.WHITE
var xray: MeshInstance3D       # The doctor's outline through walls (see make_xray)
var xray_mat: ShaderMaterial
const XRAY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_inverted, blend_mix;
uniform sampler2D frame_tex : filter_nearest, source_color;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool flip = false;
void vertex() {
	// Face the camera like the sprite does
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 uv = UV;
	if (flip) { uv.x = 1.0 - uv.x; }
	if (texture(frame_tex, uv).a < 0.5) { discard; }
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
"""

var anim: AnimationPlayer
var model: Node3D             # This person's own body
var own_anim: AnimationPlayer
var shade: Node3D             # The faceless night body, made the first time it's needed
var shade_anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var skin: StandardMaterial3D
var skin_color := Color.WHITE
var clothes: Array[StandardMaterial3D] = []   # Everything but skin and eyes, for the servant grey
var clothes_colors: Array[Color] = []
var current := ""
var dead := false
var target_yaw := 0.0
var dark_overlay: StandardMaterial3D


# Returns false when this person has no model yet (the capsule stays)
func setup(look: String) -> bool:
	if SPRITES.has(look) and _setup_sprite(SPRITES[look]):
		return true
	if not LOOKS.has(look):
		return false
	var entry: Array = LOOKS[look]
	var path: String = MODEL_DIR + str(entry[0]) + ".gltf"
	if not ResourceLoader.exists(path):
		return false
	model = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	var colors: Dictionary = entry[1]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes.append(mi)
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i) as StandardMaterial3D
			if source == null:
				continue
			var m := source.duplicate() as StandardMaterial3D  # Own copy: tints don't leak to others
			var mat_name := source.resource_name
			if colors.has(mat_name):
				m.albedo_color = colors[mat_name]
			mi.set_surface_override_material(i, m)
			if mat_name == "Skin":
				skin = m
				skin_color = m.albedo_color
			elif mat_name != "Face":
				clothes.append(m)
				clothes_colors.append(m.albedo_color)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		anim = players[0]
		for loop_name in ["Idle", "Walk", "Run"]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")
	own_anim = anim
	target_yaw = global_rotation.y
	return true


# ---------- Sprite body ----------

func _setup_sprite(dir: String) -> bool:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var found := false
	for d: String in DIRS:
		var path := dir + "rotations/%s.png" % d
		if ResourceLoader.exists(path):
			frames.add_animation("stand_" + d)
			frames.add_frame("stand_" + d, load(path))
			found = true
		for kind: String in ["walk", "idle"]:
			var i := 0
			while ResourceLoader.exists(dir + "animations/%s/%s/frame_%03d.png" % [kind, d, i]):
				if i == 0:
					frames.add_animation(kind + "_" + d)
					frames.set_animation_speed(kind + "_" + d, SPRITE_FPS[kind])
					frames.set_animation_loop(kind + "_" + d, true)
				frames.add_frame(kind + "_" + d, load(dir + "animations/%s/%s/frame_%03d.png" % [kind, d, i]))
				i += 1
	if not found:
		return false
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = SPRITE_PIXEL
	sprite.position.y = 40.0 * SPRITE_PIXEL  # Feet on the ground
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true  # Night and lamps light it like everything else
	add_child(sprite)
	_sprite_play("stand", "south")
	return true


# The animation for a direction, borrowing a neighbour (mirrored) when it wasn't made
func _sprite_play(kind: String, d: String) -> void:
	var frames := sprite.sprite_frames
	var flip := false
	var clip := kind + "_" + d
	if not frames.has_animation(clip):
		var mirror := {"west": "east", "north-west": "north-east", "south-west": "south-east",
				"east": "west", "north-east": "north-west", "south-east": "south-west"}
		var near := {"south-east": "east", "north-east": "east", "south-west": "west", "north-west": "west"}
		if mirror.has(d) and frames.has_animation(kind + "_" + mirror[d]):
			clip = kind + "_" + mirror[d]
			flip = true
		elif near.has(d) and frames.has_animation(kind + "_" + near[d]):
			clip = kind + "_" + near[d]
		elif near.has(d) and frames.has_animation(kind + "_" + mirror.get(near[d], "")):
			clip = kind + "_" + mirror[near[d]]
			flip = true
		elif kind == "idle":
			_sprite_play("stand", d)
			return
		elif frames.has_animation(kind + "_south"):
			clip = kind + "_south"
		else:
			clip = "stand_south"
	sprite.flip_h = flip
	if sprite.animation != clip:
		sprite.play(clip)


func _sprite_dir(v: Vector3) -> String:
	# The camera looks north: +z is toward the viewer (south), +x is east
	var angle := atan2(v.x, v.z)  # 0 = south, PI/2 = east
	var index := posmod(roundi(angle / (PI / 4.0)), 8)
	return DIRS[index]


# The sprite's outline, drawn only where something stands in front of it (inverted depth
# test: never over the doctor himself, only over the roof or wall that hides him)
func make_xray(color: Color) -> void:
	if sprite == null:
		return
	var shader := Shader.new()
	shader.code = XRAY_SHADER
	xray_mat = ShaderMaterial.new()
	xray_mat.shader = shader
	xray_mat.set_shader_parameter("tint", color)
	var quad := QuadMesh.new()
	quad.size = Vector2(80.0, 80.0) * SPRITE_PIXEL
	xray = MeshInstance3D.new()
	xray.mesh = quad
	xray.material_override = xray_mat
	xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	xray.position = sprite.position + Vector3(0.0, 0.03, 0.03)  # A hair toward the camera, so it never shows over the body itself
	add_child(xray)


func set_see_through(amount: float) -> void:
	if sprite:
		sprite.transparency = amount


func _process(_delta: float) -> void:
	if sprite == null:
		return
	if xray:
		xray.visible = sprite.visible and sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED
		if xray.visible:
			xray_mat.set_shader_parameter("frame_tex", sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
			xray_mat.set_shader_parameter("flip", sprite.flip_h)
	# Lying in bed or dead: the body is turned flat, so the sprite stops facing the camera
	var lying := dead or absf(rotation.x) > 0.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if lying else BaseMaterial3D.BILLBOARD_ENABLED
	if lying:
		sprite.rotation = Vector3.ZERO
		sprite.position = Vector3(0.0, 40.0 * SPRITE_PIXEL, 0.05)


# Called every physics frame with the body's velocity: walk or stand, and face where we go
func animate(velocity: Vector3, delta: float) -> void:
	if sprite and not (shade and shade.visible):
		if dead:
			return
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		if ground_speed > 0.3:
			facing = _sprite_dir(velocity)
			_sprite_play("walk", facing)
			sprite.speed_scale = clampf(ground_speed / 2.0, 0.8, 2.0)
		else:
			sprite.speed_scale = 1.0
			_sprite_play("idle", facing)
		return
	if dead or anim == null:
		return
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		target_yaw = atan2(velocity.x, velocity.z)
		_play("Run" if flat.length() > 4.0 else "Walk")
	else:
		_play("Idle")
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func face(point: Vector3) -> void:
	var d := point - global_position
	if sprite and Vector2(d.x, d.z).length() > 0.01:
		facing = _sprite_dir(d)
	if Vector2(d.x, d.z).length() > 0.01:
		target_yaw = atan2(d.x, d.z)
		global_rotation.y = target_yaw


func die() -> void:
	dead = true
	if sprite:
		rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # Lying on its back, seen from above
		_sprite_play("stand", "south")
		sprite.pause()
		return
	_play("Death")  # Ends lying on the ground and stays there


# Blood loss makes the skin paler; servants also turn grey all over
func tint(blood_lost: float, servant: bool) -> void:
	if sprite:
		# No separate skin on a sprite: the whole figure pales, and goes grey for a servant
		var pale := Color.WHITE.lerp(Color(1.0, 0.94, 0.94), clampf(blood_lost, 0.0, 1.0))
		sprite_tint = pale.lerp(Color(0.75, 0.75, 0.8), 0.5) if servant else pale
		sprite.modulate = sprite_tint
		return
	if skin:
		skin.albedo_color = skin_color.lerp(PALE, clampf(blood_lost, 0.0, 1.0) * 0.6)
	for i in clothes.size():
		clothes[i].albedo_color = clothes_colors[i].lerp(Color(0.6, 0.6, 0.65), 0.5) if servant else clothes_colors[i]


# Hunting at night: a dark, faceless shape with a faint red glow. The body is a plain
# mannequin the same for everyone, so the outline doesn't give away who it is.
func set_dark(dark: bool) -> void:
	if dark and dark_overlay == null:
		dark_overlay = StandardMaterial3D.new()
		dark_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dark_overlay.albedo_color = Color(0.05, 0.05, 0.08, 0.85)
		dark_overlay.emission_enabled = true
		dark_overlay.emission = Color(0.25, 0.05, 0.05)
		dark_overlay.emission_energy_multiplier = 0.6
	if dark and shade == null:
		_make_shade()
	if sprite:
		sprite.visible = not dark or shade == null
		if shade == null:
			sprite.modulate = Color(0.12, 0.12, 0.16) if dark else sprite_tint
			return
		shade.visible = dark
		anim = shade_anim if dark else null
		if dark:
			current = ""
			_play("Idle")
		return
	if shade == null:
		for mi in meshes:  # No shade model: darken the own body, as before
			mi.material_overlay = dark_overlay if dark else null
		return
	model.visible = not dark
	shade.visible = dark
	anim = shade_anim if dark else own_anim
	var playing := current
	current = ""
	_play(playing if playing != "" else "Idle")


func _make_shade() -> void:
	var path := MODEL_DIR + SHADE_MODEL + ".gltf"
	if (model == null and sprite == null) or not ResourceLoader.exists(path):
		return
	shade = (load(path) as PackedScene).instantiate()
	shade.scale = Vector3.ONE * SCALE
	shade.visible = false
	add_child(shade)
	for node in shade.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = dark_overlay
	var players := shade.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		shade_anim = players[0]
		for loop_name in ["Idle", "Walk", "Run"]:
			if shade_anim.has_animation(loop_name):
				shade_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR


func _play(anim_name: String) -> void:
	if anim and current != anim_name and anim.has_animation(anim_name):
		current = anim_name
		anim.play(anim_name, 0.2)
