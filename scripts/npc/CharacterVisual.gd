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


# Called every physics frame with the body's velocity: walk or stand, and face where we go
func animate(velocity: Vector3, delta: float) -> void:
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
	if Vector2(d.x, d.z).length() > 0.01:
		target_yaw = atan2(d.x, d.z)
		global_rotation.y = target_yaw


func die() -> void:
	dead = true
	_play("Death")  # Ends lying on the ground and stays there


# Blood loss makes the skin paler; servants also turn grey all over
func tint(blood_lost: float, servant: bool) -> void:
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
	if model == null or not ResourceLoader.exists(path):
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
