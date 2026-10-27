class_name Hearing
extends CanvasLayer

# The hearing at the Town Hall (see the design doc, "A Audiência").
# The doctor accuses someone during the day (Q) and the town gathers at 7 PM. He presents up
# to three pieces of evidence from his casebook, calls up to two witnesses, hears the
# defence, and the town votes. Two hearings per run.
#   Guilty and the vampire: the town is saved (for now: the old doctor's act comes later).
#   Guilty but innocent: they are shut outside the town gate, the town trusts the doctor less,
#   the hunt goes on.
# A frightened town wants a full case: three pieces of evidence and two witnesses who speak.
# Short of that, only those who trust the doctor deeply weigh his case at all.
#   Acquitted and the vampire: it walks free and it knows; two nights later it comes for him.
#   Acquitted and innocent: they won't forgive him soon.

const HOUR := 19.0
const MAX_EVIDENCE := 3
const MAX_WITNESSES := 2
const GUILTY_SCORE := 4.0     # A voter's conviction needed to say "guilty"
const DEEP_TRUST := 80.0      # Without a full case, only voters this close to the doctor listen
const PANEL_SIZE := Vector2(820, 560)

enum Step { NONE, EVIDENCE, WITNESSES, TESTIMONY, VOTE, VERDICT }

var step := Step.NONE
var accused: Node = null
var evidence: Array[Dictionary] = []    # {text, weight, picked}
var witnesses: Array[Dictionary] = []   # {npc, about, picked}
var cursor := 0
var pages: Array[String] = []           # What is said, one page at a time
var page := 0
var votes: Array[Dictionary] = []       # {name, guilty}
var guilty := false

var panel: PanelContainer
var title: Label
var body: Label
var options: VBoxContainer
var hint: Label


func setup(style: StyleBox, title_font: Font) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = PANEL_SIZE
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(PANEL_SIZE.x - 60.0, 0.0)
	body.add_theme_font_size_override("font_size", 19)
	box.add_child(body)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 6)
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(options)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	box.add_child(hint)


func _t(text: String, args := {}) -> String:
	return Lang.contract(tr(text).format(args))


func _n(person: String) -> String:
	return tr(person)


# ---------- Calling a hearing ----------

# The day the hearing would be held if called now: today if it's still before dusk
func day_if_called_now() -> int:
	var before_dusk := GameState.hour >= 6.0 and GameState.hour < HOUR - 0.5
	return GameState.day if before_dusk else GameState.day + 1


func _process(_delta: float) -> void:
	if step != Step.NONE or GameState.game_over or get_tree().paused:
		return
	var h: Dictionary = GameState.hearing
	if h.is_empty() or GameState.in_dialogue or GameState.reading:
		return
	if GameState.day < int(h["day"]) or (GameState.day == int(h["day"]) and GameState.hour < HOUR):
		return
	if GameState.hour < 6.0:
		return  # Wait for a proper evening
	_open(h["accused"])


func _open(accused_name: String) -> void:
	GameState.hearing = {}
	accused = null
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == accused_name:
			accused = npc
	if accused == null or not accused.is_alive():
		EventBus.dialogue_started.emit("Doctor", _t("The hearing against {name} will not take place.", {"name": _n(accused_name)}))
		return
	GameState.hearings_held += 1
	Playtest.count("hearings")
	Playtest.log_line("Hearing against %s" % accused_name)
	evidence = _collect_evidence()
	witnesses = _collect_witnesses()
	get_tree().paused = true
	panel.visible = true
	_go(Step.EVIDENCE)


# ---------- What the doctor can bring ----------

