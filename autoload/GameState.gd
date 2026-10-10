extends Node

var day := 1
var hour := 8.0
var is_night := false
var exhaustion := 0.0              # 0.0 = rested, 1.0 = collapses
var collapsed_in_street := false   # Used by the morning summary later

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
