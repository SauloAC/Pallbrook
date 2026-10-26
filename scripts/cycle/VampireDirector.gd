extends Node

# Picks the secret vampire and runs their nightly hunt

@export_range(0.0, 1.0) var servant_chance := 0.35
@export var townsfolk_per_servant := 3  # At most one servant for every this many townsfolk (2 of 7)
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

# ---------- Meeting the doctor at night ----------
# 1. It notices him from afar (he didn't see its face): it gives up for tonight, and its next
#    bite leaves someone else's trace on purpose.
# 2. They see each other up close: it chases him. He gets away by breaking its line of sight
#    for a few seconds, reaching a safe place (church, a garden with garlic, over the bridge)
#    or lasting until dawn.
# 3. It reaches him: the game ends.
const CHASE_TRIGGER := 7.0     # Mutual sighting closer than this starts the chase
const CATCH_RANGE := 1.1       # Contact, or as good as
const LOSE_SECONDS := 4.0      # Out of its sight this long and it gives up
const SAFE_GIVE_UP := 8.0      # Waiting at the edge of a safe place this long, then it leaves
var chasing := false
var chased_tonight := false     # One chase a night: after that it heads home
var plant_false_trace := false  # Next bite leaves someone else's trace (it knows it was seen)
var safe_zones: SafeZones
var hunt_hour := 23.0
var relentless := false        # Tonight's chase is for the doctor: no giving up


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
	safe_zones = SafeZones.new()
	add_child(safe_zones)
	safe_zones.setup(GameState.vampire_name)
	var diary := Diary.new()  # The old doctor's torn pages, hidden around town
	add_child(diary)
	diary.setup(GameState.vampire_name)
	#print("[DEBUG] The vampire is: ", GameState.vampire_name)


func _on_phase_changed(is_night: bool) -> void:
	if GameState.game_over or vampire == null:
		return
	if is_night:
		acted_tonight = false
		chased_tonight = false
		fed_tonight = false
		frenzy_tonight = _frenzied()
		# Two nights after it learned his face (and he didn't bring it to justice), it comes for him
		GameState.doom_tonight = GameState.come_night >= 0 and GameState.day >= GameState.come_night
		if GameState.doom_tonight:
			hunt_hour = randf_range(20.5, 21.5)
			Playtest.log_line("Tonight the vampire comes for the doctor")
		elif frenzy_tonight:
			hunt_hour = randf_range(20.5, 22.0)  # Can't wait: hunts while people are still up
		else:
			hunt_hour = randf_range(hunt_start_hour, hunt_end_hour)
		return
	# Dawn
	GameState.doom_tonight = false
	if chasing:
		_end_chase(true)
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
	if GameState.game_over or vampire == null or not GameState.is_night:
		return
	# Face to face with the doctor, at any point of its night (going out or coming back)
	if not chasing and not chased_tonight and vampire.state == vampire.State.HUNTING and vampire.witnessed and vampire.noticed_doctor:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and vampire.global_position.distance_to(player.global_position) < CHASE_TRIGGER:
			_start_chase()
			return
	if acted_tonight or hunting:
		return
	# Hours after midnight count as 24+, so 00:30 = 24.5
	var h := GameState.hour if GameState.hour >= 12.0 else GameState.hour + 24.0
	if GameState.doom_tonight and not chasing and h >= hunt_hour:
		# No victim tonight: it goes straight for the doctor, wherever he is
		acted_tonight = true
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			vampire.start_hunt(GameState.nearest_place(player.global_position))
			_start_chase(true)
		return
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
	var counted := false
	while hunting and not vampire.agent.is_navigation_finished():
		if chasing:
			return  # Face to face: the chase took over
		if vampire.witnessed and not counted:
			counted = true  # Seen from hiding: the doctor knows, the vampire doesn't
			Playtest.count("vampire_recognized")
			Playtest.log_line("The doctor recognized the vampire on the street")
		if vampire.noticed_doctor and not vampire.witnessed:
			# Spotted from afar: not tonight, and next time it covers its tracks
			Playtest.count("vampire_noticed_doctor")
			Playtest.log_line("The vampire noticed the doctor from afar and gave up")
			plant_false_trace = true
			_abort_hunt()
			return
		await get_tree().physics_frame
	if not hunting:
		return
	if _doctor_watching(victim) and not _frenzied():  # Starving, it no longer cares who is watching
		victim.marked = false  # The doctor kept watch: the hold is broken
		Playtest.count("vampire_scared_off_by_watch")
		Playtest.log_line("The vampire saw the doctor watching %s's door and fled" % victim.data.npc_name)
		_abort_hunt(_t("A figure fled from {name}'s door when it saw the doctor.", {"name": tr(victim.data.npc_name)}))
		return
	await get_tree().create_timer(2.0).timeout  # Inside the house...
	if chasing:
		return
	if vampire.noticed_doctor or (_doctor_watching(victim) and not _frenzied()):
		_abort_hunt()
		return
	if not hunting:
		return
	_resolve_attack(victim)
	vampire.end_hunt()
	hunting = false


