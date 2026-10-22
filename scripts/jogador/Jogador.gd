extends CharacterBody3D

@export var speed := 5.0
@export var talk_range := 2.5

var nearby_npc: Node3D = null
var spawn_point: Vector3
var visual: CharacterVisual = null
var step_timer := 0.0
const STEP_INTERVAL := 0.42
const SILHOUETTE := preload("res://assets/shaders/silhouette.gdshader")

# ---------- Hiding at night ----------
# Standing still right beside something solid (a tree, a wall, a cart) at night counts as
# lurking. Behind cover nobody sees the doctor; but someone who does catch him lurking late
# trusts him less than if he were just walking by.
const LURK_RADIUS := 1.2
const LURK_SECONDS := 2.0
var lurk_time := 0.0
var cover_query: PhysicsShapeQueryParameters3D

# Inside a bush or tall grass (empties named Hide_* in town.glb) the doctor is fully hidden:
# nobody sees him, not even the vampire. Stepping out late at night in front of someone
# counts as being caught lurking.
const EMERGE_SECONDS := 2.5
var cover_count := 0
var left_cover_at := -100.0


func _ready() -> void:
	add_to_group("player")  # Lets the vampire know where the doctor is
	spawn_point = global_position  # Where the doctor starts; used if he ever falls off
	visual = CharacterVisual.new()
	add_child(visual)
	visual.position.y = -1.0  # The doctor's body origin sits at the capsule's center
	if visual.setup("Doctor"):
		$MeshInstance3D.visible = false
		_add_silhouette(visual.meshes)
	else:
		visual.queue_free()
		visual = null

	if visual == null:
		_add_silhouette([$MeshInstance3D])
	_setup_hiding_spots.call_deferred()


func _setup_hiding_spots() -> void:
	await get_tree().process_frame  # town.glb may finish loading after us
	for spot in get_tree().current_scene.find_children("Hide_*", "Node3D", true, false):
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.0  # The empty's scale in Blender sets the real size
		shape.shape = sphere
		area.add_child(shape)
		area.monitorable = false
		spot.add_child(area)
		area.body_entered.connect(func(body: Node3D):
			if body == self:
				_set_cover(1))
		area.body_exited.connect(func(body: Node3D):
			if body == self:
				_set_cover(-1))


func _set_cover(change: int) -> void:
	var was_hidden := is_hidden()
	cover_count = maxi(cover_count + change, 0)
	if not was_hidden and is_hidden():
		Playtest.count("hid_in_bush_or_grass")
	if was_hidden and not is_hidden():
		left_cover_at = Time.get_ticks_msec() / 1000.0
	# Half see-through while hidden, so the player knows
	if visual:
		for mi in visual.meshes:
			mi.transparency = 0.45 if is_hidden() else 0.0


func is_hidden() -> bool:
	return cover_count > 0


func just_left_cover() -> bool:
	return Time.get_ticks_msec() / 1000.0 - left_cover_at < EMERGE_SECONDS


# Shows the doctor's outline through buildings that hide him.
# Uses the materials' built-in X-ray stencil mode: the body marks the pixels where it is seen,
# and the outline is only drawn where it is hidden, so his own head never counts as a wall.
# Falls back to silhouette.gdshader if this Godot has no stencil support.
const SILHOUETTE_COLOR := Color(0.94, 0.86, 0.66, 0.55)

func _add_silhouette(meshes: Array) -> void:
	var fallback: ShaderMaterial = null
	for m in meshes:
		var mi := m as MeshInstance3D
		var done := false
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat and "stencil_mode" in mat:
				if mi.get_surface_override_material(i) != mat:
					mat = mat.duplicate() as BaseMaterial3D  # Own copy, other bodies keep theirs
				mat.set("stencil_mode", 2)  # BaseMaterial3D.STENCIL_MODE_XRAY
				mat.set("stencil_color", SILHOUETTE_COLOR)
				mi.set_surface_override_material(i, mat)
				done = true
		if not done:
			if fallback == null:
				fallback = ShaderMaterial.new()
				fallback.shader = SILHOUETTE
			mi.material_overlay = fallback


func _physics_process(delta: float) -> void:
	if global_position.y < -5.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
		reset_physics_interpolation()  # Teleport instantly, don't slide there
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if GameState.in_dialogue or GameState.reading:
		# Stand still while talking
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# Camera looks straight north, so "up" on the keyboard is -z in the world
		var direction := Vector3(input.x, 0, input.y)
		var current_speed := speed * (1.0 - GameState.exhaustion * 0.6)
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()
	if visual:
		visual.animate(get_real_velocity(), delta)
	_footsteps(delta)
	_update_nearby_npc()
	var still := Vector2(velocity.x, velocity.z).length() < 0.3
	lurk_time = lurk_time + delta if GameState.is_night and still and _near_cover() else 0.0


func is_lurking() -> bool:
	return lurk_time >= LURK_SECONDS


func _near_cover() -> bool:
	if cover_query == null:
		var shape := SphereShape3D.new()
		shape.radius = LURK_RADIUS
		cover_query = PhysicsShapeQueryParameters3D.new()
		cover_query.shape = shape
		cover_query.exclude = [get_rid()]
	# Raised so the ground under his feet doesn't count as cover
	cover_query.transform = Transform3D(Basis(), global_position + Vector3(0.0, 0.6, 0.0))
	for hit in get_world_3d().direct_space_state.intersect_shape(cover_query, 8):
		if hit["collider"] is StaticBody3D:
			return true
	return false


func _footsteps(delta: float) -> void:
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if not moving:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = STEP_INTERVAL / maxf(1.0 - GameState.exhaustion * 0.6, 0.4)  # Slower when tired
		Audio.play("step_%d" % (randi() % 5), -26.0, 0.0, 0.08)  # Soft steps on dirt


func _update_nearby_npc() -> void:
	var closest: Node3D = null
	var closest_distance := talk_range
	if GameState.in_dialogue or GameState.reading:
		closest_distance = 0.0  # Nobody is "nearby" while already talking
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not npc.can_talk():
			continue
		var distance: float = global_position.distance_to(npc.global_position)
		if distance < closest_distance:
			closest = npc
			closest_distance = distance
	# Only the closest NPC shows the "[E] Falar" prompt
	if closest != nearby_npc:
		if nearby_npc:
			nearby_npc.set_highlighted(false)
		nearby_npc = closest
		if nearby_npc:
			nearby_npc.set_highlighted(true)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.in_dialogue or GameState.reading or nearby_npc == null:
		return
	if event.is_action_pressed("interact"):
		nearby_npc.set_highlighted(false)
		nearby_npc.talk(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accuse") and nearby_npc.is_alive():
		nearby_npc.set_highlighted(false)
		EventBus.accusation_requested.emit(nearby_npc)
		get_viewport().set_input_as_handled()
