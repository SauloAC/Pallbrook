extends Area3D

# Inside the clinic: by day, the supply cabinet: what's in stock, and remedies to prepare from it
# (see Items: the tonic needs the library's recipe; ingredients from Gideon, the river, the woods);
# at night, sleep in the bed. The spot moves to whichever one is in use.

const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_CABINET := preload("res://assets/ui/icon_examine.png")

@export var bed_position := Vector3(-1.2, -1.5, -0.4)     # Relative to the Clinica node
const SLEEP_FROM_HOUR := 22.0  # The first hours of the night are for watching the streets

@export var cabinet_position := Vector3(1.4, -1.5, -1.2)

@onready var prompt: Sprite3D = $Prompt
var player_inside := false

# The cabinet: stock on the left, recipes on the right
var picker: CanvasLayer
var picker_body: Label
var stock_label: Label
var picking := false
var amount := 1
var selected := 0
var opened_frame := -1

func _ready() -> void:
	body_entered.connect(func(body): if body.name == "Jogador": player_inside = true)
	body_exited.connect(func(body): if body.name == "Jogador": player_inside = false)
	position = bed_position if GameState.is_night else cabinet_position
	_build_picker()


func _build_picker() -> void:
	picker = CanvasLayer.new()
	picker.layer = 20
	picker.visible = false
	add_child(picker)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("Supply cabinet")
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	box.add_child(columns)
	stock_label = Label.new()
	stock_label.add_theme_font_size_override("font_size", 18)
	stock_label.custom_minimum_size = Vector2(300, 0)
	columns.add_child(stock_label)
	picker_body = Label.new()
	picker_body.add_theme_font_size_override("font_size", 19)
	picker_body.custom_minimum_size = Vector2(560, 0)
	picker_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columns.add_child(picker_body)
	var hint := Label.new()
	hint.text = tr("[W/S] Remedy    [A/D] Batches    [E] Prepare    [Esc] Close")
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


const LATEST_BREW := 17.0  # The work must end before dusk


func _remedy() -> String:
	return Items.REMEDY_ORDER[selected]


func _refresh_picker() -> void:
	# Left: what's on the shelves
	var stock := PackedStringArray([tr("On the shelves")])
	for id: String in Items.REMEDY_ORDER:
		var have := GameState.item_count(id) + (GameState.tonics_ordered if id == "tonic" else 0)
		if have > 0:
			stock.append("  %s: %d%s" % [tr(Items.item_name(id)), GameState.item_count(id),
					(" " + tr("(+{n} steeping)").format({"n": GameState.tonics_ordered})) if id == "tonic" and GameState.tonics_ordered > 0 else ""])
	stock.append("")
	stock.append(tr("Ingredients"))
	var any := false
	for id: String in Items.INGREDIENTS:
		if GameState.item_count(id) > 0:
			stock.append("  %s: %d" % [tr(Items.item_name(id)), GameState.item_count(id)])
			any = true
	if not any:
		stock.append("  " + tr("none"))
	stock_label.text = "\n".join(stock)
	# Right: the recipes, the chosen one in detail
	var lines := PackedStringArray()
	for i in Items.REMEDY_ORDER.size():
		var id: String = Items.REMEDY_ORDER[i]
		var known: bool = not Items.REMEDIES[id].get("learned", false) or GameState.knows_tonic
		var label := tr(Items.item_name(id)) if known else tr(Items.item_name(id)) + " " + tr("(recipe unknown: the library)")
		lines.append(("» " if i == selected else "   ") + label)
	var recipe: Dictionary = Items.REMEDIES[_remedy()]
	var can := GameState.batches_possible(_remedy())
	amount = clampi(amount, 1, maxi(can, 1))
	lines.append("")
	lines.append(tr("Needs: {list}").format({"list": Items.needs_text(_remedy())}))
	var time := tr("One hour") if recipe["hours"] >= 1.0 else tr("Half an hour")
	if recipe.get("overnight", false):
		lines.append(tr("{time} of work, then it steeps overnight: ready tomorrow morning.").format({"time": time}))
	else:
		lines.append(tr("{time} of work. Each batch makes {n}.").format({"time": time, "n": recipe["makes"]}))
	if can < 1:
		lines.append(tr("Not enough ingredients."))
	else:
		lines.append(tr("Batches:  ◀ {amount} ▶  (ingredients for {can})").format({"amount": amount, "can": can}))
	picker_body.text = "\n".join(lines)


func _open_picker() -> void:
	picking = true
	amount = 1
	selected = clampi(selected, 0, Items.REMEDY_ORDER.size() - 1)
	opened_frame = Engine.get_process_frames()
	GameState.in_dialogue = true  # The doctor stands still and other prompts hide
	_refresh_picker()
	picker.visible = true


func _close_picker() -> void:
	picking = false
	picker.visible = false
	GameState.in_dialogue = false


func _input(event: InputEvent) -> void:
	if not picking or Engine.get_process_frames() == opened_frame:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		selected = wrapi(selected - 1, 0, Items.REMEDY_ORDER.size())
		amount = 1
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		selected = wrapi(selected + 1, 0, Items.REMEDY_ORDER.size())
		amount = 1
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		amount = maxi(amount - 1, 1)
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		amount = mini(amount + 1, maxi(GameState.batches_possible(_remedy()), 1))
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("interact"):
		var id := _remedy()
		var recipe: Dictionary = Items.REMEDIES[id]
		if recipe.get("learned", false) and not GameState.knows_tonic:
			Audio.play("click", -10.0)
			get_viewport().set_input_as_handled()
			return  # Not known yet: the line says where to learn it
		if GameState.hour + float(recipe["hours"]) > LATEST_BREW:
			_close_picker()
			EventBus.dialogue_started.emit("Supply cabinet", tr("Too late to start working today. Come back in the morning."))
			get_viewport().set_input_as_handled()
			return
		var batches := amount
		if not GameState.make(id, batches):
			Audio.play("click", -10.0)
			get_viewport().set_input_as_handled()
			return
		_close_picker()
		var cycle = get_tree().get_first_node_in_group("day_night")
		var made: int = recipe["makes"] * batches
		var note := tr("An hour of grinding, weighing and steeping. {amount} iron tonics will be ready tomorrow morning.").format({"amount": made}) \
				if recipe.get("overnight", false) else tr("Half an hour at the cabinet: {amount} × {item}.").format({"amount": made, "item": tr(Items.item_name(id))})
		if cycle:
			cycle.pass_hours(float(recipe["hours"]), note)
	elif event.is_action_pressed("ui_cancel"):
		_close_picker()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var target := bed_position if GameState.is_night else cabinet_position
	if position != target:
		position = target  # Overlap signals catch up on the next physics frame
	prompt.visible = player_inside and not GameState.in_dialogue and not GameState.near_mural
	prompt.texture = ICON_SLEEP if GameState.is_night else ICON_CABINET

func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if GameState.is_night:
		if GameState.chased:
			EventBus.dialogue_started.emit("Bed", tr("Not with that thing outside. Get somewhere safe first."))
			return
		if GameState.hour >= 12.0 and GameState.hour < SLEEP_FROM_HOUR:
			EventBus.dialogue_started.emit("Bed", tr("Too early to sleep. The night is when things happen."))
			return
		EventBus.player_slept.emit()
		return
	# Day: the cabinet (stock, and remedies to prepare)
	_open_picker()
