class_name Gathering
extends Node3D

# Free ingredients in the world, beyond the bridge (see Items): willow bark on the riverbank,
# thyme and wormwood in the woods. Once a day each, by daylight, half an hour of the doctor's
# time. Gideon sells most of the same things, dearer; gathering trades coins for hours.

const SPOTS := [
	{"key": "willow", "at": Vector3(-16.4, 0.0, -15.5), "gives": {"willow": 2},
			"text": "Half an hour on the riverbank with a knife: two strips of willow bark."},
	{"key": "herbs", "at": Vector3(-21.0, 0.0, -17.5), "gives": {"thyme": 1, "wormwood": 1},
			"text": "Half an hour among the trees: a bunch of wild thyme and a handful of wormwood."},
]
const USE_RANGE := 1.2
const SEEN_RANGE := 9.0   # The icon shows faintly from here, so the spots can be found
const HOURS := 0.5
const ICON := preload("res://assets/ui/icon_examine.png")

var prompts: Array[Sprite3D] = []
var ground: Array[Vector3] = []
var near_index := -1


func _ready() -> void:
	_place.call_deferred()


func _place() -> void:
	await get_tree().physics_frame  # The terrain's collider must be there for the ground check
	for spot: Dictionary in SPOTS:
		var at: Vector3 = spot["at"]
		var query := PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 5.0, 0.0), at - Vector3(0.0, 5.0, 0.0))
		var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
		var base: Vector3 = at if hit.is_empty() else hit["position"]
		ground.append(base)
		var prompt := Sprite3D.new()
		prompt.texture = ICON
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.pixel_size = 0.006
		prompt.visible = false
		add_child(prompt)
		prompt.global_position = base + Vector3(0.0, 1.2, 0.0)
		prompts.append(prompt)


func _gathered_today(i: int) -> bool:
	return int(GameState.gathered.get(SPOTS[i]["key"], -1)) == GameState.day


func _process(_delta: float) -> void:
	near_index = -1
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for i in prompts.size():
		var prompt := prompts[i]
		if player == null or GameState.is_night or _gathered_today(i):
			prompt.visible = false
			continue
		var gap := player.global_position - ground[i]
		var distance := Vector2(gap.x, gap.z).length()
		prompt.visible = distance < SEEN_RANGE and not GameState.in_dialogue and not GameState.reading
		var close := distance < USE_RANGE and absf(gap.y) < 2.5
		prompt.modulate.a = 1.0 if close else 0.45
		if close and prompt.visible:
			near_index = i


func _unhandled_input(event: InputEvent) -> void:
	if near_index < 0 or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var spot: Dictionary = SPOTS[near_index]
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle == null:
		return
	GameState.gathered[spot["key"]] = GameState.day
	var gives: Dictionary = spot["gives"]
	for id: String in gives:
		GameState.add_item(id, gives[id])
	Playtest.count("gathered_" + String(spot["key"]))
	cycle.pass_hours(HOURS, tr(spot["text"]))
