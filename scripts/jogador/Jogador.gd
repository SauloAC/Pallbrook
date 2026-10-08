extends CharacterBody3D

@export var velocidade := 5.0

func _physics_process(delta: float) -> void:
	var entrada := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Gira a entrada 45° para "cima" ser a diagonal da câmera isométrica
	var direcao := Vector3(entrada.x, 0, entrada.y).rotated(Vector3.UP, deg_to_rad(45))

	velocity.x = direcao.x * velocidade
	velocity.z = direcao.z * velocidade

	if not is_on_floor():
		velocity += get_gravity() * delta

	move_and_slide()