func _collect_evidence() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var who: String = accused.data.npc_name
	# What the doctor saw himself
	if GameState.faced_night >= 0 and GameState.faced_by == who:
		list.append({"text": _t("Night {night}: you saw {name}'s face in the dark, and it ran after you.", {"night": GameState.faced_night, "name": _n(who)}),
				"weight": 2.5, "own": true})
	for night in GameState.saw_hunting.get(who, []):
		if night != GameState.faced_night:
			list.append({"text": _t("Night {night}: you saw {name} sneaking through the dark streets.", {"night": night, "name": _n(who)}),
					"weight": 2.0, "own": true})
	# Statements that don't fit together (only those the doctor compared himself)
	for key: String in GameState.crosschecks:
		var parts := key.split("|")
		if parts[1] == who and GameState.crosschecks[key] == "conflict":
			list.append({"text": _t("Night {night}: {witness}'s account doesn't fit where {name} said they were.", {"night": parts[0], "witness": _n(parts[2]), "name": _n(who)}),
					"weight": 2.0})
	# Seen out at night, worse if it was by the house of someone attacked that night
	for key: String in GameState.reports:
		var night := int(key.get_slice("|", 0))
		var witness := key.get_slice("|", 1)
		for s in GameState.reports[key]:
			if s["kind"] != "person" or s["who"] != who:
				continue
			var victim := GameState.attack_at(night, s["place"])
			var args := {"night": night, "witness": _n(witness), "name": _n(who), "place": GameState.place_name(s["place"]),
					"time": GameState.format_time(s["hour"]), "victim": _n(victim)}
			if victim != "":
				list.append({"text": _t("Night {night}: {witness} saw {name} near {place} at {time}, the night {victim} was attacked.", args), "weight": 2.5})
			elif _late(s["hour"]):
				list.append({"text": _t("Night {night}: {witness} saw {name} out near {place} at {time}.", args), "weight": 1.0})
	# The exams
	var pale := 0
	for e in accused.exams:
		if e.get("look", "") in ["Pale", "Grey", "A little pale"] and not e.get("marks", false) and not e.get("old_marks", false):
			pale += 1
	if pale >= 2:
		list.append({"text": _t("{name} looks anemic, yet in {count} exams you never found a single bite.", {"name": _n(who), "count": pale}), "weight": 2.0})
	var trait_name: String = accused.data.clue_trait
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == accused or trait_name == "":
			continue
		var found: String = npc.body_trace if npc.examined else ""
		for e in npc.exams:
			if str(e.get("trace", "")).begins_with(trait_name):
				found = trait_name
		if found.begins_with(trait_name) and found != "":
			list.append({"text": _t("Traces of {trace} on {victim}'s clothes point to {name}.", {"trace": tr(trait_name), "victim": _n(npc.data.npc_name), "name": _n(who)}),
					"weight": 1.5})
	# Clues the doctor marked important in his casebook, about this person
	for entry: Dictionary in GameState.entries:
		if entry.get("mark", "") == "important" and who in entry["people"]:
			list.append({"text": "(!) " + String(entry["text"]), "weight": 1.5 if entry["kind"] == "evidence" else 1.0,
					"marked": true})
	# No duplicates; the doctor's marked clues first, then the strongest, no more than fits
	list.sort_custom(func(a, b):
		if a.get("marked", false) != b.get("marked", false):
			return a.get("marked", false)
		return a["weight"] > b["weight"])
	var seen := {}
	var unique: Array[Dictionary] = []
	for item in list:
		if unique.size() >= 8:
			break
		if not seen.has(item["text"]):
			seen[item["text"]] = true
			item["picked"] = false
			unique.append(item)
	return unique


func _late(hour: float) -> bool:
	return hour >= 22.0 or hour < 5.0


# People who saw the accused at night, as they told the doctor
func _collect_witnesses() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var who: String = accused.data.npc_name
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == accused or not npc.is_alive() or npc.data == null:
			continue
		var best := {}
		for key: String in GameState.reports:
			if key.get_slice("|", 1) != npc.data.npc_name:
				continue
			for s in GameState.reports[key]:
				if s["kind"] == "person" and s["who"] == who and (best.is_empty() or _late(s["hour"])):
					best = s.duplicate()
					best["night"] = int(key.get_slice("|", 0))
		if not best.is_empty():
			list.append({"npc": npc, "about": best, "picked": false})
	return list


# ---------- Steps ----------

func _go(new_step: Step) -> void:
	step = new_step
	cursor = 0
	match step:
		Step.EVIDENCE:
			title.text = _t("The hearing of {name}", {"name": _n(accused.data.npc_name)})
			body.text = tr("The town has gathered at the Town Hall. Choose the evidence you will present (up to 3). The town will want all three, and two witnesses.")
			if evidence.is_empty():
				body.text = tr("The town has gathered at the Town Hall. Your casebook holds nothing solid against them: you will have to rely on witnesses and your word.")
		Step.WITNESSES:
			body.text = tr("Who will you call to speak (up to 2)? Only those who trust you will stand up.")
			if witnesses.is_empty():
				body.text = tr("Nobody told you they saw the accused at night. There is no one to call.")
		Step.TESTIMONY:
			pages = _testimony()
			page = 0
		Step.VOTE:
			_count_votes()
		Step.VERDICT:
			pass
	_refresh()


