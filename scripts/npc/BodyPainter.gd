class_name BodyPainter
extends RefCounted

# Prototype (3 Nov): dresses the bare Universal Animation Library mannequin by painting it. Each
# vertex gets a colour from the bone it follows and where it sits on the body at rest (a coat down
# to the hem, trousers below, the hair on top of the head...). Drawn at 37 px tall, painted regions
# read as clothes, and every resident shares the one body and its 43 animations.
# The mannequin stands 1.83 m, feet at 0, facing +z; heights below are in its own metres.

const DEFAULT := {
	"skin": Color(0.85, 0.68, 0.56),
	"hair": Color(0.25, 0.17, 0.10),
	"coat": Color(0.15, 0.15, 0.18),    # Torso and sleeves, and the skirts of a coat or a dress
	"shirt": Color(0.85, 0.83, 0.78),   # The strip down the chest where the coat is open
	"vest": Color(-1, 0, 0),            # Optional: a band under the shirt strip (negative = none)
	"legs": Color(0.12, 0.11, 0.12),    # Trousers or stockings
	"boots": Color(0.25, 0.15, 0.10),
	"eyes": Color(0.10, 0.07, 0.06),
	"hem": 0.55,                        # Where the coat or dress ends (0.55 knee, 0.15 ankle, 0.95 hip)
	"open": 0.055,                      # Half-width of the open front (0 = closed, like a dress)
	"hair_long": false,                 # Hair down to the shoulders at the back
}


static func paint(model: Node3D, look: Dictionary) -> void:
	var c := DEFAULT.duplicate()
	c.merge(look, true)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var src := mi.mesh as ArrayMesh
		if src == null or mi.skin == null:
			continue
		var names := {}
		for b in mi.skin.get_bind_count():
			names[b] = String(mi.skin.get_bind_name(b))
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arrays := src.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(verts.size(), 1)  # 4 or 8 influences per vertex
			var head_top := 0.0
			for v in verts:
				head_top = maxf(head_top, v.y)
			var colors := PackedColorArray()
			colors.resize(verts.size())
			for i in verts.size():
				var best := 0
				for k in range(1, per):
					if weights[i * per + k] > weights[i * per + best]:
						best = k
				var bone: String = names.get(bones[i * per + best], "")
				colors[i] = _region(bone, verts[i], head_top, c)
			arrays[Mesh.ARRAY_COLOR] = colors
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
					Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.resource_name = "Painted"
			out.surface_set_material(s, m)
		mi.mesh = out


static func _region(bone: String, v: Vector3, head_top: float, c: Dictionary) -> Color:
	var b := bone.to_lower()
	# The open front of the coat: shirt (and vest) from the collar down to the hem, whatever bone
	# the vertex follows there (the chest mostly follows the collarbones)
	var torso := b.begins_with("spine") or b.begins_with("clavicle") or b.begins_with("pelvis") or b.begins_with("neck")
	if torso and _in_opening(v, c) and v.y > c["hem"] and v.y < head_top - 0.24:
		if c["vest"].r >= 0.0 and absf(v.x) > c["open"] * 0.45 and v.y < head_top - 0.42:
			return c["vest"]
		return c["shirt"]
	if b.begins_with("head") or b.begins_with("neck"):
		# Eyes: two dark dots on the face
		if v.z > 0.085 and absf(v.x) > 0.018 and absf(v.x) < 0.05 and v.y > head_top - 0.14 and v.y < head_top - 0.105:
			return c["eyes"]
		# Hair: the crown, and the back of the head (down to the neck if long)
		var crown := v.y > head_top - 0.075
		var back := v.z < -0.02 and v.y > head_top - (0.26 if c["hair_long"] else 0.17)
		var sides := absf(v.x) > 0.07 and v.y > head_top - 0.12 and v.z < 0.05
		if crown or back or sides:
			return c["hair"]
		return c["skin"]
	if b.begins_with("hand") or b.begins_with("index") or b.begins_with("middle") or b.begins_with("ring") \
			or b.begins_with("pinky") or b.begins_with("thumb"):
		return c["skin"]
	if b.begins_with("foot") or b.begins_with("ball"):
		return c["boots"]
	if b.begins_with("calf") or b.begins_with("thigh"):
		return c["coat"] if v.y > c["hem"] and not _in_opening(v, c) else c["legs"]
	if b.begins_with("upperarm") or b.begins_with("lowerarm") or b.begins_with("clavicle"):
		return c["coat"]
	return c["coat"]


static func _in_opening(v: Vector3, c: Dictionary) -> bool:
	return v.z > 0.04 and absf(v.x) < c["open"]
