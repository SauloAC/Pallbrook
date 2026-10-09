extends Node

var day := 1
var is_night := false
var exhaustion := 0.0              # 0.0 = rested, 1.0 = collapses
var collapsed_in_street := false   # Used by the morning summary later

func start_night() -> void:
	is_night = true
	EventBus.phase_changed.emit(true)

func start_day() -> void:
	is_night = false
	day += 1
	EventBus.phase_changed.emit(false)