func _abort_hunt(event := "") -> void:
	# Seen by the doctor: flee home, nobody is harmed tonight
	hunting = false
	vampire.end_hunt()
	GameState.add_night_event(event if event != "" else tr("A shadow was seen prowling the streets. Nobody died tonight."))


# A night event or clue in the current language ({placeholders} filled after translating)
func _t(text: String, args := {}) -> String:
	return Lang.contract(tr(text).format(args))


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
	var night := GameState.day if GameState.is_night else GameState.day - 1  # The night it happened
	var shown := {"name": tr(victim_name)}  # The name as the current language writes it
	Playtest.count("vampire_attacks")
	Playtest.log_line("The vampire attacked %s" % victim_name)
	# At night the discovery belongs to the next morning
	var morning := GameState.day + 1 if GameState.is_night else GameState.day
	shown["day"] = morning
	var others := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc != victim and npc.is_alive() and not npc.is_servant:
			others += 1
	# A marked person who was not saved during the day is turned now (if there is room:
	# otherwise the mark fades and it simply feeds)
	if victim.marked and _servant_slots(victim) <= 0:
		victim.marked = false
	if victim.marked:
		fed_tonight = true
		victim.marked = false
		victim.make_servant()
		Playtest.count("servants_made")
		vampire.set_hunger(vampire.blood + 20.0)
		GameState.record_attack(night, victim_name, victim.data.home)
		GameState.add_night_event(_t("During the night, a figure was seen near {name}'s house.", shown))
		GameState.add_clue(_t("Morning of Day {day}: a figure was seen near {name}'s house.", shown), "evidence", morning)
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
	if died or frenzy:
		GameState.record_attack(night, victim_name, victim.data.home)  # Everyone heard of it
	if died:
		GameState.add_night_event(_t("{name} was found dead at their doorstep.", shown))
		GameState.add_clue(_t("Morning of Day {day}: {name} died during the night.", shown), "evidence", morning)
		EventBus.npc_died.emit(victim_name)
	elif frenzy:
		# No patience to turn anyone: it just feeds, and not quietly
		GameState.add_night_event(tr("Screams were heard in the night. Someone woke up torn and gravely weak."))
		GameState.add_clue(_t("Morning of Day {day}: screams were heard near {name}'s house.", shown), "evidence", morning)
	elif others > 0 and _servant_slots() > 0 and randf() < servant_chance and victim.affinity >= 60.0:
		# They trust the doctor: marked, with one day to warn him
		victim.marked = true
		victim.marked_day = morning
		GameState.add_night_event(tr("Somewhere in Pallbrook, someone woke up weaker than they went to bed."))
	elif others > 0 and _servant_slots() > 0 and randf() < servant_chance:
		# Sometimes the bite turns them (only if someone else is left to hunt)
		victim.make_servant()
		Playtest.count("servants_made")
		GameState.record_attack(night, victim_name, victim.data.home)
		GameState.add_night_event(_t("During the night, a figure was seen near {name}'s house.", shown))
		GameState.add_clue(_t("Morning of Day {day}: a figure was seen near {name}'s house.", shown), "evidence", morning)
	elif starving:
		GameState.add_night_event(tr("Somewhere in Pallbrook, someone woke up gravely weak, as if drained."))
	else:
		GameState.add_night_event(tr("Somewhere in Pallbrook, someone woke up weaker than they went to bed."))
	_check_town_lost()


# Not everyone bitten becomes a servant: only those it chooses, and only a few at a time.
# A town of servants would never vote against it, however much they trust the doctor.
# Marked people (turning tomorrow) hold a place too; `turning` is one about to be turned now.
func _servant_slots(turning: Node = null) -> int:
	var townsfolk := 0
	var taken := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == vampire or npc.data == null:
			continue
		townsfolk += 1
		if npc.is_alive() and (npc.is_servant or (npc.marked and npc != turning)):
			taken += 1
	return maxi(1, floori(townsfolk / float(townsfolk_per_servant))) - taken


