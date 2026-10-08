extends CharacterBody3D

@export var speed := 5.0

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Rotate input 45° so "up" matches the isometric camera's screen direction
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, deg_to_rad(45))

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
