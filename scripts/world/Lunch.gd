class_name Lunch
extends Node3D

# Lunch at the tavern (see the design doc, "Almoço na taverna"). Between noon and 12:40 the doctor
# sits at the patio tables, pays a coin, and listens: two or three short exchanges between whoever
# is there, built from what is really going on in town. The doctor only overhears. What matters
# goes into the casebook; the rest is the town being alive (pairs teasing, old rivalries).
# A hot meal takes half an hour off the fatigue debt from a collapse, and everyone at the table
# warms to him a little.

const USE_AT := Vector3(-3.9, 0.0, 29.5)    # Between the two patio tables, south of the door
const USE_RANGE := 1.0
const OPENS := 12.0
const LAST_SEAT := 12.0 + 40.0 / 60.0
const PRICE := 1
const REST := 0.5           # Hours of fatigue debt a hot meal takes off (see DayNightCycle)
const WARMTH := 2.0         # Affinity with everyone at the table
const HOST := "Marta"
const REGULARS := ["Hugo", "Tomas", "Sarah", "Sophia", "Elias"]   # Lunch at the tavern most days
const GARLIC_ODDS := 0.35   # Days Marta serves garlic soup
const ICON := preload("res://assets/ui/icon_talk.png")

# Two people who are both at the table: a short exchange that shows who they are
const PAIRS := [
	["Tomas", "Saved you the seat by the window, Sarah.", "Sarah", "You saved it for yourself, and I happened to sit there."],
	["Sophia", "Still no answer about the torn pages, Mayor?", "Hugo", "Some things are better left in the past, Miss Sophia."],
	["Elias", "We missed you at Mass, Tomás.", "Tomas", "The forge doesn't keep Sundays, Father."],
	["Hugo", "Father, a word about the harvest festival later?", "Elias", "Of course, Hugo. After the bells."],
	["Sophia", "I found that atlas you wanted for the children.", "Sarah", "You're a treasure, Sophia."],
	["Tomas", "If the mayor needs a new gate, he can pay for the old one first.", "Hugo", "Tomás, please. Not at the table."],
	["Sarah", "The children asked if the doctor is staying.", "Sophia", "Tell them nobody stays in Pallbrook. They just stop leaving."],
]
const OPENINGS := [
	"Stew today, and bread from this morning. Eat while it's hot.",
	"Sit, sit. Mutton pie, and don't let Tomás take the biggest slice.",
	"Cabbage soup again. Complain to the weather, not to me.",
]
const ABSENT_REASONS := [
	"Says the light hurts the eyes these days.",
	"Says it's a cold, nothing more.",
	"Says there's too much work to stop for lunch.",
]

var prompt: Sprite3D
var running := false


func _ready() -> void:
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	add_child(prompt)
	prompt.global_position = USE_AT + Vector3(0.0, 2.0, 0.0)
	if not GameState.lunch.has("garlic_hater"):
		# One innocent who simply can't stand garlic, so a refused bowl proves nothing alone
		var names: Array = REGULARS.filter(func(n): return n != GameState.vampire_name)
		GameState.lunch["garlic_hater"] = names.pick_random() if not names.is_empty() else ""
		GameState.lunch["seen"] = []


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - USE_AT
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	prompt.visible = near and not running and not GameState.in_dialogue and not GameState.reading \
			and not GameState.is_night and GameState.hour >= 11.0 and GameState.hour < 14.0


# Before the doctor's own E (talking): someone standing by the table doesn't get in the way
func _input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if GameState.hour < OPENS:
		EventBus.dialogue_started.emit(HOST, tr("Lunch is at noon, doctor. Come back in a little while."))
	elif GameState.hour > LAST_SEAT:
		EventBus.dialogue_started.emit(HOST, tr("Lunch is over, doctor. There's bread left if you want it, but the talk has gone back to work."))
	elif int(GameState.lunch.get("day", -1)) == GameState.day:
		EventBus.dialogue_started.emit(HOST, tr("Back for more? You already ate today, doctor."))
	elif GameState.coins < PRICE:
		EventBus.dialogue_started.emit(HOST, tr("Lunch is a coin, doctor. Come back when the Town Hall pays you."))
	else:
		_run()


