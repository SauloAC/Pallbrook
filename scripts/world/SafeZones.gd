class_name SafeZones
extends Node

# Places the vampire will not follow the doctor into (see the design doc, "Encontros à noite"):
# - the church and its yard (consecrated ground)
# - vegetable gardens with garlic growing in them
# - the bridge and everything beyond it (it cannot cross running water, not even by the bridge)
# Each run one garden owner "doesn't like garlic" and grows none: the vampire, if it owns a
# garden, otherwise someone picked at random.
#
# Rectangles are on the ground (x, z), in world units. Church and bridge come from town.blend.

const CHURCH := Rect2(-8.8, -12.8, 7.6, 11.6)        # Church walls (-7.3..-2.7, -11.3..-2.7) + its yard
const BRIDGE_DECK := Rect2(-40.0, -14.0, 30.0, 3.4)  # The deck from its east end (x -10) westward
const BEYOND_RIVER_X := -16.3                        # West bank: the cemetery side
const BRIDGE_WAIT := Vector3(-8.6, 0.0, -12.0)       # Where it waits when the doctor crossed
const GARDEN_MARGIN := 0.6                           # Standing right beside the rows counts
const GARLIC_WHITE := Color(0.93, 0.9, 0.82)
const GARLIC_GREEN := Color(0.32, 0.45, 0.2)

var gardens: Array[Rect2] = []   # Gardens that have garlic
var no_garlic_owner := ""        # Whose garden has none this run


func setup(vampire_name: String) -> void:
	add_to_group("safe_zones")
	var soils := get_tree().current_scene.find_children("GSoil_*", "MeshInstance3D", true, false)
	var owners: Array[String] = []
	for soil in soils:
		owners.append(String(soil.name).trim_prefix("GSoil_").get_slice(".", 0))
	if owners.is_empty():
		return
	no_garlic_owner = vampire_name if vampire_name in owners else owners.pick_random()
	for soil: MeshInstance3D in soils:
		var owner_name := String(soil.name).trim_prefix("GSoil_").get_slice(".", 0)
		if owner_name == no_garlic_owner:
			continue
		var box: AABB = soil.global_transform * soil.get_aabb()
		gardens.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(GARDEN_MARGIN))
		_plant_garlic(box)


func is_safe(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	if CHURCH.has_point(p) or BRIDGE_DECK.has_point(p) or pos.x < BEYOND_RIVER_X:
		return true
	for g in gardens:
		if g.has_point(p):
			return true
	return false


# Which kind of safe place this is: "church", "river", "garden" or "" (not safe)
func kind(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	if CHURCH.has_point(p):
		return "church"
	if BRIDGE_DECK.has_point(p) or pos.x < BEYOND_RIVER_X:
		return "river"
	for g in gardens:
		if g.has_point(p):
			return "garden"
	return ""


# Where the vampire stands to wait for someone in a safe place: just outside its edge
func wait_point(pos: Vector3) -> Vector3:
	var p := Vector2(pos.x, pos.z)
	if BRIDGE_DECK.has_point(p) or pos.x < BEYOND_RIVER_X:
		return BRIDGE_WAIT
	for rect in [CHURCH] + gardens:
		if rect.has_point(p):
			return _just_outside(rect, pos)
	return pos


func _just_outside(rect: Rect2, pos: Vector3) -> Vector3:
	var out := pos
	var left := pos.x - rect.position.x
	var right := rect.end.x - pos.x
	var top := pos.z - rect.position.y
	var bottom := rect.end.y - pos.z
	var nearest := minf(minf(left, right), minf(top, bottom))
	if nearest == left:
		out.x = rect.position.x - 1.0
	elif nearest == right:
		out.x = rect.end.x + 1.0
	elif nearest == top:
		out.z = rect.position.y - 1.0
	else:
		out.z = rect.end.y + 1.0
	return out


# A row of garlic along the garden's west edge: white bulbs and thin green leaves, easy to
# spot from above, even at night
func _plant_garlic(box: AABB) -> void:
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = GARLIC_WHITE
	bulb_mat.roughness = 0.8
	bulb_mat.emission_enabled = true  # A faint glow so the rows read at night too
	bulb_mat.emission = GARLIC_WHITE
	bulb_mat.emission_energy_multiplier = 0.25
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = GARLIC_GREEN
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.13
	bulb_mesh.height = 0.2
	var leaf_mesh := CylinderMesh.new()
	leaf_mesh.top_radius = 0.006
	leaf_mesh.bottom_radius = 0.02
	leaf_mesh.height = 0.5
	var count := maxi(4, int(box.size.z / 0.4))
	for i in count:
		var plant := Node3D.new()
		var z := box.position.z + 0.2 + (box.size.z - 0.4) * (i / float(maxi(count - 1, 1)))
		add_child(plant)
		plant.global_position = Vector3(box.position.x - 0.15, box.end.y, z)
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.material_override = bulb_mat
		bulb.position.y = 0.07
		plant.add_child(bulb)
		for k in 3:
			var leaf := MeshInstance3D.new()
			leaf.mesh = leaf_mesh
			leaf.material_override = leaf_mat
			leaf.position.y = 0.28
			leaf.rotation = Vector3(deg_to_rad(18.0), deg_to_rad(120.0 * k), 0.0)
			plant.add_child(leaf)
