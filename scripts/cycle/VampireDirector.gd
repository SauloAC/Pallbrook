extends Node

# Picks the secret vampire and runs their nightly hunt

@export_range(0.0, 1.0) var servant_chance := 0.35
@export_range(0.0, 1.0) var clue_reliability := 0.75  # Chance the trace points to the real vampire
@export var hunt_start_hour := 22.5  # Earliest the vampire leaves home
@export var hunt_end_hour := 24.5    # Latest (24.5 = 00:30)

var vampire: Node = null
var acted_tonight := false
var hunting := false
var hunt_victim: Node = null
var hunt_hour := 23.0


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
	if GameState.game_over or vampire == null:
		return
	if is_night:
		acted_tonight = false
		hunt_hour = randf_range(hunt_start_hour, hunt_end_hour)
		return
	# Dawn
	if hunting:
		_finish_hunt_now()
	elif not acted_tonight:
		# The doctor slept before the hunt: it happened off-screen
		var victim := _pick_victim()
		if victim:
			_resolve_attack(victim)
		else:
			_check_town_lost()
	acted_tonight = false


func _process(_delta: float) -> void:
	if GameState.game_over or vampire == null or acted_tonight or hunting or not GameState.is_night:
		return
	# Hours after midnight count as 24+, so 00:30 = 24.5
	var h := GameState.hour if GameState.hour >= 12.0 else GameState.hour + 24.0
	if h >= hunt_hour and h < 25.0:
		var victim := _pick_victim()
		if victim:
			_run_hunt(victim)


func _run_hunt(victim: Node) -> void:
	hunting = true
	acted_tonight = true
	hunt_victim = victim
	vampire.start_hunt(victim.data.home)
	# Walk to the victim's door, unless the doctor spots us
	await get_tree().physics_frame
	while hunting and not vampire.agent.is_navigation_finished():
		if vampire.witnessed:
			_abort_hunt()
			return
		await get_tree().physics_frame
	if not hunting:
		return
	await get_tree().create_timer(2.0).timeout  # Inside the house...
	if not hunting:
		return
	_resolve_attack(victim)
	vampire.end_hunt()
	hunting = false


func _abort_hunt() -> void:
	# Recognized by the doctor: flee home, nobody dies tonight
	hunting = false
	vampire.end_hunt()
	GameState.add_night_event("A shadow was seen prowling the streets. Nobody died tonight.")


func _finish_hunt_now() -> void:
	# The night ended mid-hunt (the doctor slept): settle it instantly
	hunting = false
	if hunt_victim and hunt_victim.is_alive() and not hunt_victim.is_servant:
		_resolve_attack(hunt_victim)
	vampire.stop_hunt()


func _pick_victim() -> Node:
	var victims := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive() and not npc.is_servant:
			victims.append(npc)
	if victims.is_empty():
		return null
	return victims.pick_random()


func _resolve_attack(victim: Node) -> void:
	var victim_name: String = victim.data.npc_name
	# At night the discovery belongs to the next morning
	var morning := GameState.day + 1 if GameState.is_night else GameState.day
	var others := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc != victim and npc.is_alive() and not npc.is_servant:
			others += 1
	# Sometimes convert instead of kill (only if someone else is left to hunt)
	if others > 0 and randf() < servant_chance:
		victim.make_servant()
		GameState.add_night_event("During the night, a figure was seen near %s's house." % victim_name)
		GameState.add_clue("Morning of Day %d: a figure was seen near %s's house." % [morning, victim_name])
	else:
		victim.die(_pick_trace(victim))
		GameState.add_night_event("%s was found dead at their doorstep." % victim_name)
		GameState.add_clue("Morning of Day %d: %s died during the night." % [morning, victim_name])
		EventBus.npc_died.emit(victim_name)
	_check_town_lost()


func _pick_trace(victim: Node) -> String:
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
