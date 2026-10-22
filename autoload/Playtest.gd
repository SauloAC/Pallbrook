extends Node

# Playtest report: quietly records what happens in each run and writes it to
# user://playtest/ (a readable .txt and a .json for comparing testers).
# At the end of a run it asks a few short questions and offers to open the folder.
#   Windows: %APPDATA%\Godot\app_userdata\Pallbrook\playtest
#   macOS:   ~/Library/Application Support/Godot/app_userdata/Pallbrook/playtest
# Anywhere in the game: Playtest.count("key") to tally something, Playtest.log_line("text") for a line.

const VERSION := "0.1.0"
const FOLDER := "user://playtest"
const QUESTIONS := [
	"Who did you suspect, and why?",
	"What was the most confusing thing?",
	"What did you enjoy most?",
	"Anything else? (bugs, ideas, what you'd change)",
]

var run_id := ""
var started_msec := 0
var reading_msec := 0
var reading_since := -1
var totals: Dictionary = {}
var today: Dictionary = {}
var days: Array[Dictionary] = []
var lines: Array[String] = []
var result := "unfinished"   # won / lost / quit
var ending := ""
var accused := ""
var answers: Array[String] = []
var finished := false

var survey: CanvasLayer
var after_survey: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.npc_died.connect(func(who: String): count("deaths"); log_line("%s died" % who))
	EventBus.player_collapsed.connect(func(): count("collapses"); log_line("The doctor collapsed in the street"))
	EventBus.player_slept.connect(func(): count("nights_slept_at_clinic"))
	EventBus.game_ended.connect(_on_game_ended)
	start_run()


# A new run: called at launch and when the player chooses to play again
func start_run() -> void:
	run_id = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	started_msec = Time.get_ticks_msec()
	reading_msec = 0
	reading_since = -1
	totals = {}
	today = {"day": 1}
	days = []
	lines = []
	result = "unfinished"
	ending = ""
	accused = ""
	answers = []
	finished = false


func count(key: String, amount := 1) -> void:
	totals[key] = totals.get(key, 0) + amount
	today[key] = today.get(key, 0) + amount


func log_line(text: String) -> void:
	lines.append("Day %d %s · %s" % [GameState.day, GameState.format_time(GameState.hour), text])


func note_accused(npc_name: String) -> void:
	accused = npc_name


# The casebook tells us when it opens and closes: how long people spend reading
func reading_started() -> void:
	if reading_since < 0:
		reading_since = Time.get_ticks_msec()


func reading_stopped() -> void:
	if reading_since >= 0:
		reading_msec += Time.get_ticks_msec() - reading_since
		reading_since = -1


func _on_phase_changed(is_night: bool) -> void:
	if is_night:
		return
	# Dawn: close yesterday's page and save what we have, in case the game is closed later
	today["coins"] = GameState.coins
	today["tonics"] = GameState.tonics
	days.append(today)
	today = {"day": GameState.day}
	_write()


func _on_game_ended(won: bool, message: String) -> void:
	result = "won" if won else "lost"
	ending = message
	finished = true
	reading_stopped()
	_write()


func _notification(what: int) -> void:
	# Closed the window mid-game: keep what we have
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not finished:
		result = "quit"
		reading_stopped()
		_write()


# ---------- The report ----------

func _people() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data == null:
			continue
		out.append({"name": npc.data.npc_name, "vampire": npc.is_vampire(), "alive": npc.is_alive(),
				"servant": npc.is_servant, "blood": roundi(npc.blood), "bites": npc.bite_spots.size(),
				"flu": npc.has_flu(), "marked": npc.marked, "trust": roundi(npc.affinity),
				"exams": npc.exams.size()})
	return out


func _report() -> Dictionary:
	var played := (Time.get_ticks_msec() - started_msec) / 60000.0
	return {"version": VERSION, "run": run_id, "os": OS.get_name(), "result": result, "ending": ending,
			"vampire": GameState.vampire_name, "accused": accused, "day_reached": GameState.day,
			"minutes_played": snappedf(played, 0.1), "minutes_reading_casebook": snappedf(reading_msec / 60000.0, 0.1),
			"casebook_entries": GameState.entries.size(), "appointments": GameState.appointments,
			"totals": totals, "days": days + [today], "people": _people(), "log": lines,
			"answers": _answers_dict()}


