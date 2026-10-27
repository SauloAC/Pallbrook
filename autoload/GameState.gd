extends Node

var day := 1
var hour := 8.0
var is_night := false
var exhaustion := 0.0              # 0.0 = rested, 1.0 = collapses
var collapsed_in_street := false   # Used by the morning summary later
var in_dialogue := false
var reading := false               # The casebook is open: the world slows down (see Notebook)
var casebook_hint_shown := false   # The first exam points the player to the casebook
var vampire_name := ""
var clues: Array[String] = []
# The casebook: {text, kind ("testimony" or "evidence"), day, people (names mentioned)}
var entries: Array[Dictionary] = []
# Clinic appointments: {day, name, from, until, status ("waiting", "treated", "missed")}
var appointments: Array[Dictionary] = []
var game_over := false
var intro_seen := false
var weather := "clear"           # Today's sky: clear, cloudy or fog (rolled at dawn)
var open_building := ""          # The walk-in building the doctor is standing in (roof hidden)
var open_upstairs := false       # ...and whether he is on its upper floor

# ---------- What people said about each night (for the casebook's cross-check) ----------
# The doctor compares statements by hand: pick a person and a night, then a witness.
# Nothing is marked as true or false until he does.
var alibis := {}       # "night|name" -> {plan: {hour: place}, bed: hour, home: place, text}
var reports := {}      # "night|witness" -> Array of sightings as told {kind, who, place, hour, inside}
var crosschecks := {}  # "night|subject|witness" -> "match", "conflict" or "silent"
var refusals := {}     # "night|name|alibi" or "night|name|seen" -> true: they wouldn't say
var beliefs := {}      # "night|subject|witness" -> "subject", "witness" or "unsure": who the doctor believes
var remarks: Array[Dictionary] = []  # The doctor's own notes: {night, people, text}
# What the doctor has learned about the creature (e.g. "servants": the bitten can lie for it).
# Hints in the casebook only appear once he knows. Filled by the old doctor's diary (to come).
var lore := {}
var chased := false             # The vampire is running after the doctor right now
var hunted_by_vampire := false  # He saw its face and got away: it knows
var faced_night := -1           # The last night it chased him (it greets him differently next day)
var faced_by := ""              # ...and who it was
var saw_hunting := {}           # name -> nights the doctor saw them sneaking out to hunt
var come_night := -1            # The night it comes for the doctor (two nights after it knows him)
var doom_tonight := false       # Tonight is that night
var known_since := -1           # The night it learned his face (that night doesn't count down)

# ---------- The hearing (see Hearing.gd) ----------
const MAX_HEARINGS := 2
var hearing := {}               # The one called: {accused, day}; empty when none is pending
var hearings_held := 0
# Attacks the whole town heard about: {night, victim, home}
var attacks: Array[Dictionary] = []
# The old doctor's diary (see Diary.gd): {spots, found, placed, last_name}
var diary := {}

# ---------- The doctor's purse ----------
const SALARY := 3        # Paid by the Town Hall every morning
const EXAM_FEE := 1      # Each patient pays for their first exam of the day
const TONIC_PRICE := 4   # Ingredients for one iron tonic, ordered from the clinic cabinet
var coins := 4
var tonics := 1          # Ready to give at the clinic
var tonics_ordered := 0  # Arrive tomorrow morning

func reset() -> void:
	# Autoloads survive a scene reload, so their state must be cleared by hand
	day = 1
	hour = 8.0
	is_night = false
	exhaustion = 0.0
	collapsed_in_street = false
	in_dialogue = false
	reading = false
	casebook_hint_shown = false
	Engine.time_scale = 1.0
	game_over = false
	vampire_name = ""
	weather = "clear"
	open_building = ""
	open_upstairs = false
	night_events.clear()
	clues.clear()
	coins = 4
	tonics = 1
	tonics_ordered = 0
	entries.clear()
	appointments.clear()
	alibis.clear()
	reports.clear()
	crosschecks.clear()
	refusals.clear()
	beliefs.clear()
	remarks.clear()
	lore.clear()
	chased = false
	hunted_by_vampire = false
	faced_night = -1
	faced_by = ""
	saw_hunting.clear()
	come_night = -1
	known_since = -1
	doom_tonight = false
	hearing = {}
	hearings_held = 0
	attacks.clear()
	diary = {}

# ---------- Cross-checking statements ----------

func record_alibi(night: int, person: String, plan: Dictionary, bed: int, home: String, text: String) -> void:
	alibis["%d|%s" % [night, person]] = {"plan": plan.duplicate(), "bed": bed, "home": home, "text": text}


func record_report(night: int, witness: String, told: Array) -> void:
	reports["%d|%s" % [night, witness]] = told.duplicate(true)


