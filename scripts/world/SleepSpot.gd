extends Area3D

# Inside the clinic: by day, order tonic ingredients at the supply cabinet;
# at night, sleep in the bed. The spot moves to whichever one is in use.

const ICON_SLEEP := preload("res://assets/ui/icon_sleep.png")
const ICON_CABINET := preload("res://assets/ui/icon_examine.png")

@export var bed_position := Vector3(-1.2, -1.5, -0.4)     # Relative to the Clinica node
const SLEEP_FROM_HOUR := 22.0  # The first hours of the night are for watching the streets

@export var cabinet_position := Vector3(1.4, -1.5, -1.2)

@onready var prompt: Sprite3D = $Prompt
var player_inside := false

# The cabinet's order sheet: how many tonics to order at once
var picker: CanvasLayer
var picker_body: Label
var picking := false
var amount := 1
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
	picker_body = Label.new()
	picker_body.add_theme_font_size_override("font_size", 22)
	picker_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker_body.custom_minimum_size = Vector2(560, 0)
	picker_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(picker_body)
	var hint := Label.new()
	hint.text = tr("[A/D] Quantity    [E] Order    [Esc] Cancel")
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _most() -> int:
	return floori(float(GameState.coins) / GameState.TONIC_PRICE)


func _refresh_picker() -> void:
	picker_body.text = tr("Iron tonics to order:  ◀ {amount} ▶\nCost: {cost} coins (you have {coins})\nReady tomorrow morning.").format(
			{"amount": amount, "cost": amount * GameState.TONIC_PRICE, "coins": GameState.coins})


func _open_picker() -> void:
	picking = true
	amount = 1
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
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		amount = maxi(amount - 1, 1)
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		amount = mini(amount + 1, _most())
		Audio.play("click", -10.0)
		_refresh_picker()
	elif event.is_action_pressed("interact"):
		_close_picker()
		GameState.order_tonic(amount)
		var text := tr("You ordered the ingredients for one iron tonic ({price} coins). It will be ready tomorrow morning.\nCoins left: {coins} · Tonics ordered: {ordered}") if amount == 1 \
				else tr("You ordered the ingredients for {amount} iron tonics ({price} coins). They will be ready tomorrow morning.\nCoins left: {coins} · Tonics ordered: {ordered}")
		EventBus.dialogue_started.emit("Supply cabinet", text.format({"amount": amount, "price": GameState.TONIC_PRICE * amount, "coins": GameState.coins, "ordered": GameState.tonics_ordered}))
	elif event.is_action_pressed("ui_cancel"):
		_close_picker()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var target := bed_position if GameState.is_night else cabinet_position
	if position != target:
		position = target  # Overlap signals catch up on the next physics frame
	prompt.visible = player_inside and not GameState.in_dialogue
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
	# Day: choose how many tonics to order
	if _most() >= 1:
		_open_picker()
		return
	var text := tr("Iron salts, herbs, a little wine... one tonic costs {price} coins, and you have {coins}.").format({"price": GameState.TONIC_PRICE, "coins": GameState.coins})
	EventBus.dialogue_started.emit("Supply cabinet", text)
