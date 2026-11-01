extends Node

# Saving the game (see the design doc, "Salvar a partida"). The town is saved every morning, once
# the doctor has read the night's summary: everything the night changed is settled by then, nobody
# is mid-errand and the clock has just started. "Continue" on the title screen (and "back to the
# morning) reloads the town at that moment.
#
# The save pauses a case; it never undoes one. Losing ends the case and deletes it (a new case
# brings a new vampire), and what the doctor can't unlearn is written into it the moment it
# happens (see "What can't be undone" below), so closing the game is no way back either.
#
# What goes in the file:
#   game     - GameState: the casebook, what people said, the purse, the diary, the hearing...
#   npcs     - each townsperson: blood, trust, exams, complaints, sightings, alive or buried
#   director - the vampire's own plans that outlast a night, and the garden left without garlic
#   player   - where the doctor woke up
# Where people stand and what they were doing is not saved: at 6 AM they all follow their
# schedule from the start, so they are put straight where the schedule says (NPC.catch_up).
#
# The file is written with store_var and read without objects, so a shared save can't run code.

const PATH := "user://save.dat"
const FORMAT := 2   # Raise when the layout changes in a way older saves can't follow

# GameState fields that make up a case. Left out on purpose: what only lasts a moment (in_dialogue,
# reading, open_building, chased, pending_hours...) and what belongs to the session (intro_seen).
const GAME_PROPS := ["case_id", "act", "sign_day", "day", "hour", "is_night", "casebook_hint_shown", "vampire_name", "clues", "entries",
		"appointments", "weather", "alibis", "reports", "crosschecks", "refusals", "beliefs", "remarks",
		"lore", "hunted_by_vampire", "faced_night", "faced_by", "saw_hunting", "come_night", "known_since",
		"hearing", "hearings_held", "attacks", "diary", "mural", "coins", "items", "tonics_ordered",
		"gathered", "knows_tonic", "merchant", "history", "records_read", "lunch", "fatigue_debt",
		"hints_seen", "tutorial_done"]

var data := {}            # The save being loaded into the new scene
var restoring := false    # True from "Continue" until the town has taken its saved state


func has_save() -> bool:
	return not read().is_empty()


# The day the save was made on (0 = no save)
func saved_day() -> int:
	return int(read().get("day", 0))


func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var loaded = file.get_var(false)  # Never objects
	if not loaded is Dictionary or int(loaded.get("format", 0)) != FORMAT:
		return {}
	return loaded


func delete_save() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# ---------- Saving ----------

func save_game() -> void:
	if GameState.game_over or GameState.is_night:
		return
	var npcs := {}
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data:
			npcs[npc.data.npc_name] = npc.save_state()
	var director = get_tree().get_first_node_in_group("vampire_director")
	var zones = get_tree().get_first_node_in_group("safe_zones")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var out := {
		"format": FORMAT,
		"build": Playtest.VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"day": GameState.day,
		"game": pack(GameState, GAME_PROPS),
		"npcs": npcs,
		"director": {
			"plant_false_trace": director.plant_false_trace if director else false,
			"no_garlic": zones.no_garlic_owner if zones else "",
		},
		"player": {"at": player.global_position if player else Vector3.ZERO},
	}
	if not _write(out):
		return
	Settings.show_toast(tr("Saved: morning of Day {day}").format({"day": GameState.day}))
	Playtest.log_line("Saved")


# Written beside the old save first, so closing the game halfway never loses both
func _write(out: Dictionary) -> bool:
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_var(out)
	file.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists("save.dat"):
		dir.remove("save.dat")
	return dir.rename("save.dat.tmp", "save.dat") == OK


# ---------- What can't be undone ----------
# Some moments must outlast closing the game before the next morning's save, or the player could
# quit and come back knowing what he shouldn't: who chased him, how a hearing went. Only their
# consequences are written into this morning's save, on the spot; the rest of the day stays as
# it was. (Dying needs none of this: the save is deleted the moment it catches him.)