func _refresh() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	match step:
		Step.EVIDENCE:
			for i in evidence.size():
				_option(("[x] " if evidence[i]["picked"] else "[  ] ") + evidence[i]["text"], i == cursor)
			_option(tr("Go on"), cursor == evidence.size())
			hint.text = tr("[W/S] Choose    [E] Mark / Go on")
		Step.WITNESSES:
			for i in witnesses.size():
				var w: Dictionary = witnesses[i]
				var s: Dictionary = w["about"]
				var line := _t("{witness}: saw {name} near {place} (night {night})", {"witness": _n(w["npc"].data.npc_name),
						"name": _n(accused.data.npc_name), "place": GameState.place_name(s["place"]), "night": s["night"]})
				_option(("[x] " if w["picked"] else "[  ] ") + line, i == cursor)
			_option(tr("Go on"), cursor == witnesses.size())
			hint.text = tr("[W/S] Choose    [E] Mark / Go on")
		Step.TESTIMONY:
			body.text = pages[page]
			hint.text = tr("[E] Continue")
		Step.VOTE:
			var lines := PackedStringArray()
			var yes := 0
			for v in votes:
				lines.append(_t("{name}: guilty", {"name": _n(v["name"])}) if v["guilty"] else _t("{name}: not guilty", {"name": _n(v["name"])}))
				if v["guilty"]:
					yes += 1
			body.text = tr("The town votes.") + "\n\n" + "\n".join(lines) + "\n\n" + \
					_t("{yes} of {total} say guilty.", {"yes": yes, "total": votes.size()})
			hint.text = tr("[E] Continue")
		Step.VERDICT:
			hint.text = tr("[E] Continue")


func _option(text: String, selected: bool) -> void:
	var label := Label.new()
	label.text = ("» " if selected else "   ") + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_SIZE.x - 60.0, 0.0)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(0.95, 0.8, 0.45) if selected else Color(0.85, 0.85, 0.85)
	options.add_child(label)


func _input(event: InputEvent) -> void:
	if step == Step.NONE:
		return
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("interact"):
		_press()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(by: int) -> void:
	var count := 0
	if step == Step.EVIDENCE:
		count = evidence.size() + 1
	elif step == Step.WITNESSES:
		count = witnesses.size() + 1
	if count > 0:
		cursor = posmod(cursor + by, count)
		_refresh()


func _picked(list: Array[Dictionary]) -> int:
	return list.filter(func(x): return x["picked"]).size()


func _press() -> void:
	match step:
		Step.EVIDENCE:
			if cursor < evidence.size():
				var item: Dictionary = evidence[cursor]
				if item["picked"] or _picked(evidence) < MAX_EVIDENCE:
					item["picked"] = not item["picked"]
				_refresh()
			else:
				_go(Step.WITNESSES)
		Step.WITNESSES:
			if cursor < witnesses.size():
				var w: Dictionary = witnesses[cursor]
				if w["picked"] or _picked(witnesses) < MAX_WITNESSES:
					w["picked"] = not w["picked"]
				_refresh()
			else:
				_go(Step.TESTIMONY)
		Step.TESTIMONY:
			page += 1
			if page >= pages.size():
				_go(Step.VOTE)
			else:
				_refresh()
		Step.VOTE:
			_verdict()
		Step.VERDICT:
			_close()


# ---------- What is said ----------

var case_weight := 0.0      # Evidence and testimony, before each voter's own view
var full_case := false      # Three pieces of evidence and two witnesses who spoke
var doctor_word := 0.0      # The part that is only the doctor's word (weighed by trust)


func _testimony() -> Array[String]:
	var said: Array[String] = []
	var who: String = accused.data.npc_name
	case_weight = 0.0
	doctor_word = 0.0
	var spoke := 0
	var shown := PackedStringArray()
	for item in evidence:
		if item["picked"]:
			shown.append("• " + item["text"])
			if item.get("own", false):
				doctor_word += item["weight"]
			else:
				case_weight += item["weight"]
	if shown.is_empty():
		said.append(tr("You stand before the town with nothing but your suspicion."))
	else:
		said.append(tr("You lay out your case:") + "\n\n" + "\n".join(shown))
	# Witnesses
	for w in witnesses:
		if not w["picked"]:
			continue
		var npc: Node = w["npc"]
		var s: Dictionary = w["about"]
		var args := {"witness": _n(npc.data.npc_name), "name": _n(who), "place": GameState.place_name(s["place"]),
				"time": GameState.format_time(s["hour"]), "night": s["night"]}
		if npc.is_servant and accused.is_vampire():
			if npc.affinity >= 75.0:
				# It made them lie. They trust the doctor more than they fear it.
				said.append(_t("{witness} stands, shaking: \"It made me lie to you, doctor. It's {name}. I saw them that night near {place}, and God forgive me, I kept quiet.\"", args))
				case_weight += 3.0
				spoke += 1
				GameState.learn("servants")
			else:
				said.append(_t("{witness} looks at {name} and goes pale: \"I... I don't remember anything, doctor. I must have been mistaken.\"", args))
				case_weight -= 1.0
		elif npc.affinity < 35.0 or npc.is_wary():
			said.append(_t("{witness} won't stand: \"I'll not speak up there for you, doctor.\"", args))
		else:
			var line := "{witness}: \"On the night of Day {night} I saw {name} near {place}, around {time}.\""
			if _late(s["hour"]):
				line = "{witness}: \"On the night of Day {night} I saw {name} near {place}, around {time}. At that hour, when decent folk are asleep.\""
			said.append(_t(line, args))
			case_weight += 1.5
			spoke += 1
	full_case = shown.size() >= MAX_EVIDENCE and spoke >= MAX_WITNESSES
	# The defence: its servants swear for it
	if accused.is_vampire():
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc.is_servant and npc.is_alive() and npc.affinity < 75.0:
				said.append(_t("{servant} stands up: \"{name} was with me all that night. I'd swear it before God.\"", {"servant": _n(npc.data.npc_name), "name": _n(who)}))
				case_weight -= 1.0
		said.append(_t("{name}: \"Doctor, you are tired and frightened. You see monsters in every shadow. I have nothing to hide.\"", {"name": _n(who)}))
	else:
		said.append(_t("{name}: \"I have lived here all my life. I'm no monster, and you all know it.\"", {"name": _n(who)}))
	return said


