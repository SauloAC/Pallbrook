extends Camera3D

@export var target: Node3D
@export var smoothing := 5.0

var offset: Vector3

func _ready() -> void:
	if target:
		# Keeps the distance the camera already has from the player
		offset = global_position - target.global_position

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + offset
	# Smooth follow: higher smoothing = tighter, lower = floatier
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
