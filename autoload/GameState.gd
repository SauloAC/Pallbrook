extends Node

var day := 1
var is_night := false

func start_night() -> void:
	is_night = true
	EventBus.phase_changed.emit(true)

func start_day() -> void:
	is_night = false
	day += 1
	EventBus.phase_changed.emit(false)