func _pick_trace(victim: Node) -> String:
	if plant_false_trace:
		plant_false_trace = false  # Seen recently: this time it leaves someone else's trace
	elif randf() < clue_reliability:
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
	EventBus.game_ended.emit(false, _t("No one in Pallbrook is free anymore. {name} has won.", {"name": tr(vampire.data.npc_name)}))


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


# ---------- The chase ----------

func _start_chase(for_the_doctor := false) -> void:
	chasing = true
	relentless = for_the_doctor
	chased_tonight = true
	hunting = false  # Whatever it was doing, the doctor comes first now
	vampire.chasing = true
	vampire.hunt_returning = false
	GameState.chased = true
	GameState.faced_night = GameState.day  # The day only turns at dawn
	GameState.faced_by = vampire.data.npc_name
	Playtest.count("chases")
	Playtest.log_line("The vampire saw the doctor face to face and chased him")
	Audio.play("clue", -2.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var out_of_sight := 0.0
	var waiting := 0.0
	var retarget := 0.0
	var target := player.global_position
	while chasing:
		await get_tree().physics_frame
		if not chasing or GameState.game_over or not GameState.is_night:
			return
		var delta := get_physics_process_delta_time()
		# Measured on the ground: the doctor's origin sits a metre up, at his capsule's centre
		var gap: Vector3 = vampire.global_position - player.global_position
		var distance := Vector2(gap.x, gap.z).length()
		if distance < CATCH_RANGE and not safe_zones.is_safe(player.global_position):
			_caught()
			return
		if safe_zones.is_safe(player.global_position):
			# It stops at the edge and waits
			target = safe_zones.wait_point(player.global_position)
			waiting += delta
			if waiting > SAFE_GIVE_UP and not relentless:  # Tonight it waits until dawn
				_end_chase(false)
				return
		else:
			waiting = 0.0
			if relentless or vampire.sees(player, true):  # A bush won't hide him; tonight nothing will
				out_of_sight = 0.0
				target = player.global_position
			else:
				out_of_sight += delta  # Goes on to where it last saw him
				if out_of_sight > LOSE_SECONDS:
					_end_chase(false)
					return
		retarget -= delta
		if retarget <= 0.0:
			retarget = 0.25
			vampire.go_to(target)


# He lived through the night it came for him, but the town saw where: a doctor who sleeps on
# the church floor or crouched in someone's vegetable patch is a man with something to fear.
func _hid_all_night() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var where := safe_zones.kind(player.global_position) if player else ""
	var lines := {"church": "Word spread that the doctor spent the night on the church floor. People trust him a little less.",
			"garden": "Word spread that the doctor spent the night crouched in someone's garden. People trust him a little less.",
			"river": "Word spread that the doctor spent the night among the graves beyond the bridge. People trust him a little less."}
	if not lines.has(where):
		return
	GameState.add_night_event(tr(lines[where]))
	Playtest.count("hid_from_the_vampire")
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc != vampire and npc.is_alive():
			npc.change_affinity(-6.0)


# The doctor got away (or the sun came up). It knows he saw its face.
func _end_chase(dawn: bool) -> void:
	if not chasing:
		return
	chasing = false
	GameState.chased = false
	if relentless:
		relentless = false
		if dawn:
			vampire.stop_hunt()
		else:
			vampire.end_hunt()
		GameState.add_night_event(tr("It hunted you all night, and waited where it could not follow. At dawn it was gone. It will come again tonight."))
		_hid_all_night()
		return
	var first := not GameState.hunted_by_vampire
	GameState.recognize(GameState.faced_night + 3)  # Two nights to bring it before the town
	if dawn:
		vampire.stop_hunt()
	else:
		vampire.end_hunt()
	Playtest.count("chases_escaped")
	Playtest.log_line("The doctor escaped the chase")
	GameState.add_night_event(tr("You saw its face, and it saw yours. You got away, but it knows."))
	if first:
		GameState.add_night_event(tr("You have two nights to bring it before the town. Then it will come for you."))


func _caught() -> void:
	chasing = false
	GameState.chased = false
	Playtest.count("caught_by_vampire")
	Playtest.log_line("The vampire caught the doctor")
	GameState.in_dialogue = true  # Stops the doctor where he stands
	Audio.play("death")
	# The night closes in red, then the end
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var red := ColorRect.new()
	red.color = Color(0.35, 0.0, 0.0, 0.0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(red)
	var tween := create_tween()
	tween.tween_property(red, "color:a", 0.9, 1.2)
	await tween.finished
	await get_tree().create_timer(0.8).timeout
	layer.queue_free()
	GameState.in_dialogue = false
	EventBus.game_ended.emit(false, tr("It caught you in the dark. In the morning they buried you beyond the bridge. Pallbrook will need another doctor."))
