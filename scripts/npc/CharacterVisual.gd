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
	"Ada":    ["Casual_Female", {"Skin": Color(0.82, 0.62, 0.48), "Shirt": Color(0.55, 0.38, 0.22), "Pants": Color(0.30, 0.36, 0.22),
			"Hair": Color(0.55, 0.25, 0.10)}],
	# The merchant beyond the bridge (not a townsperson: no schedule, never a suspect)
	"Gideon": ["Worker_Male", {"Skin": Color(0.78, 0.6, 0.48), "Shirt": Color(0.72, 0.68, 0.58), "Vest": Color(0.22, 0.3, 0.2),
			"Pants": Color(0.28, 0.22, 0.16), "Hat": Color(0.32, 0.3, 0.27)}],
	# His Quaternius body was: ["Doctor_Male_Young", {"Skin": Color(0.85, 0.68, 0.56), "Main": Color(0.15, 0.15, 0.18),
	#     "Black": Color(0.35, 0.30, 0.25), "Brown": Color(0.18, 0.15, 0.13), "Hair": Color(0.25, 0.17, 0.10)}]
	# 3 Nov, second try: built from the Universal Base Characters kit (CharacterKit): his head and
	# face, peasant clothes coloured as a dark coat, parted hair and a beard
	"Doctor": ["KIT", {"parts": ["base/Superhero_Male_FullBody", "outfits/Male_Peasant", "hair/Hair_SimpleParted",
			"hair/Hair_Beard"], "colors": {"skin": Color(0.90, 0.72, 0.60), "hair": Color(0.40, 0.27, 0.16),
			"top": Color(0.24, 0.24, 0.30), "legs": Color(0.17, 0.16, 0.19), "feet": Color(0.38, 0.24, 0.14)}}],
}

# The Universal Animation Library (Quaternius, CC0): the skeleton and 43 clips the kit bodies share (CharacterKit)
const UAL_PATH := "res://assets/models/characters/UAL1_Standard.glb"
const UAL_SCALE := 0.93   # About 1.7 m, like the others
# The shared rig's clip names, for bodies whose clips are named otherwise (the UAL body)
const CLIP_ALIASES := {"Run": "Jog_Fwd", "Death": "Death01", "Defeat": "Death01", "SitDown": "Sitting_Enter",
		"PickUp": "PickUp_Table", "RecieveHit": "Hit_Chest", "Punch": "Punch_Cross"}

# At night the hunter wears no face: a plain, shared body instead of their own
const SHADE_MODEL := "BaseCharacter"

# Test (31 Oct): pixel-art sprites from PixelLab instead of the 3D body, for whoever has a
# folder here (rotations/<dir>.png, animations/walk/<dir>/frame_NNN.png, animations/idle/<dir>/...).
# The sprite always faces the camera; directions without their own walk are borrowed (west
# mirrors east). Everything else (bed, death, pallor, the night shade) works as for the bodies.
# Test over (31 Oct): the 3D bodies animate better, so nobody used a sprite then.
# Again from 3 Nov, now that the town is painted 2D: the doctor first. Tomas also has a folder:
# "Tomas": "res://assets/characters/sprites/tomas/"
# doctor_half: the PixelLab frames halved (40 px), so his pixels are the size of the painted buildings
# (art_source: 2x2 blocks to one pixel, keeping the dark contour). The full-size frames stay in doctor/.
const SPRITES := {"Doctor": "res://assets/characters/sprites/doctor_half/"}
# Prototype (3 Nov): whoever is listed here keeps the 3D body and rig, drawn as pixel art (PixelRig)
# instead of using a SPRITES folder. Remove the name to go back to the PixelLab sprite.
const PIXEL_3D := ["Doctor"]
var rig: PixelRig
const DIRS := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
const SPRITE_PIXEL := 0.0215   # 80 px canvas, ~79 px of body -> about 1.7 m (scaled for other canvas sizes)
const UPRIGHT := 1.5557238      # 1 / cos(50 deg): an upright sprite seen by the 50-degree camera
var px_size := SPRITE_PIXEL     # This sprite's pixel, for its canvas
var half_h := 40.0              # Half its canvas height, in pixels
const SPRITE_FPS := {"walk": 10.0, "idle": 5.0, "sit": 8.0, "death": 7.0}
const SPRITE_LOOPS := ["walk", "idle"]   # sit and death play once and hold their last frame
# Sitting (3 Nov): only the south pose was drawn on a seat; east and north sit on the floor, so on a
# chair they are lifted to a bench seat (~0.5 m). In pixels of the 80 px canvas (west mirrors east).
const SIT_LIFT_PX := {"south": 0.0, "east": 15.0, "west": 15.0, "north": 14.0}
var seated := false
var sit_lift := 0.0             # Metres the sprite is raised while seated (see SIT_LIFT_PX)
var sit_tween: Tween
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
var acting := false   # A one-off clip is playing (see act): walking and idling wait
var act_id := 0
var target_yaw := 0.0
var dark_overlay: StandardMaterial3D


