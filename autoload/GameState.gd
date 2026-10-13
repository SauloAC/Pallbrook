extends Node

var day := 1
var hour := 8.0
var is_night := false
var exhaustion := 0.0              # 0.0 = rested, 1.0 = collapses
var collapsed_in_street := false   # Used by the morning summary later
var in_dialogue := false
var vampire_name := ""
var clues: Array[String] = []
var game_over := false
var intro_seen := false

func reset() -> void:
	# Autoloads survive a scene reload, so their state must be cleared by hand
	day = 1
	hour = 8.0
	is_night = false
	exhaustion = 0.0
	collapsed_in_street = false
	in_dialogue = false
	game_over = false
	vampire_name = ""
	night_events.clear()
	clues.clear()

func add_clue(text: String) -> void:
	if text in clues:
		return  # No duplicates
	clues.append(text)
	EventBus.clue_found.emit(text)

func start_night() -> void:
	night_events.clear()
	collapsed_in_street = false
	is_night = true
	EventBus.phase_changed.emit(true)

func start_day() -> void:
	is_night = false
	day += 1
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
