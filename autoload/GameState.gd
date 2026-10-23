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
	night_events.clear()
	clues.clear()
	coins = 4
	tonics = 1
	tonics_ordered = 0
	entries.clear()
	appointments.clear()

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
		if npc.data and text.contains(npc.data.npc_name):
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
	add_night_event("The Town Hall paid your salary: %d coins." % SALARY)
	if tonics_ordered > 0:
		tonics += tonics_ordered
		add_night_event("Your order arrived: %d iron tonic%s." % [tonics_ordered, "" if tonics_ordered == 1 else "s"])
		tonics_ordered = 0
	EventBus.phase_changed.emit(false)
	
var night_events: Array[String] = []

func add_night_event(text: String) -> void:
	night_events.append(text)


# Converts a float hour (e.g. 18.5) into "6:30 PM".
func format_time(h: float) -> String:
	var hours := int(h) % 24          # % 24 also handles values past midnight (24.5 → 0:30)
	var minutes := int((h - int(h)) * 6.0) * 10
	var suffix := "AM" if hours < 12 else "PM"
	var display_hour := hours % 12
	if display_hour == 0:
		display_hour = 12             # Midnight = 12 AM, noon = 12 PM
	return "%d:%02d %s" % [display_hour, minutes, suffix]


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
	return PLACE_NAMES.get(place, place)


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


func order_tonic() -> bool:
	if coins < TONIC_PRICE:
		return false
	coins -= TONIC_PRICE
	tonics_ordered += 1
	Playtest.count("tonics_ordered")
	return true
