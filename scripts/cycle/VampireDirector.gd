extends Node

# Picks the secret vampire and runs their nightly hunt

@export_range(0.0, 1.0) var servant_chance := 0.35
@export_range(0.0, 1.0) var clue_reliability := 0.75  # Chance the trace points to the real vampire
@export var hunt_start_hour := 22.5  # Earliest the vampire leaves home
@export var hunt_end_hour := 24.5    # Latest (24.5 = 00:30)
@export var bite_min := 25.0         # Blood taken per night (people start at 100)
@export var bite_max := 35.0
@export var outbreak_size := 2       # People already anemic when the doctor arrives
@export var watch_range := 8.0       # Doctor this close to the victim's door: the vampire gives up
@export var hunger_per_day := 15.0   # The vampire's own blood drops this much every dawn
@export var blood_gain := 0.4         # Share of what it drinks that refills the vampire
@export var hungry_level := 50.0     # Below this, bites take twice as much
@export var frenzy_level := 25.0     # Below this, the vampire turns reckless and violent

var vampire: Node = null
var acted_tonight := false
var fed_tonight := false
var frenzy_tonight := false  # Decided at nightfall, before any feeding
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
	vampire.set_hunger(randf_range(65.0, 80.0))  # Fed recently, before the doctor came
	_seed_outbreak()
	#print("[DEBUG] The vampire is: ", GameState.vampire_name)


func _on_phase_changed(is_night: bool) -> void:
	if GameState.game_over or vampire == null:
		return
	if is_night:
		acted_tonight = false
		fed_tonight = false
		frenzy_tonight = _frenzied()
		if frenzy_tonight:
			hunt_hour = randf_range(20.5, 22.0)  # Can't wait: hunts while people are still up
		else:
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
			_offscreen_witness(victim)
		else:
			_check_town_lost()
	acted_tonight = false
	# Every day without enough blood leaves the vampire hungrier
	vampire.set_hunger(vampire.blood - hunger_per_day)


func _hungry() -> bool:
	return vampire.blood < hungry_level


func _frenzied() -> bool:
	return vampire.blood < frenzy_level


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
			Playtest.count("vampire_recognized")
			Playtest.log_line("The doctor recognized the vampire on the street")
			_abort_hunt()
			return
		await get_tree().physics_frame
	if not hunting:
		return
	if _doctor_watching(victim) and not _frenzied():  # Starving, it no longer cares who is watching
		victim.marked = false  # The doctor kept watch: the hold is broken
		Playtest.count("vampire_scared_off_by_watch")
		Playtest.log_line("The vampire saw the doctor watching %s's door and fled" % victim.data.npc_name)
		_abort_hunt("A figure fled from %s's door when it saw the doctor." % victim.data.npc_name)
		return
	await get_tree().create_timer(2.0).timeout  # Inside the house...
	if vampire.witnessed or (_doctor_watching(victim) and not _frenzied()):
		_abort_hunt()
		return
	if not hunting:
		return
	_resolve_attack(victim)
	vampire.end_hunt()
	hunting = false


func _abort_hunt(event := "A shadow was seen prowling the streets. Nobody died tonight.") -> void:
	# Seen by the doctor: flee home, nobody is harmed tonight
	hunting = false
	vampire.end_hunt()
	GameState.add_night_event(event)


func _doctor_watching(victim: Node) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var door := GameState.place_position(victim.data.home)
	if player.global_position.distance_to(door) >= watch_range:
		return false
	if player.has_method("is_hidden") and player.is_hidden():
		return false  # In a bush or tall grass
	# A doctor hidden behind a tree or a wall isn't noticed: the vampire goes on, and can be caught
	var query := PhysicsRayQueryParameters3D.create(door + Vector3(0.0, 1.5, 0.0), player.global_position + Vector3(0.0, 0.5, 0.0))
	var skip: Array[RID] = [(player as CollisionObject3D).get_rid(), vampire.get_rid()]
	query.exclude = skip
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _finish_hunt_now() -> void:
	# The night ended mid-hunt (the doctor slept): settle it instantly
	hunting = false
	if hunt_victim and hunt_victim.is_alive() and not hunt_victim.is_servant:
		_resolve_attack(hunt_victim)
	vampire.stop_hunt()


func _seed_outbreak() -> void:
	# The anemia started before the doctor came: a few people are already weak
	var others := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire:
			others.append(npc)
	others.shuffle()
	for npc in others.slice(0, outbreak_size):
		npc.feed(randf_range(52.0, 62.0), _pick_trace(npc))
	# One or two healthy people, frightened by the outbreak, also claim to be ill
	var worried_count := randi_range(1, 2)
	for npc in others.slice(outbreak_size, outbreak_size + worried_count):
		npc.worried = true
	# Autumn: someone else may already have a chill (fever, not anemia)
	var rest := others.slice(outbreak_size + worried_count)
	if not rest.is_empty() and randf() < 0.6:
		rest.pick_random().catch_flu()


