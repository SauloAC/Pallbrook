class_name CharacterKit
extends RefCounted

# Prototype (3 Nov): residents built from Quaternius' Universal Base Characters kit (CC0): a base
# body (its head and face), clothes from Modular Character Outfits, a hairstyle, a beard... all
# rigged to the one Universal Animation Library skeleton, so they share its animations (UAL 1 + 2).
# Each piece gets a flat colour by its role, so a resident is just a list of pieces and colours,
# and the kit's own textures aren't used (drawn at 37 px they'd only be noise).

const DIR := "res://assets/characters/kit/"
const ANIMS := "res://assets/models/characters/UAL1_Standard.glb"       # Skeleton and 43 clips
const MORE_ANIMS := "res://assets/characters/kit/UAL2_Standard.glb"     # 43 more, as "ual2/<name>"

const DEFAULT_COLORS := {
	"skin": Color(0.88, 0.70, 0.58), "eyes": Color(0.12, 0.08, 0.06), "hair": Color(0.30, 0.20, 0.12),
	"top": Color(0.45, 0.40, 0.32), "legs": Color(0.25, 0.22, 0.20), "feet": Color(0.30, 0.20, 0.12),
	"hood": Color(0.25, 0.30, 0.22), "belt": Color(0.30, 0.20, 0.12), "pauldron": Color(0.35, 0.28, 0.20),
}
const FALLBACK := {"sleeves": "top", "beard": "hair", "brows": "hair", "bracer": "belt"}
const FACE_BONES := ["Head", "neck_01"]   # What is left of the base body under clothes
const HEAD_SCALE := 1.3                   # Heads drawn bigger than life, to read at 37 px (see HeadScale)


# look: {"parts": ["base/Superhero_Male_FullBody", "outfits/Male_Peasant", "hair/Hair_SimpleParted"], "colors": {...}}
static func assemble(look: Dictionary) -> Node3D:
	var body: Node3D = (load(ANIMS) as PackedScene).instantiate()
	var skel: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)  # The bare mannequin
		mi.free()
	_add_clips(body)
	var head := HeadScale.new()
	head.amount = float(look.get("head", HEAD_SCALE))
	skel.add_child(head)
	var colors := DEFAULT_COLORS.duplicate()
	colors.merge(look.get("colors", {}), true)
	var parts: Array = look.get("parts", [])
	var dressed := parts.any(func(p): return str(p).begins_with("outfits/"))
	for part_name in parts:
		var path := DIR + str(part_name) + ".gltf"
		if not ResourceLoader.exists(path):
			push_warning("CharacterKit: no piece " + path)
			continue
		var part: Node3D = (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
			var skin := mi.skin
			mi.owner = null  # It leaves its own scene: no owner to keep
			mi.get_parent().remove_child(mi)
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
			mi.skin = skin
			_colour(mi, colors, dressed)
		part.free()
	return body


# The second library's clips, under "ual2/" (same skeleton, same node paths)
static func _add_clips(body: Node3D) -> void:
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not ResourceLoader.exists(MORE_ANIMS):
		return
	var other: Node = (load(MORE_ANIMS) as PackedScene).instantiate()
	var theirs := other.find_children("*", "AnimationPlayer", true, false)
	if not theirs.is_empty():
		var lib: AnimationLibrary = (theirs[0] as AnimationPlayer).get_animation_library("")
		if lib:
			(players[0] as AnimationPlayer).add_animation_library("ual2", lib)  # Shared, not copied: clips are only read
	other.free()


static func _role(mesh_name: String, mat_name: String) -> String:
	var n := mesh_name.to_lower()
	if mat_name.begins_with("MI_Superhero") or mat_name.begins_with("MI_Regular"):
		return "skin"
	if mat_name.begins_with("MI_Eyes"):
		return "eyes"
	if mat_name.begins_with("MI_Hair"):
		if "beard" in n:
			return "beard"
		if "eyebrow" in n or n == "face":  # The base body's own eyebrows are a mesh called "Face"
			return "brows"
		return "hair"
	for role in ["hood", "belt", "pauldron", "bracer", "arms", "body", "legs", "feet"]:
		if role in n:
			return {"arms": "sleeves", "body": "top"}.get(role, role)
	return "top"


static func _colour(mi: MeshInstance3D, colors: Dictionary, dressed: bool) -> void:
	var mesh := mi.mesh
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i)
		var role := _role(String(mi.name), src.resource_name if src else "")
		var key := role
		while not colors.has(key) and FALLBACK.has(key):
			key = FALLBACK[key]
		var m := StandardMaterial3D.new()
		m.albedo_color = colors.get(key, Color.MAGENTA)
		m.resource_name = role
		mi.set_surface_override_material(i, m)
		if role in ["eyes", "brows"]:
			mi.set_meta("no_outline", true)  # Tiny, inside the head: an outline would blot the face
	if dressed and mesh.get_surface_count() == 1 and (mesh.surface_get_material(0) and \
			mesh.surface_get_material(0).resource_name.begins_with("MI_Superhero")):
		_keep_only(mi, FACE_BONES)  # Under clothes only the head shows; the rest would poke through


# Rebuilds a skinned mesh with only the triangles that follow the given bones
static func _keep_only(mi: MeshInstance3D, bones_kept: Array) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or mi.skin == null:
		return
	var kept := {}
	for b in mi.skin.get_bind_count():
		if String(mi.skin.get_bind_name(b)) in bones_kept:
			kept[b] = true
	var arrays := src.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var per := bones.size() / maxi(verts.size(), 1)
	var on := PackedByteArray()
	on.resize(verts.size())
	for v in verts.size():
		var best := 0
		for k in range(1, per):
			if weights[v * per + k] > weights[v * per + best]:
				best = k
		on[v] = 1 if kept.has(bones[v * per + best]) else 0
	var old: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var idx := PackedInt32Array()
	for t in range(0, old.size(), 3):
		if on[old[t]] and on[old[t + 1]] and on[old[t + 2]]:
			idx.append_array([old[t], old[t + 1], old[t + 2]])
	arrays[Mesh.ARRAY_INDEX] = idx
	var mat := mi.get_surface_override_material(0)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
	mi.mesh = out
	mi.set_surface_override_material(0, mat)