# Returns false when this person has no model yet (the capsule stays)
func setup(look: String) -> bool:
	if SPRITES.has(look) and look not in PIXEL_3D and _setup_sprite(SPRITES[look]):
		return true
	if not LOOKS.has(look):
		return false
	var entry: Array = LOOKS[look]
	var kit := str(entry[0]) == "KIT"
	var painted := kit  # Coloured by the kit, not by the model's own materials
	var path: String = UAL_PATH if painted else MODEL_DIR + str(entry[0]) + ".gltf"
	if not ResourceLoader.exists(path):
		return false
	if kit:
		model = CharacterKit.assemble(entry[1])
	else:
		model = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * (UAL_SCALE if painted else SCALE)
	if look in PIXEL_3D:
		rig = PixelRig.new()
		add_child(rig)
		rig.build(model)  # The body lives in the rig's little world; the town sees its picture
	else:
		add_child(model)
	var colors: Dictionary = {} if painted else entry[1]
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
	if rig:
		rig.flatten(model)  # Toon bands and outline on the coloured copies
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
		for kind: String in SPRITE_FPS:
			var i := 0
			while ResourceLoader.exists(dir + "animations/%s/%s/frame_%03d.png" % [kind, d, i]):
				if i == 0:
					frames.add_animation(kind + "_" + d)
					frames.set_animation_speed(kind + "_" + d, SPRITE_FPS[kind])
					frames.set_animation_loop(kind + "_" + d, kind in SPRITE_LOOPS)
				frames.add_frame(kind + "_" + d, load(dir + "animations/%s/%s/frame_%03d.png" % [kind, d, i]))
				i += 1
	if not found:
		return false
	var canvas := frames.get_frame_texture(frames.get_animation_names()[0], 0).get_height()
	px_size = SPRITE_PIXEL * 80.0 / canvas
	half_h = canvas / 2.0
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = px_size
	# Stand upright like the painted buildings (a full billboard leans back into the wall behind and
	# gets cut by it), stretched by 1/cos(50 deg) so the 50-degree camera shows it at its full height
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.scale.y = UPRIGHT
	sprite.position.y = half_h * px_size * UPRIGHT  # Feet on the ground
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
	var flat := _flat()
	if flat == null:
		return
	var shader := Shader.new()
	shader.code = XRAY_SHADER
	xray_mat = ShaderMaterial.new()
	xray_mat.shader = shader
	xray_mat.set_shader_parameter("tint", color)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0 * half_h, 2.0 * half_h) * px_size if sprite else Vector2(PixelRig.SIZE) * PixelRig.PX
	xray = MeshInstance3D.new()
	xray.mesh = quad
	xray.material_override = xray_mat
	xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Upright like the sprite and a hair toward the camera, so it only shows where a wall hides the body
	xray.scale.y = UPRIGHT
	xray.position = flat.position + Vector3(0.0, 0.0, 0.03)
	if rig:
		xray_mat.set_shader_parameter("frame_tex", rig.viewport.get_texture())
		rig.add_child(xray)  # Stands with the picture
	else:
		add_child(xray)