# It knows the doctor's face: on night `night` it comes for him (the earliest date stands)
func recognize(night: int) -> void:
	hunted_by_vampire = true
	if come_night < 0 or night < come_night:
		come_night = night
		known_since = day


# Free nights left before it comes (0 = tonight it comes; -1 = it doesn't know him).
# The count starts with the next night: the night it saw him is not one of them.
func nights_left() -> int:
	if come_night < 0:
		return -1
	var left := come_night - day
	if is_night and day == known_since:
		left -= 1
	return left


func record_attack(night: int, victim: String, home: String) -> void:
	attacks.append({"night": night, "victim": victim, "home": home})


# Who was attacked at that place that night ("" = nobody the town heard of)
func attack_at(night: int, place: String) -> String:
	for a in attacks:
		if a["night"] == night and a["home"] == place:
			return a["victim"]
	return ""


func learn(topic: String) -> void:
	if not lore.has(topic):
		lore[topic] = day
		Playtest.count("learned_" + topic)


func knows(topic: String) -> bool:
	return lore.has(topic)


# A note the doctor wrote himself from ready-made phrases (also filed in the casebook)
func add_remark(night: int, people: Array, text: String) -> void:
	remarks.append({"night": night, "people": people.duplicate(), "text": text})
	add_clue(tr("Night {night} · Your note: {text}").format({"night": night, "text": text}), "remark")
	Playtest.count("remarks_written")


func record_refusal(night: int, person: String, question: String) -> void:
	refusals["%d|%s|%s" % [night, person, question]] = true


# They wouldn't answer that question about that night (and never did later)
func refused(night: int, person: String, question: String) -> bool:
	if question == "alibi" and has_alibi(night, person):
		return false
	if question == "seen" and has_report(night, person):
		return false
	return refusals.has("%d|%s|%s" % [night, person, question])


func has_alibi(night: int, person: String) -> bool:
	return alibis.has("%d|%s" % [night, person])


func has_report(night: int, witness: String) -> bool:
	return reports.has("%d|%s" % [night, witness])


# What the witness said about the subject that night (sightings of that person only)
func sightings_of(night: int, witness: String, subject: String) -> Array:
	var told: Array = reports.get("%d|%s" % [night, witness], [])
	return told.filter(func(s): return s["kind"] == "person" and s["who"] == subject)


# The doctor compares one witness against one alibi. Returns "match", "conflict" or "silent"
# (the witness said nothing about that person), and remembers it for the nights table.
func cross_check(night: int, subject: String, witness: String) -> String:
	var seen := sightings_of(night, witness, subject)
	var result := "silent"
	var alibi: Dictionary = alibis.get("%d|%s" % [night, subject], {})
	if not seen.is_empty() and not alibi.is_empty():
		result = "match"
		for s in seen:
			if not _fits_alibi(alibi, s):
				result = "conflict"
				break
	var key := "%d|%s|%s" % [night, subject, witness]
	if not crosschecks.has(key) and result != "silent":
		Playtest.count("crosscheck_" + result)
	crosschecks[key] = result
	return result


# Night table mark for one person and night: "conflict", "match", "alibi" (told, not checked
# yet) or "" (not asked)
func night_mark(night: int, person: String) -> String:
	var mark := "alibi" if has_alibi(night, person) else ("refused" if refused(night, person, "alibi") else "")
	for key: String in crosschecks:
		var parts := key.split("|")
		if int(parts[0]) == night and parts[1] == person:
			if crosschecks[key] == "conflict":
				return "conflict"
			if crosschecks[key] == "match":
				mark = "match"
	return mark


# Where the alibi puts someone at an hour of the night (after bedtime: at home, in bed)
func _alibi_place(alibi: Dictionary, at_hour: float) -> String:
	var h := at_hour + 24.0 if at_hour < 12.0 else at_hour  # 1 AM comes after 11 PM
	var bed := float(alibi["bed"])
	if bed < 12.0:
		bed += 24.0
	if h >= bed:
		return alibi["home"]
	var plan: Dictionary = alibi["plan"]
	var hours := plan.keys()
	hours.sort()
	var place: String = plan[hours[0]]
	for k in hours:
		var key_h := float(k) + 24.0 if int(k) < 12 else float(k)
		if key_h <= h:
			place = plan[k]
	return place


# A sighting fits if the alibi puts them there at that hour, give or take half an hour for the
# walk between places (it used to be an hour, which let almost everything fit)
# places. Someone seen walking counts where they were heading too (they pass other places).
func _fits_alibi(alibi: Dictionary, s: Dictionary) -> bool:
	var heading: String = s.get("heading", "")
	for offset in [0.0, -0.5, 0.5]:
		var there := _alibi_place(alibi, fposmod(float(s["hour"]) + offset, 24.0))
		if there == s["place"] or (heading != "" and there == heading):
			return true
	return false


