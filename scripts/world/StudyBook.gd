class_name StudyBook
extends Node3D

# A heavy materia medica on the library lectern. Reading it takes three hours of daylight and
# teaches the doctor to prepare the iron tonic himself (see "A cadeia do tônico").

const AT := Vector3(14.5, 0.0, 19.4)        # On the desk by the east wall, out of everyone's way
const USE_RANGE := 1.0
const READ_HOURS := 3.0
const LATEST_START := 15.0                   # Three hours must fit before dusk
const ICON := preload("res://assets/ui/icon_examine.png")

var prompt: Sprite3D


func _ready() -> void:
	prompt = Sprite3D.new()
	prompt.texture = ICON
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.pixel_size = 0.008
	prompt.visible = false
	add_child(prompt)
	prompt.global_position = AT + Vector3(0.0, 2.2, 0.0)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if player:
		var gap := player.global_position - AT
		near = Vector2(gap.x, gap.z).length() < USE_RANGE and absf(gap.y) < 2.5
	prompt.visible = near and not GameState.in_dialogue and not GameState.reading


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if GameState.knows_tonic:
		EventBus.dialogue_started.emit("Doctor", tr("The materia medica. You already know the iron tonic by heart."))
		return
	if GameState.is_night or GameState.hour >= LATEST_START:
		EventBus.dialogue_started.emit("Doctor", tr("A thick materia medica, with a chapter on iron tonics. It would take about three hours of good light to learn it. Come back earlier in the day."))
		return
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle == null:
		return
	Playtest.count("tonic_recipe_learned")
	cycle.pass_hours(READ_HOURS, tr("Three hours with the materia medica. You can now prepare the iron tonic at the clinic cabinet: iron salts, wormwood and red wine, steeped overnight. The merchant beyond the bridge sells the ingredients."),
			func(): GameState.knows_tonic = true)
