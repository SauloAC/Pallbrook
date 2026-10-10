extends Node

# Picks the secret vampire and decides what they do each night

var vampire: Node = null


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	# NPCs join the "npcs" group in their own _ready, which runs after ours
	await get_tree().process_frame
	_choose_vampire()


func _choose_vampire() -> void:
	var npcs := get_tree().get_nodes_in_group("npcs")
	if npcs.is_empty():
		return
	vampire = npcs.pick_random()
	GameState.vampire_name = vampire.data.npc_name
	print("[DEBUG] The vampire is: ", GameState.vampire_name)


func _on_phase_changed(is_night: bool) -> void:
	# Act at dawn: whatever happened "during the night" is discovered now
	if is_night or vampire == null:
		return
	_night_action()


func _night_action() -> void:
	var victims := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive():
			victims.append(npc)
	if victims.is_empty():
		return
	var victim = victims.pick_random()
	victim.die()
	GameState.add_night_event("%s foi encontrado sem vida na porta de casa." % victim.data.npc_name)
	EventBus.npc_died.emit(victim.data.npc_name)
