extends Camera3D

@export var target: Node3D
@export var smoothing := 5.0

var offset: Vector3

func _ready() -> void:
	# The camera moves itself every frame, so it doesn't need physics interpolation
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target:
		# Keeps the distance the camera already has from the player
		offset = global_position - target.global_position

func _process(delta: float) -> void:
	if target == null:
		return
	# Follow the smoothed (in-between) position of the player, not the raw physics one
	var target_pos := target.get_global_transform_interpolated().origin
	var desired := target_pos + offset
	# Smooth follow: higher smoothing = tighter, lower = floatier
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
