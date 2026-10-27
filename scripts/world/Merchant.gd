class_name Merchant
extends Node3D

# Gideon's stall, on the road in front of the cemetery gate, beyond the bridge (see the design
# doc, "O comerciante além da ponte"). He came from the town across the hills that the wolf
# attacked, and by these graves he feels strangely safe (the vampire can't cross running water;
# he doesn't know that). He sells the ingredients for the iron tonic, mornings only, and every
# day he tells a little more of what happened over there.

const NAME := "Gideon"
const OPEN_FROM := 7.0
const OPEN_UNTIL := 12.0
const STALL_AT := Vector3(-24.5, 0.0, -12.9)   # On the road, west of the cemetery gate
const USE_AT := Vector3(-24.5, 0.0, -11.9)     # Where the doctor stands to buy
const USE_RANGE := 1.4
const ICON := preload("res://assets/ui/icon_talk.png")
const WOOD := Color(0.36, 0.24, 0.14)
const CLOTH_A := Color(0.52, 0.16, 0.12)
const CLOTH_B := Color(0.86, 0.8, 0.66)
# A new piece of his story on each day the doctor stops by, then the last one repeats
const STORY := [
	"Iron salts, wormwood, a good red wine: everything a doctor needs for his tonics. I came from the town over the hills, past the river. I left when the wolf came.",
	"A grey wolf, big as a calf. It took the shepherd first, then the miller's boy. It never touched the sheep, doctor. Not one.",
	"We barred the gates. It came anyway: always at night, always quiet. In the morning, only the bodies, pale as candles.",
	"Strange thing: it always stopped at the brook. Never once crossed running water. Wolves swim, doctor. I've seen them.",
	"Why do I sell here, by the graves? I can't say. Nothing walks here at night but the wind. I sleep like a child.",
	"Your predecessor bought from me too. The last time he looked starved, doctor. Said he couldn't keep anything down.",
	"Fresh stock today. Mind yourself on the way back across the bridge.",
]

var prompt: Sprite3D
var figure: CharacterVisual
var panel: CanvasLayer
var body_label: Label
var hint_label: Label
var is_open_ui := false
var amount := 1
var story_text := ""
var opened_frame := -1


func _ready() -> void:
	_build_stall.call_deferred()
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	add_child(prompt)
	_build_panel()


func _build_stall() -> void:
	await get_tree().physics_frame  # The road's collider must be there for the ground check
	var base := _ground(STALL_AT)
	# Table, four posts and a striped awning, a few crates and sacks
	_box(base + Vector3(0.0, 0.45, 0.0), Vector3(1.7, 0.08, 0.8), WOOD)
	_box(base + Vector3(0.0, 0.22, 0.0), Vector3(1.6, 0.44, 0.7), WOOD.darkened(0.25))
	for corner in [Vector2(-0.8, -0.35), Vector2(0.8, -0.35), Vector2(-0.8, 0.35), Vector2(0.8, 0.35)]:
		_box(base + Vector3(corner.x, 1.05, corner.y), Vector3(0.07, 2.1, 0.07), WOOD)
	for i in 5:
		_box(base + Vector3(-0.76 + i * 0.38, 2.12, 0.0), Vector3(0.38, 0.05, 1.0), CLOTH_A if i % 2 == 0 else CLOTH_B)
	_box(base + Vector3(-0.45, 0.6, 0.05), Vector3(0.3, 0.22, 0.3), Color(0.5, 0.36, 0.2))
	_box(base + Vector3(0.1, 0.56, -0.05), Vector3(0.22, 0.14, 0.22), Color(0.3, 0.42, 0.24))   # Herbs
	_box(base + Vector3(0.5, 0.58, 0.1), Vector3(0.12, 0.18, 0.12), Color(0.35, 0.08, 0.1))      # Wine
	_box(base + Vector3(1.15, 0.25, 0.1), Vector3(0.45, 0.5, 0.45), Color(0.5, 0.36, 0.2))
	_box(base + Vector3(-1.15, 0.2, -0.1), Vector3(0.4, 0.4, 0.35), Color(0.62, 0.52, 0.36))    # A sack
	# Gideon behind it, facing the road
	figure = CharacterVisual.new()
	add_child(figure)
	figure.global_position = base + Vector3(0.0, 0.0, -0.75)
	if not figure.setup(NAME):
		figure.queue_free()
		figure = null
	prompt.global_position = base + Vector3(0.0, 2.6, 0.2)


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	piece.material_override = mat
	add_child(piece)
	piece.global_position = at


