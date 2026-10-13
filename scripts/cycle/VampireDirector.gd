extends Node
@export_range(0.0, 1.0) var servant_chance := 0.35
@export_range(0.0, 1.0) var clue_reliability := 0.75  # Chance the trace points to the real vampire

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
	#print("[DEBUG] The vampire is: ", GameState.vampire_name)


func _on_phase_changed(is_night: bool) -> void:
	# Act at dawn: whatever happened "during the night" is discovered now
	if is_night or vampire == null:
		return
	if GameState.game_over:
		return
	_night_action()


func _night_action() -> void:
	var victims := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive() and not npc.is_servant:
			victims.append(npc)
	if victims.is_empty():
		_check_town_lost()
		return
	var victim = victims.pick_random()
	var victim_name: String = victim.data.npc_name

	# Sometimes convert instead of kill (only if there is still someone else to hunt)
	if victims.size() > 1 and randf() < servant_chance:
		victim.make_servant()
		GameState.add_night_event("During the night, a figure was seen near %s's house." % victim_name)
		#print("[DEBUG] %s became a servant" % victim_name)
		GameState.add_clue("Morning of Day %d: a figure was seen near %s's house." % [GameState.day, victim_name])
	else:
		victim.die(_pick_trace(victim))
		GameState.add_night_event("%s was found dead at their doorstep." % victim_name)
		GameState.add_clue("Morning of Day %d: %s died during the night." % [GameState.day, victim_name])
		EventBus.npc_died.emit(victim_name)


func _pick_trace(victim) -> String:
	if randf() < clue_reliability:
		return vampire.data.clue_trait  # The real trace
	# Misleading trace: someone innocent (never the victim)
	var others := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc != victim:
			others.append(npc)
	if others.is_empty():
		return vampire.data.clue_trait
	return others.pick_random().data.clue_trait


func _check_town_lost() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive() and not npc.is_servant:
			return  # Someone is still free
	EventBus.game_ended.emit(false, "No one in Pallbrook is free anymore. %s has won." % vampire.data.npc_name)