func _run() -> void:
	running = true
	GameState.lunch["day"] = GameState.day
	GameState.coins -= PRICE
	GameState.fatigue_debt = maxf(GameState.fatigue_debt - REST, 0.0)
	Playtest.count("lunch_at_tavern")
	var table := _at_table()
	for npc in table:
		npc.change_affinity(WARMTH)
	var names: Array = table.map(func(n): return n.data.npc_name)
	var lines := _scene(table, names)
	# He takes a chair at the table if one is marked there (a Seat); he gets up when he walks off
	var seat := Seat.nearest(get_tree(), USE_AT, 2.5)
	if seat:
		seat.sit_player(get_tree().get_first_node_in_group("player"))
	# The clock stops while they talk (nobody gets up mid-sentence); the hour passes after
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle:
		cycle.set_process(false)
	for line: Array in lines:
		EventBus.dialogue_started.emit(line[0], line[1])
		await EventBus.dialogue_ended
	if cycle:
		cycle.set_process(true)
		await cycle.pass_hours(1.0)
	running = false


# Who is eating here right now
func _at_table() -> Array:
	var marker := GameState.place_position("Taverna")
	var table := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.is_alive() and not npc.in_bed and npc.current_place == "Taverna" \
				and npc.global_position.distance_to(marker) < 8.0:
			table.append(npc)
	return table


func _npc(person: String) -> Node:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == person:
			return npc
	return null


# [speaker, line] in order. The host opens; then up to three exchanges, the ones that carry news
# first; quiet days get the table's own small talk.
func _scene(table: Array, names: Array) -> Array:
	var lines := []
	var host_here := HOST in names
	if host_here:
		lines.append([HOST, tr(OPENINGS.pick_random())])
	var talkers: Array = names.filter(func(n): return n != HOST)
	if talkers.size() + (1 if host_here else 0) < 2:
		lines.append([HOST if host_here else "Doctor", tr("Quiet today. Everyone's eating at home.") if host_here else tr("You eat alone on the patio. The town is quiet today.")])
		return lines
	var exchanges := []
	var news := _attack_news(names)
	if not news.is_empty():
		exchanges.append(news)
	exchanges.append_array(_sightings(table, names))
	if randf() < GARLIC_ODDS:
		var garlic := _garlic(names)
		if not garlic.is_empty():
			exchanges.append(garlic)
	var pale := _pale_one(names)
	if not pale.is_empty():
		exchanges.append(pale)
	var absent := _absence(names)
	if not absent.is_empty():
		exchanges.append(absent)
	var small := _small_talk(names)
	# At most three; small talk always gets a place when there is room
	var chosen := exchanges.slice(0, 3 if small.is_empty() else 2)
	if not small.is_empty():
		chosen.append(small)
	for exchange: Array in chosen:
		lines.append_array(exchange)
	return lines


# Someone attacked last night (alive): the host has heard
func _attack_news(names: Array) -> Array:
	var night := GameState.last_night()
	for a: Dictionary in GameState.attacks:
		if a["night"] != night:
			continue
		var victim: String = a["victim"]
		var speaker: String = HOST if HOST in names and victim != HOST else names.filter(func(n): return n != victim).pick_random()
		var reply_from: Array = names.filter(func(n): return n != speaker and n != victim)
		var text := tr("{who} woke up with a pallor that frightened me. Another one.").format({"who": tr(victim)})
		_note(speaker, text)
		var exchange := [[speaker, text]]
		if not reply_from.is_empty():
			var count := GameState.attacks.filter(func(x): return x["night"] > 0).size()
			exchange.append([reply_from.pick_random(), tr("That makes {n} since Jonas.").format({"n": count})])
		return exchange
	return []