# kind: "testimony" (what people say) or "evidence" (what the doctor saw or found)
# on_day: which day the casebook files it under (default: today)
func add_clue(text: String, kind := "testimony", on_day := -1) -> void:
	if text in clues:
		return  # No duplicates
	clues.append(text)
	var filed_day := on_day if on_day > 0 else day
	entries.append({"text": text, "kind": kind, "day": filed_day, "people": _names_in(text)})
	EventBus.clue_found.emit(text)


# Every townsperson named in a line, so the casebook can show it under each of them
func _names_in(text: String) -> Array[String]:
	var names: Array[String] = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and (text.contains(npc.data.npc_name) or text.contains(tr(npc.data.npc_name))):
			names.append(npc.data.npc_name)
	return names

func start_night() -> void:
	night_events.clear()
	collapsed_in_street = false
	is_night = true
	EventBus.phase_changed.emit(true)

func start_day() -> void:
	is_night = false
	day += 1
	coins += SALARY
	_roll_weather()
	add_night_event(tr("The Town Hall paid your salary: %d coins.") % SALARY)
	if tonics_ordered > 0:
		tonics += tonics_ordered
		add_night_event(tr("Your order arrived: 1 iron tonic.") if tonics_ordered == 1 else tr("Your order arrived: %d iron tonics.") % tonics_ordered)
		tonics_ordered = 0
	EventBus.phase_changed.emit(false)
	
var night_events: Array[String] = []


# Autumn sky. A well-fed vampire can walk under clouds or fog, so the weather matters.
func _roll_weather() -> void:
	var r := randf()
	weather = "fog" if r < 0.25 else ("cloudy" if r < 0.55 else "clear")
	if weather == "fog":
		add_night_event(tr("A thick fog lies over Pallbrook this morning."))
	elif weather == "cloudy":
		add_night_event(tr("Grey clouds hide the sun today."))
	Playtest.count("days_" + weather)


func weather_name() -> String:
	return {"clear": "Clear", "cloudy": "Cloudy", "fog": "Fog"}.get(weather, "Clear")

func add_night_event(text: String) -> void:
	night_events.append(text)


# Converts a float hour (e.g. 18.5) into "6:30 PM" (or the current language's way;
# local = false keeps English, for the playtest report).
func format_time(h: float, local := true) -> String:
	var hours := int(h) % 24          # % 24 also handles values past midnight (24.5 → 0:30)
	var minutes := int((h - int(h)) * 6.0) * 10
	if local and Lang.clock_24h():
		return "%d:%02d" % [hours, minutes]  # Portuguese and Spanish read the clock 0-23
	var display_hour := hours % 12
	if display_hour == 0:
		display_hour = 12             # Midnight = 12 AM, noon = 12 PM
	var pattern := "%d:%02d AM" if hours < 12 else "%d:%02d PM"
	return (tr(pattern) if local else pattern) % [display_hour, minutes]


# ---------- Places ----------

# How each location marker is called in dialogue
const PLACE_NAMES := {
	"Clinica": "the Clinic",
	"Taverna": "the Tavern",
	"Igreja": "the Church",
	"Escola": "the School",
	"Prefeitura": "the Town Hall",
	"Biblioteca": "the Library",
	"Praca": "the square",
	"Casa1": "Clara's house",
	"Casa2": "Tomas's forge",
	"CasaSophia": "Sophia's house",
	"CasaSarah": "Sarah's house",
	"CasaHugo": "the Mayor's house",
}


func place_name(place: String) -> String:
	return tr(PLACE_NAMES.get(place, place))  # In the current language


# The location marker closest to a point in the world (e.g. where someone was seen)
func nearest_place(pos: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for marker in get_tree().get_nodes_in_group("locations"):
		var distance: float = pos.distance_to(marker.global_position)
		if distance < best_distance:
			best_distance = distance
			best = String(marker.name)
	return best


func place_position(place: String) -> Vector3:
	for marker in get_tree().get_nodes_in_group("locations"):
		if marker.name == place:
			return marker.global_position
	return Vector3.ZERO


# Nights are numbered by the day they start on: the night of Day 2 runs from
# 6 PM on Day 2 until 6 AM (the day counter only changes at sunrise).
# So during the day, "last night" is always day - 1.
func last_night() -> int:
	return day - 1


func order_tonic(count := 1) -> bool:
	if count < 1 or coins < TONIC_PRICE * count:
		return false
	coins -= TONIC_PRICE * count
	tonics_ordered += count
	for i in count:
		Playtest.count("tonics_ordered")
	return true