# Edits this case's save (nothing before the first morning, or if the save is another case's)
func _edit(change: Callable) -> void:
	if restoring or GameState.case_id == "":
		return
	var saved := read()
	if saved.is_empty() or saved.get("game", {}).get("case_id", "") != GameState.case_id:
		return
	change.call(saved)
	_write(saved)


# GameState fields as they are now (e.g. the vampire knowing his face, a hearing spent)
func remember(props: Array) -> void:
	var values := pack(GameState, props)
	_edit(func(saved: Dictionary): saved["game"].merge(values, true))


# Face to face with it. Closing the game mid-chase counts as getting away: it knows him.
func remember_chase(come_night: int) -> void:
	var night := GameState.faced_night
	var by := GameState.faced_by
	var today := GameState.day
	_edit(func(saved: Dictionary):
		var game: Dictionary = saved["game"]
		game["faced_night"] = night
		game["faced_by"] = by
		game["hunted_by_vampire"] = true
		var known := int(game.get("come_night", -1))
		if known < 0 or come_night < known:
			game["come_night"] = come_night
			game["known_since"] = today)


# One casebook line he can't forget (he saw who was sneaking through the dark)
func remember_entry(text: String) -> void:
	var entry := {}
	for e: Dictionary in GameState.entries:
		if e["text"] == text:
			entry = e.duplicate(true)
	if entry.is_empty():
		return
	_edit(func(saved: Dictionary):
		var game: Dictionary = saved["game"]
		if not game["clues"].has(text):
			game["clues"].append(text)
			game["entries"].append(entry))


# Each townsperson's fields as they are now, and whether they are still in town (after a hearing)
func remember_townsfolk(props: Array) -> void:
	var values := {}
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data:
			values[npc.data.npc_name] = {"vars": pack(npc, props), "status": npc.save_state()["status"]}
	_edit(func(saved: Dictionary):
		for who: String in values:
			if saved["npcs"].has(who):
				saved["npcs"][who]["vars"].merge(values[who]["vars"], true)
				saved["npcs"][who]["status"] = values[who]["status"])


# ---------- Loading ----------

# Starts the town again from the saved morning (Continue on the title screen).
# Returns false if there is nothing to load.
func continue_game() -> bool:
	var loaded := read()
	if loaded.is_empty():
		return false
	GameState.reset()
	unpack(GameState, loaded.get("game", {}))
	GameState.intro_seen = true
	GameState.tutorial_done = GameState.tutorial_done or GameState.day > 1
	data = loaded
	restoring = true
	Playtest.log_line("Continued from the morning of Day %d" % GameState.day)
	Audio.start_game()
	get_tree().paused = false
	get_tree().reload_current_scene()
	return true


# Called by each townsperson as they appear in the reloaded town
func npc_data(npc_name: String) -> Dictionary:
	return data.get("npcs", {}).get(npc_name, {})


# Called by the VampireDirector once it has rebuilt the town around the saved vampire
func finish_restore() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var at = data.get("player", {}).get("at", null)
	if player and at is Vector3 and at != Vector3.ZERO:
		player.global_position = at
		player.reset_physics_interpolation()
	restoring = false
	data = {}


# ---------- Copying fields ----------

func pack(obj: Object, props: Array) -> Dictionary:
	var out := {}
	for prop: String in props:
		var value = obj.get(prop)
		out[prop] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return out


# Typed arrays (Array[Dictionary], Array[String]) are refilled in place so they keep their type
func unpack(obj: Object, saved: Dictionary) -> void:
	for prop: String in saved:
		if not prop in obj:
			continue  # A field from an older build
		var current = obj.get(prop)
		var value = saved[prop]
		if current is Array and value is Array:
			current.clear()
			current.assign(value.duplicate(true))
		elif current is Dictionary and value is Dictionary:
			obj.set(prop, value.duplicate(true))
		elif typeof(current) == typeof(value):
			obj.set(prop, value)
		elif current is float and value is int:
			obj.set(prop, float(value))