func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 3.0, 0.0), at - Vector3(0.0, 3.0, 0.0))
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
	return at if hit.is_empty() else hit["position"]


func is_open() -> bool:
	return not GameState.is_night and GameState.hour >= OPEN_FROM and GameState.hour < OPEN_UNTIL


func _process(delta: float) -> void:
	var here := is_open()
	if figure:
		figure.visible = here
		if here:
			figure.animate(Vector3.ZERO, delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - USE_AT
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	prompt.visible = near and not GameState.in_dialogue and not GameState.reading and not is_open_ui


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if not is_open():
		EventBus.dialogue_started.emit("Doctor", tr("The stall is covered with a cloth. A note pinned to it: \"Mornings, from 7 to noon.\""))
		return
	_open_ui()


# ---------- Talking and buying ----------

func _build_panel() -> void:
	panel = CanvasLayer.new()
	panel.layer = 20
	panel.visible = false
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)
	var title := Label.new()
	title.text = tr(NAME)
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	body_label = Label.new()
	body_label.add_theme_font_size_override("font_size", 21)
	body_label.custom_minimum_size = Vector2(640, 0)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)


func _open_ui() -> void:
	# The first visit of the day brings the next piece of his story (and it goes in the casebook)
	var index := int(GameState.merchant.get("told", 0))
	if int(GameState.merchant.get("day", -1)) != GameState.day:
		GameState.merchant["day"] = GameState.day
		index = mini(index, STORY.size() - 1)
		GameState.merchant["told"] = index + 1
		if index < STORY.size() - 1:
			GameState.add_clue(Lang.contract(tr("Day {day} · {name} said: \"{text}\"").format({"day": GameState.day, "name": tr(NAME), "text": tr(STORY[index])})))
	else:
		index = maxi(index - 1, 0)
	story_text = tr(STORY[mini(index, STORY.size() - 1)])
	amount = 1
	is_open_ui = true
	opened_frame = Engine.get_process_frames()
	GameState.in_dialogue = true
	panel.visible = true
	_refresh()


func _most() -> int:
	return floori(float(GameState.coins) / GameState.TONIC_PRICE)


func _refresh() -> void:
	var offer := ""
	if _most() < 1:
		offer = tr("Ingredients for one iron tonic: {price} coins. You have {coins}.").format({"price": GameState.TONIC_PRICE, "coins": GameState.coins})
		hint_label.text = tr("[Esc] Leave")
	else:
		amount = clampi(amount, 1, _most())
		offer = tr("Ingredients for iron tonics:  ◀ {amount} ▶\nCost: {cost} coins (you have {coins}). Prepare them at the clinic cabinet.").format(
				{"amount": amount, "cost": amount * GameState.TONIC_PRICE, "coins": GameState.coins})
		hint_label.text = tr("[A/D] Quantity    [E] Buy    [Esc] Leave")
	body_label.text = "\"" + story_text + "\"\n\n" + offer


func _close_ui() -> void:
	is_open_ui = false
	panel.visible = false
	GameState.in_dialogue = false


func _input(event: InputEvent) -> void:
	if not is_open_ui or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		amount = maxi(amount - 1, 1)
		Audio.play("click", -10.0)
		_refresh()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		amount = mini(amount + 1, maxi(_most(), 1))
		Audio.play("click", -10.0)
		_refresh()
	elif event.is_action_pressed("interact"):
		if _most() >= 1 and GameState.buy_ingredients(amount):
			_close_ui()
			EventBus.dialogue_started.emit(NAME, tr("There you are: enough for {amount}. Steep them overnight, doctor, or they're worth nothing.").format({"amount": amount}))
		else:
			_close_ui()
	elif event.is_action_pressed("ui_cancel"):
		_close_ui()
	else:
		return
	get_viewport().set_input_as_handled()