func _pick_victim() -> Node:
	# A marked person is the first to be visited again
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive() and npc.marked:
			return npc
	var victims := []
	var weak := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive() and not npc.is_servant and not npc.has_flu():
			victims.append(npc)  # Fever in the blood: the vampire leaves the sick alone
			if npc.is_anemic():
				weak.append(npc)
	if victims.is_empty():
		return null
	# Half the time it returns to someone already weakened
	if not weak.is_empty() and randf() < 0.5:
		return weak.pick_random()
	return victims.pick_random()


func _resolve_attack(victim: Node) -> void:
	var victim_name: String = victim.data.npc_name
	Playtest.count("vampire_attacks")
	Playtest.log_line("The vampire attacked %s" % victim_name)
	# At night the discovery belongs to the next morning
	var morning := GameState.day + 1 if GameState.is_night else GameState.day
	var others := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc != victim and npc.is_alive() and not npc.is_servant:
			others += 1
	# A marked person who was not saved during the day is turned now
	if victim.marked:
		fed_tonight = true
		victim.marked = false
		victim.make_servant()
		Playtest.count("servants_made")
		vampire.set_hunger(vampire.blood + 20.0)
		GameState.add_night_event("During the night, a figure was seen near %s's house." % victim_name)
		GameState.add_clue("Morning of Day %d: a figure was seen near %s's house." % [morning, victim_name], "evidence", morning)
		_check_town_lost()
		return
	# Feed. Death only comes when the blood runs out.
	var amount := randf_range(bite_min, bite_max)
	var starving := _hungry()
	var frenzy := _frenzied()
	if starving:
		amount *= 2.0  # Hungry: takes twice the blood
	fed_tonight = true
	var had: float = victim.blood
	# In a frenzy it is careless: the trace always points to the real vampire
	var died: bool = victim.feed(amount, vampire.data.clue_trait if frenzy else _pick_trace(victim))
	vampire.set_hunger(vampire.blood + minf(amount, had) * blood_gain)
	if died:
		GameState.add_night_event("%s was found dead at their doorstep." % victim_name)
		GameState.add_clue("Morning of Day %d: %s died during the night." % [morning, victim_name], "evidence", morning)
		EventBus.npc_died.emit(victim_name)
	elif frenzy:
		# No patience to turn anyone: it just feeds, and not quietly
		GameState.add_night_event("Screams were heard in the night. Someone woke up torn and gravely weak.")
		GameState.add_clue("Morning of Day %d: screams were heard near %s's house." % [morning, victim_name], "evidence", morning)
	elif others > 0 and randf() < servant_chance and victim.affinity >= 60.0:
		# They trust the doctor: marked, with one day to warn him
		victim.marked = true
		victim.marked_day = morning
		GameState.add_night_event("Somewhere in Pallbrook, someone woke up weaker than they went to bed.")
	elif others > 0 and randf() < servant_chance:
		# Sometimes the bite turns them (only if someone else is left to hunt)
		victim.make_servant()
		Playtest.count("servants_made")
		GameState.add_night_event("During the night, a figure was seen near %s's house." % victim_name)
		GameState.add_clue("Morning of Day %d: a figure was seen near %s's house." % [morning, victim_name], "evidence", morning)
	elif starving:
		GameState.add_night_event("Somewhere in Pallbrook, someone woke up gravely weak, as if drained.")
	else:
		GameState.add_night_event("Somewhere in Pallbrook, someone woke up weaker than they went to bed.")
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


func _offscreen_witness(victim: Node) -> void:
	# Nobody watched this hunt live, so roll whether a townsperson glimpsed it
	var night := GameState.last_night()  # Dawn has already started the new day
	var place: String = victim.data.home
	var candidates := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == vampire or npc == victim or not npc.is_alive() or npc.is_servant:
			continue
		# Night owls, still up at hunt time, are likelier to notice
		var bed: int = npc.plans.get(night, {}).get("bedtime", npc.data.bedtime)
		var still_up: bool = bed > hunt_hour
		var chance := 0.5 if still_up else 0.1
		if frenzy_tonight:
			chance = 0.8 if still_up else 0.3  # Reckless: easier to spot
		if randf() < chance:
			candidates.append(npc)
	if candidates.is_empty():
		return
	var witness = candidates.pick_random()
	var h := fmod(hunt_hour, 24.0)
	if randf() < (0.5 if frenzy_tonight else 0.25):
		witness.add_sighting(night, "person", vampire.data.npc_name, place, h)  # Saw the face
	else:
		witness.add_sighting(night, "figure", "", place, h)