func _answers_dict() -> Dictionary:
	var d := {}
	for i in answers.size():
		d[QUESTIONS[i]] = answers[i]
	return d


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var r := _report()
	var json := FileAccess.open("%s/run_%s.json" % [FOLDER, run_id], FileAccess.WRITE)
	if json:
		json.store_string(JSON.stringify(r, "  "))
	var txt := FileAccess.open("%s/run_%s.txt" % [FOLDER, run_id], FileAccess.WRITE)
	if txt:
		txt.store_string(_as_text(r))


func _as_text(r: Dictionary) -> String:
	var t: Array[String] = []
	t.append("PALLBROOK PLAYTEST REPORT  (version %s)" % r["version"])
	t.append("Run %s on %s" % [r["run"], r["os"]])
	t.append("")
	t.append("Result: %s" % r["result"])
	if r["ending"] != "":
		t.append(r["ending"])
	t.append("The vampire was: %s" % r["vampire"])
	t.append("Accused: %s" % (r["accused"] if r["accused"] != "" else "nobody"))
	t.append("Reached day %d · %.1f minutes played · %.1f minutes in the casebook" % [r["day_reached"], r["minutes_played"], r["minutes_reading_casebook"]])
	t.append("")
	t.append("TOTALS")
	var keys: Array = r["totals"].keys()
	keys.sort()
	for k in keys:
		t.append("  %s: %s" % [k, r["totals"][k]])
	t.append("")
	t.append("DAY BY DAY")
	for d in r["days"]:
		var bits: Array[String] = []
		for k in d.keys():
			if k != "day":
				bits.append("%s %s" % [k, d[k]])
		t.append("  Day %s: %s" % [d["day"], ", ".join(PackedStringArray(bits)) if not bits.is_empty() else "-"])
	t.append("")
	t.append("TOWNSFOLK AT THE END")
	for p in r["people"]:
		t.append("  %s%s: %s, blood %d, bites %d, trust %d, exams %d%s%s%s" % [p["name"], " (VAMPIRE)" if p["vampire"] else "",
				"alive" if p["alive"] else "dead", p["blood"], p["bites"], p["trust"], p["exams"],
				", servant" if p["servant"] else "", ", flu" if p["flu"] else "", ", marked" if p["marked"] else ""])
	t.append("")
	t.append("CLINIC APPOINTMENTS")
	for a in r["appointments"]:
		t.append("  Day %d %s: %s" % [a["day"], a["name"], a["status"]])
	t.append("")
	t.append("EVENTS")
	for l in r["log"]:
		t.append("  " + l)
	if not r["answers"].is_empty():
		t.append("")
		t.append("PLAYER'S ANSWERS")
		for q in r["answers"].keys():
			t.append("  " + q)
			t.append("    " + str(r["answers"][q]))
	return "\n".join(PackedStringArray(t)) + "\n"


# ---------- End-of-run questions ----------

func show_survey(then: Callable) -> void:
	after_survey = then
	if survey:
		survey.queue_free()
	survey = CanvasLayer.new()
	survey.layer = 50
	survey.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(survey)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	survey.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(760, 0)
	box.position = Vector2(-380, -330)
	box.add_theme_constant_override("separation", 8)
	survey.add_child(box)
	box.add_child(_label("A few questions for the playtest", 30))
	box.add_child(_label("Short answers are fine. They are saved with the report of this run.", 18))
	var fields: Array[TextEdit] = []
	for q in QUESTIONS:
		box.add_child(_label(q, 20))
		var field := TextEdit.new()
		field.custom_minimum_size = Vector2(760, 70)
		field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		field.add_theme_font_size_override("font_size", 18)
		box.add_child(field)
		fields.append(field)
	box.add_child(_label("Report folder: " + ProjectSettings.globalize_path(FOLDER), 14))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var save := Button.new()
	save.text = "Save and open the report folder"
	save.add_theme_font_size_override("font_size", 20)
	save.pressed.connect(func(): _finish_survey(fields, true))
	buttons.add_child(save)
	var skip := Button.new()
	skip.text = "Save without answering"
	skip.add_theme_font_size_override("font_size", 20)
	skip.pressed.connect(func(): _finish_survey(fields, false))
	buttons.add_child(skip)
	fields[0].grab_focus()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	return l


func _finish_survey(fields: Array[TextEdit], open_folder: bool) -> void:
	answers = []
	for f in fields:
		answers.append(f.text.strip_edges())
	_write()
	if open_folder:
		OS.shell_open(ProjectSettings.globalize_path(FOLDER))
	survey.queue_free()
	survey = null
	if after_survey.is_valid():
		after_survey.call()