# What someone at the table saw last night, out loud (the person seen may be sitting right there)
func _sightings(table: Array, names: Array) -> Array:
	var night := GameState.last_night()
	var found := []
	for npc in table:
		for s: Dictionary in npc.sightings:
			if s["night"] != night or s["kind"] != "person" or s["who"] == npc.data.npc_name:
				continue
			var key := "%d|%s|%s" % [night, npc.data.npc_name, s["who"]]
			if key in GameState.lunch["seen"]:
				continue
			GameState.lunch["seen"].append(key)
			var who: String = s["who"]
			var text := tr("I couldn't sleep last night. Around {hour} I saw {who} out by {place}.").format(
					{"hour": GameState.format_time(float(s["hour"])), "who": tr(who), "place": GameState.place_name(String(s["place"]))})
			_note(npc.data.npc_name, text)
			var exchange := [[npc.data.npc_name, text]]
			if who in names:
				exchange.append([who, tr("I went out for some air. Is that a crime now?")])
			else:
				var others: Array = names.filter(func(n): return n != npc.data.npc_name)
				if not others.is_empty():
					exchange.append([others.pick_random(), tr("At that hour? What business would anyone have out there?")])
			found.append(exchange)
			break
		if found.size() >= 1:
			break
	return found


# Garlic soup: the vampire (if it came out today) and one innocent who hates garlic turn it down
func _garlic(names: Array) -> Array:
	if not HOST in names:
		return []
	var exchange := [[HOST, tr("Garlic soup today. My mother swore it was good for the blood.")]]
	var refused := false
	for person: String in names:
		if person == HOST:
			continue
		if person == GameState.vampire_name:
			exchange.append([person, tr("Not for me, Marta. Just the bread, please.")])
		elif person == GameState.lunch.get("garlic_hater", ""):
			exchange.append([person, tr("You know I can't stand garlic, Marta.")])
		else:
			continue
		refused = true
		GameState.add_clue(tr("Day {day} · At lunch, {who} turned down Marta's garlic soup.").format({"day": GameState.day, "who": tr(person)}), "evidence")
	return exchange if refused else []


# Someone not at the table who has lost a lot of blood
func _pale_one(names: Array) -> Array:
	var palest = null  # Untyped: NPC fields
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.is_alive() and not npc.data.npc_name in names and npc.data.npc_name != GameState.vampire_name \
				and npc.blood < 70.0 and (palest == null or npc.blood < palest.blood):
			palest = npc
	if palest == null:
		return []
	var speakers: Array = names.filter(func(n): return n != HOST) if names.size() > 1 else names
	var speaker: String = speakers.pick_random()
	var text := tr("Has anyone seen {who} lately? A pallor like candle wax.").format({"who": tr(palest.data.npc_name)})
	_note(speaker, text)
	var exchange := [[speaker, text]]
	var others: Array = names.filter(func(n): return n != speaker)
	if not others.is_empty():
		exchange.append([others.pick_random(), tr("I took some broth over yesterday. It was barely touched.")])
	return exchange


# A regular who didn't come today
func _absence(names: Array) -> Array:
	var missing := []
	for person: String in REGULARS:
		var npc = _npc(person)
		if npc and npc.is_alive() and not person in names:
			missing.append(person)
	if missing.is_empty():
		return []
	var who: String = missing.pick_random()
	var speakers: Array = names.filter(func(n): return n != HOST) if names.size() > 1 else names
	var speaker: String = speakers.pick_random()
	var exchange := [[speaker, tr("No {who} again today.").format({"who": tr(who)})]]
	var others: Array = names.filter(func(n): return n != speaker)
	if not others.is_empty():
		exchange.append([others.pick_random(), tr("{who} keeps to the house lately.").format({"who": tr(who)}) + " " + tr(ABSENT_REASONS.pick_random())])
	return exchange


# Two who are both here, not heard yet this run
func _small_talk(names: Array) -> Array:
	var options := []
	for i in PAIRS.size():
		var entry: Array = PAIRS[i]
		if entry[0] in names and entry[2] in names and not ("pair%d" % i) in GameState.lunch["seen"]:
			options.append(i)
	if options.is_empty():
		return []
	var pick: int = options.pick_random()
	GameState.lunch["seen"].append("pair%d" % pick)
	var pair: Array = PAIRS[pick]
	return [[pair[0], tr(pair[1])], [pair[2], tr(pair[3])]]


func _note(speaker: String, text: String) -> void:
	GameState.add_clue(tr("Day {day} · At lunch, {name} said: \"{text}\"").format({"day": GameState.day, "name": tr(speaker), "text": text}))