func _count_votes() -> void:
	votes.clear()
	var who: String = accused.data.npc_name
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == accused or not npc.is_alive() or npc.data == null:
			continue
		var vote := false
		if npc.is_servant and accused.is_vampire() and npc.affinity < 75.0:
			vote = false  # Bound by blood
		else:
			var trust: float = npc.affinity
			if not full_case and trust < DEEP_TRUST:
				votes.append({"name": npc.data.npc_name, "guilty": false})
				continue  # Not on so little
			var score := case_weight + doctor_word * clampf(trust / 60.0, 0.3, 1.3) + (trust - 50.0) / 20.0
			for s in npc.sightings:
				if s["kind"] == "person" and s["who"] == who and _late(s["hour"]):
					score += 1.0  # They saw it with their own eyes
			score += randf_range(-1.0, 1.0)
			vote = score >= GUILTY_SCORE
		votes.append({"name": npc.data.npc_name, "guilty": vote})
	var yes := votes.filter(func(v): return v["guilty"]).size()
	guilty = yes * 2 > votes.size()


func _verdict() -> void:
	step = Step.VERDICT
	var who: String = accused.data.npc_name
	var args := {"name": _n(who), "day": GameState.day}
	Playtest.note_accused(who)
	Playtest.log_line("Hearing verdict: %s %s" % [who, "guilty" if guilty else "not guilty"])
	if guilty and accused.is_vampire():
		title.text = tr("Guilty")
		body.text = _t("The town has found {name} guilty. They drag {name} to the cellar of the Town Hall and wait for the sun.", args)
	elif guilty:
		title.text = tr("Guilty")
		accused.jail()
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc.is_alive():
				npc.change_affinity(-10.0)
		body.text = _t("The town has found {name} guilty. They march {name} out through the town gate and bar it behind them. No one goes out there now, not since the wolf. Tonight, Pallbrook will sleep a little easier.", args)
		Playtest.count("innocent_condemned")
	elif accused.is_vampire():
		title.text = tr("Not guilty")
		body.text = _t("The town lets {name} go. As the crowd breaks up, {name} turns and looks straight at you.", args)
		GameState.recognize(GameState.day + 2)
	else:
		title.text = tr("Not guilty")
		accused.change_affinity(-30.0)
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc != accused and npc.is_alive():
				npc.change_affinity(-5.0)
		body.text = _t("The town lets {name} go. {name} won't forgive you soon, and people whisper as you pass.", args)
	if not guilty and not full_case:
		body.text += "\n\n" + tr("Three pieces of evidence and two witnesses: without a full case, few here will condemn anyone on your word.")
	if GameState.hearings_held >= GameState.MAX_HEARINGS and not (guilty and accused.is_vampire()):
		body.text += "\n\n" + tr("The town will not gather for you again.")
	_refresh()


func _close() -> void:
	var won: bool = guilty and accused.is_vampire()
	step = Step.NONE
	panel.visible = false
	get_tree().paused = false
	if won:
		var alive := 0
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc.is_alive() and not npc.is_servant and npc != accused:
				alive += 1
		EventBus.game_ended.emit(true, _t("You unmasked {name} on Day {day}. {alive} townspeople survived.",
				{"name": _n(accused.data.npc_name), "day": GameState.day, "alive": alive}))
