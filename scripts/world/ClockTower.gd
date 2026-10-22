extends Node

# The town hall clock: turns its hands to match the game's hour.
# The hands are separate nodes inside town.glb, pivoting on the clock's centre;
# they face the square (+Z), so a negative turn around Z is clockwise.

@export var hour_hand := "Clock_Hour"
@export var minute_hand := "Clock_Minute"

var hour_node: Node3D
var minute_node: Node3D


func _ready() -> void:
	# town.glb may finish loading after us
	await get_tree().process_frame
	var scene := get_tree().current_scene
	hour_node = scene.find_child(hour_hand, true, false) as Node3D
	minute_node = scene.find_child(minute_hand, true, false) as Node3D
	if hour_node == null or minute_node == null:
		push_warning("ClockTower: clock hands not found in the scene")


func _process(_delta: float) -> void:
	if hour_node == null or minute_node == null:
		return
	var h := fmod(GameState.hour, 12.0)            # Past midnight the hour can run past 24
	hour_node.rotation.z = -TAU * h / 12.0
	minute_node.rotation.z = -TAU * fmod(GameState.hour, 1.0)
