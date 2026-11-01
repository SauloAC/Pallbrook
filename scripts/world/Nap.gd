class_name Nap
extends Node3D

# An afternoon nap in the clinic bed (see the design doc, "Cochilo à tarde"): two hours of
# daylight traded for an hour more on his feet tonight. Once a day, starting between 1 and 4 PM.
# It works on the same fatigue debt as a collapse: after a night on the floor, a nap pays one
# hour of it back instead. The bed at night is still SleepSpot's.

const BED_AT := Vector3(11.3, 0.0, 4.6)     # Beside the clinic bed (same spot as the night's)
const USE_RANGE := 0.9
const HOURS := 2.0
const FROM := 13.0
const LAST_START := 16.0
const GAIN := 1.0           # Hours of fatigue debt it takes off
const MOST_RESTED := -1.0   # A nap can bank one hour at most
const ICON := preload("res://assets/ui/icon_sleep.png")

var prompt: Sprite3D
var napped_day := -1


func _ready() -> void:
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	add_child(prompt)
	prompt.global_position = BED_AT + Vector3(0.0, 1.8, 0.0)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - BED_AT
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	prompt.visible = near and not GameState.is_night and not GameState.in_dialogue and not GameState.reading \
			and not GameState.near_mural


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if napped_day == GameState.day:
		EventBus.dialogue_started.emit("Bed", tr("You already slept this afternoon. Any more and you'd lose the whole day."))
		return
	if GameState.hour < FROM:
		EventBus.dialogue_started.emit("Bed", tr("Too early for a nap. There is work to do; come back after lunch."))
		return
	if GameState.hour > LAST_START:
		EventBus.dialogue_started.emit("Bed", tr("Too late for a nap. You'd sleep right through the dusk."))
		return
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle == null:
		return
	napped_day = GameState.day
	var aching := GameState.fatigue_debt > 0.0
	GameState.fatigue_debt = maxf(GameState.fatigue_debt - GAIN, MOST_RESTED)
	Playtest.count("afternoon_nap")
	var note := tr("Two hours of sleep in the afternoon light. It eased last night's aches: tonight you will tire an hour later than you feared.") if aching \
			else tr("Two hours of sleep in the afternoon light. Tonight you will last an hour longer before exhaustion sets in.")
	cycle.pass_hours(HOURS, note)
