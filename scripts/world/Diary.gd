class_name Diary
extends Node

# The old doctor's diary (see the design doc and the "Diário" draft).
# Sheet 1 is whole and the A piece of every torn sheet is in the clinic desk from Day 1.
# The B and C pieces are hidden around town, each in one of two or three places drawn per run,
# and the last page lies whole among the graves beyond the bridge. The doctor picks them up
# (E) and fits them back on their sheet in the casebook; a whole sheet teaches him a rule.

const TEXT := preload("res://scripts/data/DiaryText.gd")
const NPC_SCRIPT := preload("res://scripts/npc/NPC.gd")
const PIECE := preload("res://scripts/world/DiaryPiece.gd")
const HOUSES := ["Casa1", "CasaSophia", "CasaSarah", "CasaHugo"]
# Places with no location marker
const SPOTS := {"#bridge": Vector3(-7.6, 0.0, -13.6), "#cemetery": Vector3(-19.5, 0.0, -4.0)}
const LAST_PAGE_NAMES_THE_VAMPIRE := 0.6  # How often the old doctor guessed right
# The pieces turn up a few at a time: sheet -> first day its pieces can be found
const REVEAL := {2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 5}


func setup(vampire_name: String) -> void:
	var state := {"spots": {}, "found": {}, "placed": {}, "spawned": {}, "last_name": vampire_name}
	# Whom the old doctor named on his last page: usually right, not always
	if randf() > LAST_PAGE_NAMES_THE_VAMPIRE:
		var others := []
		for npc in get_tree().get_nodes_in_group("npcs"):
			if npc.data and npc.data.npc_name != vampire_name:
				others.append(npc.data.npc_name)
		if not others.is_empty():
			state["last_name"] = others.pick_random()
	for sheet: Dictionary in TEXT.PAGES:
		var id := int(sheet["id"])
		if sheet.get("whole", false) and not sheet.get("hidden", false):
			state["placed"]["%dW" % id] = true  # Sheet 1: in the desk, whole
		elif not sheet.get("whole", false):
			state["placed"]["%dA" % id] = true  # Every A piece is in the desk too
		for letter: String in sheet.get("places", {}):
			var options: Array = sheet["places"][letter]
			var place: String = options.pick_random()
			if place == "#house":
				place = HOUSES.pick_random()
			state["spots"]["%d%s" % [id, letter]] = place
	GameState.diary = state
	EventBus.phase_changed.connect(_on_phase_changed)  # Each morning a few more turn up
	_spawn_pieces.call_deferred()


func _on_phase_changed(is_night: bool) -> void:
	if not is_night:
		_spawn_pieces()


func _spawn_pieces() -> void:
	await get_tree().physics_frame  # The town's colliders must be in place for the ground check
	var used := {}  # Pieces already put in each place, so they don't pile up
	for piece: String in GameState.diary["spots"]:
		var place: String = GameState.diary["spots"][piece]
		var index: int = used.get(place, 0)
		used[place] = index + 1
		if GameState.diary["spawned"].has(piece) or GameState.day < int(REVEAL.get(int(piece.left(-1)), 1)):
			continue
		GameState.diary["spawned"][piece] = true
		var node := PIECE.new()
		node.piece = piece
		add_child(node)
		node.global_position = _ground(_spot(place, index))


func _spot(place: String, index: int) -> Vector3:
	if SPOTS.has(place):
		return SPOTS[place] + Vector3(0.7 * index, 0.0, 0.0)
	var marker := GameState.place_position(place)
	var slots: Dictionary = NPC_SCRIPT.INTERIOR_SLOTS
	if slots.has(place):
		var list: Array = slots[place]
		return marker + list[(index * 3 + 2) % list.size()] + Vector3(0.45, 0.0, 0.2)  # Beside where people stand
	return marker + Vector3(2.0 - 0.8 * index, 0.0, 1.6)  # The square: by the well


# Down onto whatever floor is under the spot (below any upper floor)
func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 1.4, 0.0), at - Vector3(0.0, 3.0, 0.0))
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return at + Vector3(0.0, 0.03, 0.0)
	return hit["position"] + Vector3(0.0, 0.03, 0.0)


# ---------- Reading the sheets (used by the casebook) ----------

static func pages() -> Array:
	return TEXT.PAGES


static func page(id: int) -> Dictionary:
	for p: Dictionary in TEXT.PAGES:
		if int(p["id"]) == id:
			return p
	return {}


static func _lang(table: Dictionary) -> Variant:
	return table.get(Lang.locale, table.get("en"))


static func title(p: Dictionary) -> String:
	return _lang(p["title"])


static func learned(p: Dictionary) -> String:
	return _lang(p.get("learned", {"en": ""}))


static func lines(p: Dictionary) -> Array:
	return _lang(p["lines"])


static func whole_text(p: Dictionary) -> String:
	var text: String = _lang(p["text"])
	return text.replace("{name}", TranslationServer.translate(GameState.diary.get("last_name", "")))


static func is_placed(piece: String) -> bool:
	return GameState.diary.get("placed", {}).has(piece)


static func is_found(piece: String) -> bool:
	return GameState.diary.get("found", {}).has(piece)


# A whole sheet, or a torn one with its three pieces back together
static func is_complete(p: Dictionary) -> bool:
	var id := int(p["id"])
	if p.get("whole", false):
		return is_placed("%dW" % id)
	return is_placed("%dA" % id) and is_placed("%dB" % id) and is_placed("%dC" % id)


# What one piece shows on its own: the halves of lines that fall inside its tear
static func piece_text(p: Dictionary, letter: String) -> String:
	var parts := PackedStringArray()
	var layout: Array = p.get("layout", [])
	var text := lines(p) if p.has("lines") else []
	for i in layout.size():
		var halves: Array = text[i]
		if layout[i][0] == letter:
			parts.append(halves[0] + ("" if layout[i][1] == letter else "…"))
		elif layout[i][1] == letter:
			parts.append("…" + halves[1])
	return "\n".join(parts)


# Where a piece was found, in words
static func place_words(place: String) -> String:
	match place:
		"#bridge":
			return TranslationServer.translate("the bridge")
		"#cemetery":
			return TranslationServer.translate("the graves beyond the bridge")
	return GameState.place_name(place)
