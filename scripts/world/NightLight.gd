extends Light3D

# Street lamps: on at night, off during the day.
# Window lights (parent is a building named like a location): on at night only
# while someone is awake inside. The Clinic is the doctor's, so it is always lit.

const CHECK_INTERVAL := 0.5

var on_energy: float
var place := ""        # Building this window belongs to ("" = street lamp)
var lit := false
var check_timer := 0.0


func _ready() -> void:
	on_energy = light_energy  # The brightness set in the Inspector
	var parent := get_parent()
	if parent and parent.name != "Clinica" and _is_location(parent.name):
		place = parent.name
	lit = _should_be_lit()
	light_energy = on_energy if lit else 0.0


func _process(delta: float) -> void:
	check_timer -= delta
	if check_timer > 0.0:
		return
	check_timer = CHECK_INTERVAL
	var should := _should_be_lit()
	if should == lit:
		return
	lit = should
	var tween := create_tween()
	# Small random delay so the lights don't all switch at once
	tween.tween_interval(randf_range(0.0, 1.5))
	tween.tween_property(self, "light_energy", on_energy if lit else 0.0, 2.0)


func _should_be_lit() -> bool:
	if not GameState.is_night:
		return false
	if place == "":
		return true  # Street lamp or the Clinic
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.current_place == place and npc.state == npc.State.INSIDE:
			return true
	return false


func _is_location(node_name: String) -> bool:
	for marker in get_tree().get_nodes_in_group("locations"):
		if marker.name == node_name:
			return true
	return false