# The flat picture standing in the town: the sprite, or the pixel-art rig's picture
func _flat() -> SpriteBase3D:
	if sprite:
		return sprite
	return rig.sprite if rig else null


func set_see_through(amount: float) -> void:
	if rig:
		rig.set_fade(amount)  # Dithered: a solid picture with every other pixel left out
		return
	var flat := _flat()
	if flat:
		flat.transparency = amount


func _process(_delta: float) -> void:
	if rig:
		rig.sync(self)  # The picture follows; the body inside turns (and lies down) as we do
		if xray:
			xray.visible = rig.sprite.visible
		return
	if sprite == null:
		return
	if xray:
		xray.visible = sprite.visible and sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED
		if xray.visible:
			xray_mat.set_shader_parameter("frame_tex", sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
			xray_mat.set_shader_parameter("flip", sprite.flip_h)
			xray.position = sprite.position + Vector3(0.0, 0.0, 0.03)
	# Lying in bed, or dead without a drawn death: the body is turned flat, so the sprite stops
	# facing the camera (the drawn death already ends lying down, seen from above, and stays upright)
	var lying := (dead and not _has_clip("death")) or absf(rotation.x) > 0.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if lying else BaseMaterial3D.BILLBOARD_FIXED_Y
	if lying:
		sprite.rotation = Vector3.ZERO
		sprite.scale.y = 1.0
		sprite.position = Vector3(0.0, half_h * px_size, 0.05)
	else:
		sprite.scale.y = UPRIGHT
		sprite.position = Vector3(0.0, half_h * px_size * UPRIGHT + sit_lift, 0.0)


func _has_clip(kind: String) -> bool:
	return sprite != null and sprite.sprite_frames.has_animation(kind + "_south")


# Sits down where it stands, facing d ("south", "east", "north", "west"). Returns the clip's length.
# Moving again (animate with some speed) stands it back up.
func sit(d: String) -> float:
	if sprite == null:
		return _sit_3d(d)
	if not _has_clip("sit"):
		return 0.0
	seated = true
	facing = d
	_sprite_play("sit", d)
	sprite.frame = 0
	sprite.play(sprite.animation)
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	var length := count / float(SPRITE_FPS["sit"])
	_tween_lift(float(SIT_LIFT_PX.get(d, 0.0)) * SPRITE_PIXEL * UPRIGHT, length)
	return length


func stand_up() -> void:
	if not seated:
		return
	seated = false
	if sprite == null:
		acting = false  # Straight up into the walk: no StandUp clip holding him in place
		act_id += 1
		current = ""
		_play("Idle")
		return
	_tween_lift(0.0, 0.15)
	_sprite_play("idle", facing)


# The 3D rig's SitDown clip, held seated, turned the way the seat faces
const FACING_YAW := {"south": 0.0, "east": PI / 2.0, "north": PI, "west": -PI / 2.0}

func _sit_3d(d: String) -> float:
	if anim == null or not anim.has_animation(_clip("SitDown")):
		return 0.0
	target_yaw = FACING_YAW.get(d, 0.0)
	global_rotation.y = target_yaw
	seated = true
	var length := act("SitDown", true)
	if anim.has_animation("Sitting_Idle"):
		anim.queue("Sitting_Idle")  # The UAL body sits on, breathing, after sitting down
	return length


func _tween_lift(to: float, time: float) -> void:
	if sit_tween:
		sit_tween.kill()
	sit_tween = create_tween()
	sit_tween.tween_property(self, "sit_lift", to, time)


# Called every physics frame with the body's velocity: walk or stand, and face where we go
func animate(velocity: Vector3, delta: float) -> void:
	if sprite and not (shade and shade.visible):
		if dead or acting:
			return
		if seated:
			if Vector2(velocity.x, velocity.z).length() <= 0.3:
				return  # Stays in the chair
			stand_up()
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		if ground_speed > 0.3:
			facing = _sprite_dir(velocity)
			_sprite_play("walk", facing)
			sprite.speed_scale = clampf(ground_speed / 2.0, 0.8, 2.0)
		else:
			sprite.speed_scale = 1.0
			_sprite_play("idle", facing)
		return
	if seated and not dead:
		if Vector2(velocity.x, velocity.z).length() <= 0.3:
			return  # Stays in the chair
		stand_up()
	if dead or anim == null or acting:
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
		seated = false
		sit_lift = 0.0
		if _has_clip("death"):
			_play_death()  # Falls and stays lying on the ground
			return
		rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # No drawn death: lying on its back, seen from above
		_sprite_play("stand", "south")
		sprite.pause()
		return
	_play("Death")  # Ends lying on the ground and stays there


# Blood loss makes the skin paler; servants also turn grey all over
func tint(blood_lost: float, servant: bool) -> void:
	if rig and skin == null:
		# A painted or kit body has no skin material of its own: the whole picture pales, like a sprite
		var pale := Color.WHITE.lerp(Color(1.0, 0.94, 0.94), clampf(blood_lost, 0.0, 1.0))
		sprite_tint = pale.lerp(Color(0.75, 0.75, 0.8), 0.5) if servant else pale
		rig.set_tint(sprite_tint)
		return
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
	if rig:
		rig.pivot.add_child(shade)
		rig.flatten(shade)
	else:
		add_child(shade)
	for node in shade.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = dark_overlay
	var players := shade.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		shade_anim = players[0]
		for loop_name in ["Idle", "Walk", "Run"]:
			if shade_anim.has_animation(loop_name):
				shade_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR


# A one-off clip from the shared rig: PickUp, Punch, RecieveHit, Defeat, Death...
# Walking and idling wait until it ends; hold keeps the last pose (a fall). Returns its length.
func act(anim_name: String, hold := false, speed := 1.0) -> float:
	if sprite and not (shade and shade.visible):
		return _sprite_act(anim_name, hold)
	anim_name = _clip(anim_name)
	if anim == null or not anim.has_animation(anim_name):
		return 0.0
	acting = true
	act_id += 1
	current = anim_name
	anim.play(anim_name, 0.15, speed)
	var length := anim.get_animation(anim_name).length / speed
	if not hold:
		get_tree().create_timer(length).timeout.connect(_end_act.bind(act_id))
	return length


# The sprite has only some of the rig's clips: a fall (Defeat, Death) is its drawn death.
# The others (PickUp, Punch, RecieveHit...) have no frames yet, so nothing plays.
func _sprite_act(anim_name: String, hold: bool) -> float:
	if anim_name not in ["Defeat", "Death"] or not _has_clip("death"):
		return 0.0
	seated = false
	sit_lift = 0.0
	acting = true
	act_id += 1
	var length := _play_death()
	if not hold:
		get_tree().create_timer(length).timeout.connect(_end_act.bind(act_id))
	return length


# Only drawn facing south: it falls back toward the top of the screen whichever way it was facing
func _play_death() -> float:
	sprite.flip_h = false
	sprite.play("death_south")
	sprite.frame = 0
	return sprite.sprite_frames.get_frame_count("death_south") / float(SPRITE_FPS["death"])


func _end_act(id: int) -> void:
	if id == act_id:  # A later clip (or a held fall) took over meanwhile
		acting = false
		current = ""


# This body's name for a clip of the shared rig (see CLIP_ALIASES)
func _clip(anim_name: String) -> String:
	if anim and not anim.has_animation(anim_name) and CLIP_ALIASES.has(anim_name):
		return CLIP_ALIASES[anim_name]
	return anim_name


func _play(anim_name: String) -> void:
	anim_name = _clip(anim_name)
	if anim and current != anim_name and anim.has_animation(anim_name):
		current = anim_name
		anim.play(anim_name, 0.2)
