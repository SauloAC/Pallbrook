extends Node3D

# The painted front door of a 2D building (made by art_source/tools/b2d/door.py). While anyone stands in
# the doorway, its leaf folds toward the hinge, the way the Cainos door animations draw an opening door,
# and shows the dark opening behind; when the doorway is empty again it swings shut. When closed, both
# are hidden and the door painted on the facade shows as drawn.

const OPEN_WIDTH := 0.14     # how much of the leaf still shows, seen edge-on, when fully open
const SWING_TIME := 0.18
const CLOSE_DELAY := 0.35    # someone just walking through doesn't leave it flapping

@onready var leaf: Node3D = $Leaf
@onready var opening: Node3D = $Opening
@onready var doorway: Area3D = $Doorway

var people: Array[Node3D] = []
var tween: Tween


func _ready() -> void:
	leaf.visible = false
	opening.visible = false
	doorway.body_entered.connect(_on_entered)
	doorway.body_exited.connect(_on_exited)


func _on_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not people.has(body):
		people.append(body)
		_swing(true)


func _on_exited(body: Node3D) -> void:
	people.erase(body)
	if people.is_empty():
		_swing(false)


func _swing(open: bool) -> void:
	if tween:
		tween.kill()
	leaf.visible = true
	opening.visible = true
	tween = create_tween()
	if open:
		tween.tween_property(leaf, "scale:x", OPEN_WIDTH, maxf(0.01, SWING_TIME * (leaf.scale.x - OPEN_WIDTH) / (1.0 - OPEN_WIDTH)))
	else:
		tween.tween_interval(CLOSE_DELAY)
		tween.tween_property(leaf, "scale:x", 1.0, maxf(0.01, SWING_TIME * (1.0 - leaf.scale.x) / (1.0 - OPEN_WIDTH)))
		tween.tween_callback(_shut)


func _shut() -> void:
	leaf.visible = false
	opening.visible = false
